local M = {}

local function configure_window(ns, win, active)
  if not vim.api.nvim_win_is_valid(win) then return end
  if active then
    vim.api.nvim_win_set_hl_ns(win, 0)
    return
  end
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local visual = vim.api.nvim_get_hl(0, { name = "Visual", link = false })
  vim.api.nvim_set_hl(ns, "Visual", { link = "Normal" })
  vim.api.nvim_set_hl(ns, "ViewSplitSavedSelection", visual)
  vim.api.nvim_win_set_hl_ns(win, ns)
end

local function capture(win, buf, active_mode)
  return vim.api.nvim_win_call(win, function()
    local mode = active_mode or vim.fn.visualmode()
    local first, last
    if active_mode then
      local anchor = vim.fn.getpos("v")
      local cursor = vim.fn.getcurpos()
      if anchor[2] < 1 or cursor[2] < 1 then return nil end
      first = { anchor[2], anchor[3] - 1 }
      last = { cursor[2], cursor[3] - 1 }
    else
      first = vim.api.nvim_buf_get_mark(buf, "<")
      last = vim.api.nvim_buf_get_mark(buf, ">")
      if first[1] < 1 or last[1] < 1 then return nil end
    end
    local exclusive = vim.o.selection == "exclusive"
    local p1 = { buf, first[1], first[2] + 1, 0 }
    local p2 = { buf, last[1], last[2] + 1, 0 }
    if p2[2] < p1[2] or (p2[2] == p1[2] and p2[3] < p1[3]) then p1, p2 = p2, p1 end
    local ok, segments = pcall(vim.fn.getregionpos, p1, p2, { type = mode, exclusive = exclusive })
    if not ok or type(segments) ~= "table" or #segments == 0 then
      segments = { { p1, p2 } }
    end
    return { kind = mode == "V" and "line" or (mode == "\22" and "block" or "char"), segments = segments }
  end)
end

local function render(ns, win, buf, selection)
  if not selection or selection.active or vim.api.nvim_win_get_buf(win) ~= buf then return end
  for _, segment in ipairs(selection.segments or {}) do
    local first, last = segment[1], segment[2]
    if first and last then
      vim.api.nvim_buf_set_extmark(buf, ns, first[2] - 1, first[3] - 1, {
        end_row = last[2] - 1,
        end_col = last[3] - 1,
        hl_group = "ViewSplitSavedSelection",
        priority = 200,
        ephemeral = true,
        strict = false,
      })
    end
  end
end

function M.setup(states, group)
  local ns = vim.api.nvim_create_namespace("viewsplit-visual")
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf)
      local state = states[win]
      if not state or vim.api.nvim_win_get_buf(win) ~= buf then return false end
      local active = win == vim.api.nvim_get_current_win()
      configure_window(ns, win, active)
      if not active then
        render(ns, win, buf, state.selection)
      end
      return false
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local current = vim.api.nvim_get_current_win()
      for win, state in pairs(states) do
        if win ~= current and state.selection then
          state.selection.active = false
        end
        configure_window(ns, win, win == current)
      end
      vim.cmd.redraw()
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if not state then return end
      local mode = vim.api.nvim_get_mode().mode
      if mode:match("^[vV\\22]") then
        local selection = capture(win, vim.api.nvim_win_get_buf(win), mode)
        if selection then
          selection.active = false
          state.selection = selection
        end
        vim.schedule(function()
          if vim.api.nvim_get_mode().mode:match("^[vV\\22]") then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
          end
        end)
      end
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
        local selection = capture(win, vim.api.nvim_get_current_buf())
        if selection then selection.active = false; state.selection = selection end
      elseif new_mode:match("^[vV\22]") then
        local selection = capture(win, vim.api.nvim_get_current_buf(), new_mode:sub(1, 1))
        if selection then selection.active = true; state.selection = selection end
      end
    end,
  })
end

return M
