local M = {}

local function pos_le(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
end

local function normalize(first, last)
  first, last = { first[1], first[2] }, { last[1], last[2] }
  if not pos_le(first, last) then first, last = last, first end
  return first, last
end

local function capture(buf)
  local first = vim.api.nvim_buf_get_mark(buf, "<")
  local last = vim.api.nvim_buf_get_mark(buf, ">")
  if first[1] < 1 or last[1] < 1 then return nil end
  first, last = normalize(first, last)
  local mode = vim.fn.visualmode()
  return {
    first = first,
    last = last,
    active = false,
    kind = mode == "V" and "line" or (mode == "\22" and "block" or "char"),
  }
end

function M.setup(states, group)
  local ns = vim.api.nvim_create_namespace("viewsplit-visual")
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf)
      local state = states[win]
      if not state or vim.api.nvim_win_get_buf(win) ~= buf then return false end
      local selection = state.selection
      if selection and not selection.active and selection.kind == "char" then
        local first, last = selection.first, selection.last
        local end_col = last[2]
        local line = vim.api.nvim_buf_get_lines(buf, last[1] - 1, last[1], true)[1] or ""
        if end_col < #line then end_col = end_col + 1 end
        vim.api.nvim_buf_set_extmark(buf, ns, first[1] - 1, first[2], {
          end_row = last[1] - 1,
          end_col = end_col,
          hl_group = "Visual",
          priority = 200,
          ephemeral = true,
          strict = false,
        })
      end
      if win == vim.api.nvim_get_current_win() then return end
      return false
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if not state then return end
      local old_mode, new_mode = vim.v.event.old_mode or "", vim.v.event.new_mode or ""
      if old_mode:match("^[vV\22]") then
        state.selection = capture(vim.api.nvim_win_get_buf(win))
      elseif new_mode:match("^[vV\22]") then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
            local selection = capture(vim.api.nvim_win_get_buf(win))
            if selection then selection.active = true; state.selection = selection end
          end
        end)
      end
    end,
  })
end

return M
