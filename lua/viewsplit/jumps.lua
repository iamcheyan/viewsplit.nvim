local M = {}
local api = vim.api
local recording = {}

local function position(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return nil end
  local win = state.winid
  local cursor = api.nvim_win_get_cursor(win)
  return { bufnr = api.nvim_win_get_buf(win), lnum = cursor[1], col = cursor[2], coladd = 0 }
end

local function same(a, b)
  return a and b and a.bufnr == b.bufnr and a.lnum == b.lnum and a.col == b.col
end

function M.record(state)
  local pos = position(state)
  if not pos then return end
  local list = state.jumplist or {}
  local index = state.jump_index or #list
  if same(list[index], pos) then return end
  if #list == 1 and index == 1 then
    list[#list + 1] = pos
    state.jumplist = list
    state.jump_index = #list
    state.jump_cursor = pos
    return
  end
  for i = index + 1, #list do list[i] = nil end
  list[#list + 1] = pos
  if #list > 100 then table.remove(list, 1) end
  state.jumplist = list
  state.jump_index = #list
  state.jump_cursor = pos
end

function M.restore(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return end
  local target = state.jump_cursor
  if target and api.nvim_buf_is_valid(target.bufnr) then
    recording[state.winid] = true
    pcall(api.nvim_win_set_buf, state.winid, target.bufnr)
    pcall(api.nvim_win_set_cursor, state.winid, { target.lnum, target.col })
    recording[state.winid] = nil
  end
end

function M.back(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return false end
  local list = state.jumplist or {}
  local index = state.jump_index or #list
  if index <= 1 then return false end
  index = index - 1
  state.jump_index = index
  state.jump_cursor = vim.deepcopy(list[index])
  M.restore(state)
  return true
end

function M.forward(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return false end
  local list = state.jumplist or {}
  local index = state.jump_index or #list
  if index >= #list then return false end
  index = index + 1
  state.jump_index = index
  state.jump_cursor = vim.deepcopy(list[index])
  M.restore(state)
  return true
end

function M.setup(states, group)
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      local win = api.nvim_get_current_win()
      if recording[win] then return end
      local state = states[win]
      if state then M.record(state) end
    end,
  })
  for _, state in pairs(states) do M.record(state) end
end

return M
