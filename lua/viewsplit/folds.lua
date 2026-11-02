local M = {}
local api = vim.api
local window_options = { "foldenable", "foldlevel", "foldmethod", "foldexpr", "foldminlines", "foldnestmax" }

function M.capture(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return end
  state.folds = state.folds or {}
  for _, name in ipairs(window_options) do
    local ok, value = pcall(api.nvim_get_option_value, name, { win = state.winid })
    if ok then state.folds[name] = value end
  end
  local closed = {}
  api.nvim_win_call(state.winid, function()
    local line = 1
    local last = api.nvim_buf_line_count(api.nvim_win_get_buf(state.winid))
    while line <= last do
      local finish = vim.fn.foldclosedend(line)
      if finish >= line then
        closed[#closed + 1] = { first = line, last = finish }
        line = finish + 1
      else
        line = line + 1
      end
    end
  end)
  state.fold_ranges = closed
end

function M.restore(state)
  if not state or not api.nvim_win_is_valid(state.winid) then return end
  if state.folds then
    for _, name in ipairs(window_options) do
      local value = state.folds[name]
      if value ~= nil then
        pcall(api.nvim_set_option_value, name, value, { scope = "local", win = state.winid })
      end
    end
  end
  if not state.fold_ranges then return end
  api.nvim_win_call(state.winid, function()
    vim.cmd("silent! normal! zR")
    for _, range in ipairs(state.fold_ranges) do
      local line = range.first
      if vim.fn.foldlevel(line) > 0 then
        api.nvim_win_set_cursor(state.winid, { line, 0 })
        vim.cmd("silent! normal! zc")
      end
    end
  end)
end

function M.setup(states, group)
  api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      local state = states[api.nvim_get_current_win()]
      if state then M.capture(state) end
    end,
  })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local state = states[api.nvim_get_current_win()]
      if state and state.folds then M.restore(state) end
    end,
  })
end

return M
