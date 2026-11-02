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

function M.update_prompt(state)
  if not state or not valid(state.winid) then return end
  if vim.api.nvim_get_current_win() ~= state.winid then return end
  local pattern = state.search_pattern
  if pattern and pattern ~= "" then
    local sc = {}
    pcall(function()
      sc = vim.fn.searchcount({ recompute = 1, maxcount = 9999 })
    end)
    local msg = "/" .. pattern
    if sc.total and sc.total > 0 then
      msg = msg .. string.format("       [%d/%d]", sc.current or 0, sc.total)
    end
    if package.loaded.noice then
      pcall(require("noice").cmd, "dismiss")
    end
    vim.api.nvim_echo({ { msg, "None" } }, false, {})
  else
    if package.loaded.noice then
      pcall(require("noice").cmd, "dismiss")
    end
    vim.cmd("echo")
  end
end

function M.clean_winhl(win)
  if not valid(win) then return end
  local cur = vim.wo[win].winhighlight
  if cur and cur ~= "" then
    local filtered = {}
    for item in cur:gmatch("[^,]+") do
      local k = item:match("^([^:]+):")
      if k ~= "Search" and k ~= "CurSearch" and k ~= "IncSearch"
         and k ~= "HlSearchNear" and k ~= "HlSearchLens" and k ~= "HlSearchLensNear" then
        table.insert(filtered, item)
      end
    end
    vim.wo[win].winhighlight = table.concat(filtered, ",")
  end
end

function M.clear(state)
  if not state then return end
  vim.opt.hlsearch = false
  local win = state.winid
  if valid(win) then
    if state.search_match_id then
      pcall(vim.fn.matchdelete, state.search_match_id, win)
    end
    local wid = vim.w[win].win_search_id
    if wid and wid ~= state.search_match_id then
      pcall(vim.fn.matchdelete, wid, win)
    end
    vim.w[win].win_search_id = nil
    vim.w[win].win_search_pattern = nil
  end
  state.search_match_id = nil
  state.search_pattern = ""
  if valid(win) and vim.api.nvim_get_current_win() == win then
    if package.loaded["hlslens"] then
      pcall(require("hlslens").stop)
    end
    M.update_prompt(state)
  end
  refresh_scrollbar()
end

function M.set(state, pattern)
  if not state then return end
  vim.opt.hlsearch = false
  M.clear(state)
  if not valid(state.winid) or type(pattern) ~= "string" or pattern == "" then return end
  state.search_pattern = pattern
  vim.w[state.winid].win_search_pattern = pattern
  local ok, id = pcall(vim.fn.matchadd, "Search", pattern, 10, -1, { window = state.winid })
  if ok then
    state.search_match_id = id
    vim.w[state.winid].win_search_id = id
  end
  if valid(state.winid) and vim.api.nvim_get_current_win() == state.winid then
    M.update_prompt(state)
  end
  refresh_scrollbar()
end

function M.restore(state)
  if not state or not valid(state.winid) then return end
  vim.opt.hlsearch = false
  M.clean_winhl(state.winid)
  if state.search_pattern ~= "" then
    vim.fn.setreg("/", state.search_pattern)
  else
    vim.cmd("nohlsearch")
    if package.loaded["hlslens"] then
      pcall(require("hlslens").stop)
    end
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
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    M.clean_winhl(win)
  end
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      vim.opt.hlsearch = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        M.clean_winhl(win)
      end
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "hlsearch",
    callback = function()
      if vim.o.hlsearch then
        vim.opt.hlsearch = false
      end
    end,
  })
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
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if state then
        M.restore(state)
        vim.schedule(function()
          if valid(win) and vim.api.nvim_get_current_win() == win then
            M.update_prompt(state)
          end
        end)
      end
    end,
  })
end

return M
