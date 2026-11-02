local M = {}
local api = vim.api

local function valid_win(win)
  return type(win) == "number" and api.nvim_win_is_valid(win)
end

function M.new(win)
  return {
    winid = win,
    search_pattern = "",
    search_match_id = nil,
    folds = {},
    cursor = {},
    topline = 0,
    leftcol = 0,
    marks = {},
    jumplist = {},
    selection = {},
  }
end

function M.capture(state)
  if not valid_win(state.winid) then return end
  local win = state.winid
  state.cursor = api.nvim_win_get_cursor(win)
  local view = vim.fn.winsaveview()
  state.topline = view.topline
  state.leftcol = view.leftcol
end

function M.restore(state)
  if not valid_win(state.winid) then return end
  local win = state.winid
  if state.cursor and #state.cursor == 2 then
    pcall(api.nvim_win_set_cursor, win, state.cursor)
  end
  pcall(api.nvim_win_call, win, function()
    vim.fn.winrestview({ topline = state.topline or 1, leftcol = state.leftcol or 0 })
  end)
end

return M
