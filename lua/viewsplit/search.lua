local M = {}

local function valid(win)
  return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function refresh_scrollbar()
  local sat = package.loaded["satellite.view"]
  if sat and sat.enabled and sat.enabled() and sat.schedule_refresh then
    pcall(sat.schedule_refresh)
  end
end

function M.clear(state)
  local win = state.winid
  if valid(win) and state.search_match_id then
    pcall(vim.fn.matchdelete, state.search_match_id, win)
  end
  state.search_match_id = nil
  state.search_pattern = ""
  refresh_scrollbar()
end

function M.set(state, pattern)
  M.clear(state)
  if not valid(state.winid) or type(pattern) ~= "string" or pattern == "" then return end
  state.search_pattern = pattern
  local ok, id = pcall(vim.fn.matchadd, "Search", pattern, 10, -1, { window = state.winid })
  if ok then state.search_match_id = id end
  refresh_scrollbar()
end

function M.restore(state)
  if not valid(state.winid) then return end
  if state.search_pattern ~= "" then
    vim.fn.setreg("/", state.search_pattern)
  else
    vim.cmd("nohlsearch")
  end
end

function M.setup(states, group)
  local configured_hlslens = package.loaded["hlslens"] ~= nil
  if configured_hlslens and vim.g.viewsplit_hlslens_incsearch ~= false then
    local hlslens = package.loaded["hlslens"]
    if hlslens._config then hlslens._config.enable_incsearch = false end
    if package.loaded["hlslens.config"] then
      package.loaded["hlslens.config"].enable_incsearch = false
    end
  end
  vim.opt.hlsearch = false
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local ev = vim.v.event
      if ev.abort or (ev.cmdtype ~= "/" and ev.cmdtype ~= "?") then return end
      local win = vim.api.nvim_get_current_win()
      vim.schedule(function()
        local state = states[win]
        if state and valid(win) then M.set(state, vim.fn.getreg("/")) end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "FocusGained" }, {
    group = group,
    callback = function()
      local state = states[vim.api.nvim_get_current_win()]
      if state then M.restore(state) end
    end,
  })
end

return M
