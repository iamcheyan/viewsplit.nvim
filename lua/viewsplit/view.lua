local M = {}
local api = vim.api

local function valid_win(win)
  return type(win) == "number" and api.nvim_win_is_valid(win)
end

function M.new(win)
  local state = {
    winid = win,
    search_pattern = "",
    search_match_id = nil,
    folds = {},
    cursor = nil,
    topline = nil,
    leftcol = 0,
    skipcol = 0,
    curswant = 0,
    marks = {},
    jumplist = {},
    selection = nil,
  }
  if valid_win(win) then
    M.capture(state)
  end
  return state
end

function M.capture(state)
  if not state or not valid_win(state.winid) then return end
  local win = state.winid
  state.cursor = api.nvim_win_get_cursor(win)
  local view = api.nvim_win_call(win, vim.fn.winsaveview)
  state.topline = view.topline
  state.leftcol = view.leftcol
  state.skipcol = view.skipcol
  state.curswant = view.curswant
end

function M.restore(state)
  if not state or not valid_win(state.winid) then return end
  if type(state.cursor) ~= "table" or #state.cursor < 2 then
    M.capture(state)
    return
  end
  local win = state.winid
  api.nvim_win_call(win, function()
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

return M
