local M = {}
local api = vim.api

local function capture(state)
  if not api.nvim_win_is_valid(state.winid) then return end
  state.cursor = api.nvim_win_get_cursor(state.winid)
  local view = api.nvim_win_call(state.winid, vim.fn.winsaveview)
  state.topline = view.topline
  state.leftcol = view.leftcol
  state.skipcol = view.skipcol
  state.curswant = view.curswant
end

function M.capture(state)
  capture(state)
end

function M.restore(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return end
  if type(state.cursor) ~= "table" or #state.cursor < 2 then
    capture(state)
    return
  end
  api.nvim_win_call(state.winid, function()
    vim.fn.winrestview({
      lnum = state.cursor[1],
      col = state.cursor[2],
      topline = state.topline or 1,
      leftcol = state.leftcol or 0,
      skipcol = state.skipcol or 0,
      curswant = state.curswant or 0,
    })
  end)
end

function M.setup(states, group)
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled", "WinLeave" }, {
    group = group,
    callback = function()
      local state = states[api.nvim_get_current_win()]
      if state then capture(state) end
    end,
  })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local state = states[api.nvim_get_current_win()]
      if state then M.restore(state) end
    end,
  })
end

return M
