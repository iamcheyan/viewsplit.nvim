local M = {}

local function pos_le(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
end

local function selection_from_marks(buf)
  local a = vim.api.nvim_buf_get_mark(buf, "<")
  local b = vim.api.nvim_buf_get_mark(buf, ">")
  if a[1] < 1 or b[1] < 1 then return nil end
  a, b = { a[1], a[2] }, { b[1], b[2] }
  if not pos_le(a, b) then a, b = b, a end
  return { first = a, last = b, active = false }
end

local function setup(states, group)
  local ns = vim.api.nvim_create_namespace("viewsplit-visual")
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf)
      local state = states[win]
      if not state or vim.api.nvim_win_get_buf(win) ~= buf then return false end
      local selection = state.selection
      if selection and not selection.active then
        local a, b = selection.first, selection.last
        vim.api.nvim_buf_set_extmark(buf, ns, a[1] - 1, a[2], {
          end_row = b[1] - 1,
          end_col = b[2] + 1,
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
        state.selection = selection_from_marks(vim.api.nvim_win_get_buf(win))
      elseif new_mode:match("^[vV\22]") then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
            local selection = selection_from_marks(vim.api.nvim_win_get_buf(win))
            if selection then selection.active = true; state.selection = selection end
          end
        end)
      end
    end,
  })
end

function M.setup(states, group)
  setup(states, group)
end

return M
