local M = {}

local function valid(win)
  return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

function M.setup(states, group)
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if state then
        state.cursor = vim.api.nvim_win_get_cursor(win)
        local view = vim.fn.winsaveview()
        state.topline = view.topline
        state.leftcol = view.leftcol
      end
    end,
  })
end

function M.restore(state)
  if not valid(state.winid) then return end
  vim.api.nvim_win_call(state.winid, function()
    vim.fn.winrestview({ topline = state.topline or 1, leftcol = state.leftcol or 0 })
  end)
  if state.cursor and #state.cursor == 2 then
    pcall(vim.api.nvim_win_set_cursor, state.winid, state.cursor)
  end
end

return M
