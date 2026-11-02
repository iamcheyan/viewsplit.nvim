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

local function ensure_lens_hl()
  vim.api.nvim_set_hl(0, "HlSearchNear", { default = true, link = "CurSearch" })
  vim.api.nvim_set_hl(0, "HlSearchLens", { default = true, link = "WildMenu" })
  vim.api.nvim_set_hl(0, "HlSearchLensNear", { default = true, link = "CurSearch" })
end

local function compare_pos(a, b)
  if a[1] ~= b[1] then
    return a[1] < b[1] and -1 or 1
  end
  if a[2] ~= b[2] then
    return a[2] < b[2] and -1 or 1
  end
  return 0
end

local regex_initialized = false

local function build_matches(buf, pattern)
  if not vim.api.nvim_buf_is_valid(buf) or not pattern or pattern == "" then
    return {}, {}
  end
  local ok_regex, regex_mod = pcall(require, "hlslens.position.range.regex")
  if ok_regex and regex_mod and type(regex_mod.buildList) == "function" then
    if not regex_initialized and type(regex_mod.initialize) == "function" then
      pcall(regex_mod.initialize, 1e5)
      regex_initialized = true
    end
    local ok_list, sList, eList = pcall(regex_mod.buildList, buf, pattern)
    if ok_list and type(sList) == "table" and type(eList) == "table" then
      return sList, eList
    end
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local pat = pattern
  if vim.o.ignorecase and vim.o.smartcase and pat:find("[A-Z]") and not pat:find("\\[cC]") then
    pat = "\\C" .. pat
  elseif vim.o.ignorecase and not pat:find("\\[cC]") then
    pat = "\\c" .. pat
  end
  local sList, eList = {}, {}
  for lnum, line in ipairs(lines) do
    local start_idx = 0
    while start_idx <= #line do
      local ok, res = pcall(vim.fn.matchstrpos, line, pat, start_idx)
      if not ok or not res or res[2] == -1 then break end
      local s_col = res[2] + 1
      local e_col = math.max(s_col, res[3])
      sList[#sList + 1] = { lnum, s_col }
      eList[#eList + 1] = { lnum, e_col }
      start_idx = (res[3] > res[2]) and res[3] or (res[2] + 1)
    end
  end
  return sList, eList
end

local function get_matches_cached(state, buf, pattern)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cache = state._lens_cache
  if cache and cache.buf == buf and cache.tick == tick and cache.pattern == pattern
     and cache.ignorecase == vim.o.ignorecase and cache.smartcase == vim.o.smartcase then
    return cache.sList, cache.eList
  end
  local sList, eList = build_matches(buf, pattern)
  state._lens_cache = {
    buf = buf,
    tick = tick,
    pattern = pattern,
    ignorecase = vim.o.ignorecase,
    smartcase = vim.o.smartcase,
    sList = sList,
    eList = eList,
  }
  return sList, eList
end

local function find_nearest(sList, eList, curPos)
  local len = #sList
  if len == 0 then return nil, nil end
  local lo, hi = 1, len
  local insert_pos = len + 1
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local cmp = compare_pos(sList[mid], curPos)
    if cmp == 0 then
      return mid, 0
    elseif cmp < 0 then
      lo = mid + 1
    else
      insert_pos = mid
      hi = mid - 1
    end
  end
  local prev_idx = insert_pos - 1
  local next_idx = insert_pos
  if prev_idx >= 1 and compare_pos(curPos, eList[prev_idx]) <= 0 then
    return prev_idx, 0
  end
  if prev_idx < 1 then
    return 1, 1
  end
  if next_idx > len then
    return len, -1
  end
  local dist_prev = math.abs(curPos[1] - sList[prev_idx][1])
  local dist_next = math.abs(sList[next_idx][1] - curPos[1])
  if dist_next < dist_prev then
    return next_idx, 1
  end
  return prev_idx, -1
end

local function format_lens_chunks(idx, cnt, relIdx, nearest)
  local sfw = vim.v.searchforward == 1
  local indicator = ""
  local absRelIdx = math.abs(relIdx)
  if absRelIdx > 1 then
    indicator = string.format("%d%s", absRelIdx, sfw ~= (relIdx > 1) and "N" or "n")
  elseif absRelIdx == 1 then
    indicator = sfw ~= (relIdx == 1) and "N" or "n"
  end
  if nearest then
    local text = indicator ~= "" and string.format("[%s %d/%d]", indicator, idx, cnt) or string.format("[%d/%d]", idx, cnt)
    return { { " " }, { text, "HlSearchLensNear" } }
  else
    local text = string.format("[%s %d]", indicator, idx)
    return { { " " }, { text, "HlSearchLens" } }
  end
end

local function active_pattern(state)
  if not state then return "" end
  if state._incsearch_pattern ~= nil and state._incsearch_pattern ~= "" then
    return state._incsearch_pattern
  end
  return state.search_pattern or ""
end

local function render_window_lens(ns, win, buf, topRow, botRow, state)
  local pattern = active_pattern(state)
  if pattern == "" then return end
  if vim.api.nvim_win_get_buf(win) ~= buf then return end
  local sList, eList = get_matches_cached(state, buf, pattern)
  local cnt = #sList
  if cnt == 0 then return end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local curPos = { cursor[1], cursor[2] + 1 }
  local idx, relIdx = find_nearest(sList, eList, curPos)
  if not idx then return end
  state._last_lens_key = string.format("%d:%d:%d", idx, relIdx, vim.v.searchforward)

  local topLimit = (topRow or 0) + 1
  local botLimit = (botRow or vim.api.nvim_buf_line_count(buf)) + 1

  -- Highlight nearest match token with HlSearchNear (priority above Search match)
  local nearStart, nearEnd = sList[idx], eList[idx]
  if nearStart and nearEnd and nearStart[1] >= topLimit and nearStart[1] <= botLimit then
    vim.api.nvim_buf_set_extmark(buf, ns, nearStart[1] - 1, math.max(0, nearStart[2] - 1), {
      end_row = nearEnd[1] - 1,
      end_col = math.max(0, nearEnd[2]),
      hl_group = "HlSearchNear",
      priority = 210,
      ephemeral = true,
      strict = false,
    })
  end

  local idxLnum = nearStart[1]
  local lineRenderList = {}
  local tIdx = idx - 1 - math.min(relIdx, 0)
  local lastHlLnum = 0
  for i = math.max(tIdx, 0), 1, -1 do
    local iLnum = sList[i][1]
    if iLnum < topLimit then break end
    if lastHlLnum ~= iLnum then
      lastHlLnum = iLnum
      lineRenderList[iLnum] = { i, i - tIdx - 1 }
    end
  end

  local bIdx = idx + 1 - math.max(relIdx, 0)
  lastHlLnum = idxLnum
  local lastI, lastLnum
  for i = bIdx, cnt do
    lastI = i
    lastLnum = sList[i][1]
    if lastHlLnum ~= lastLnum then
      lastHlLnum = lastLnum
      lineRenderList[sList[i - 1][1]] = { i - 1, i - bIdx }
    end
    if lastLnum > botLimit then break end
  end
  if lastI and lastLnum and lastLnum <= botLimit then
    lineRenderList[lastLnum] = { lastI, lastI - bIdx + 1 }
  end
  lineRenderList[idxLnum] = nil

  if idxLnum >= topLimit and idxLnum <= botLimit then
    vim.api.nvim_buf_set_extmark(buf, ns, idxLnum - 1, 0, {
      virt_text = format_lens_chunks(idx, cnt, relIdx, true),
      virt_text_pos = "eol",
      hl_mode = "combine",
      priority = 100,
      ephemeral = true,
      strict = false,
    })
  end

  for lnum, pair in pairs(lineRenderList) do
    if lnum >= topLimit and lnum <= botLimit then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
        virt_text = format_lens_chunks(pair[1], cnt, pair[2], false),
        virt_text_pos = "eol",
        hl_mode = "combine",
        priority = 90,
        ephemeral = true,
        strict = false,
      })
    end
  end
end

function M.lens_info(state)
  if not state or not valid(state.winid) or not state.search_pattern or state.search_pattern == "" then
    return nil
  end
  local win = state.winid
  local buf = vim.api.nvim_win_get_buf(win)
  local sList, eList = get_matches_cached(state, buf, state.search_pattern)
  local cnt = #sList
  if cnt == 0 then
    return { idx = 0, cnt = 0, relIdx = 0, text = "" }
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local idx, relIdx = find_nearest(sList, eList, { cursor[1], cursor[2] + 1 })
  if not idx then
    return { idx = 0, cnt = cnt, relIdx = 0, text = "" }
  end
  local chunks = format_lens_chunks(idx, cnt, relIdx, true)
  return {
    idx = idx,
    cnt = cnt,
    relIdx = relIdx,
    nearStart = sList[idx],
    nearEnd = eList[idx],
    text = chunks[2] and chunks[2][1] or "",
  }
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
  state._lens_cache = nil
  state._last_lens_key = nil
  if valid(win) and vim.api.nvim_get_current_win() == win then
    if package.loaded["hlslens"] then
      pcall(require("hlslens").stop)
    end
    M.update_prompt(state)
  end
  pcall(vim.cmd.redraw)
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
  pcall(vim.cmd.redraw)
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
  ensure_lens_hl()
  local lens_ns = vim.api.nvim_create_namespace("viewsplit-search-lens")
  vim.api.nvim_set_decoration_provider(lens_ns, {
    on_win = function(_, win, buf, topRow, botRow)
      local state = states[win]
      if not state then return false end
      render_window_lens(lens_ns, win, buf, topRow, botRow, state)
      return false
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = ensure_lens_hl,
  })
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
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = group,
    callback = function()
      local cmdtype = vim.fn.getcmdtype()
      if cmdtype ~= "/" and cmdtype ~= "?" then return end
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if not state or not valid(win) then return end
      state._incsearch_pattern = vim.fn.getcmdline()
      pcall(vim.api.nvim__redraw, { win = win, valid = false })
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local ev = vim.v.event
      if ev.cmdtype ~= "/" and ev.cmdtype ~= "?" then return end
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if state then
        state._incsearch_pattern = nil
      end
      if ev.abort then
        if valid(win) then
          pcall(vim.api.nvim__redraw, { win = win, valid = false })
        end
        return
      end
      vim.schedule(function()
        local s = states[win]
        if s and valid(win) then M.set(s, vim.fn.getreg("/")) end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if not state or not state.search_pattern or state.search_pattern == "" then return end
      local buf = vim.api.nvim_win_get_buf(win)
      local sList, eList = get_matches_cached(state, buf, state.search_pattern)
      if #sList == 0 then return end
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx, relIdx = find_nearest(sList, eList, { cursor[1], cursor[2] + 1 })
      if not idx then return end
      local key = string.format("%d:%d:%d", idx, relIdx, vim.v.searchforward)
      if key ~= state._last_lens_key then
        pcall(vim.api.nvim__redraw, { win = win, valid = false })
      end
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
