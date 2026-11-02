local M = {}

local function ensure_selection_hl()
  local visual = vim.api.nvim_get_hl(0, { name = "Visual", link = false })
  vim.api.nvim_set_hl(0, "ViewSplitSavedSelection", visual)
  vim.api.nvim_set_hl(0, "ViewSplitVisualHidden", {})
end

local function configure_window(win, active)
  if not vim.api.nvim_win_is_valid(win) then return end
  local cur = vim.wo[win].winhighlight or ""
  if active then
    if vim.w[win]._viewsplit_saved_visual_hl then
      cur = cur:gsub("Visual:ViewSplitVisualHidden", "Visual:" .. vim.w[win]._viewsplit_saved_visual_hl)
      vim.w[win]._viewsplit_saved_visual_hl = nil
    else
      cur = cur:gsub(",?Visual:ViewSplitVisualHidden", "")
    end
    cur = cur:gsub(",?VisualNOS:ViewSplitVisualHidden", ""):gsub("^,", "")
    if cur ~= vim.wo[win].winhighlight then
      vim.wo[win].winhighlight = cur
    end
    return
  end
  if cur:find("Visual:ViewSplitVisualHidden", 1, true) then
    return
  end
  local existing_visual = cur:match("Visual:([^,]+)")
  if existing_visual and existing_visual ~= "ViewSplitVisualHidden" then
    vim.w[win]._viewsplit_saved_visual_hl = existing_visual
    cur = cur:gsub("Visual:[^,]+", "Visual:ViewSplitVisualHidden")
  else
    cur = (cur ~= "" and (cur .. ",") or "") .. "Visual:ViewSplitVisualHidden"
  end
  if not cur:find("VisualNOS:", 1, true) then
    cur = cur .. ",VisualNOS:ViewSplitVisualHidden"
  end
  vim.wo[win].winhighlight = cur
end

local function end_col_inclusive(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  if col > #line then
    return #line
  end
  local idx = vim.str_utfindex(line, "utf-32", col)
  local ok, byte_end = pcall(vim.str_byteindex, line, "utf-32", idx)
  if ok and byte_end then
    return byte_end
  end
  return math.min(#line, col)
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
    return {
      kind = mode == "V" and "line" or (mode == "\22" and "block" or "char"),
      mode = mode,
      bufnr = buf,
      exclusive = exclusive,
      anchor = first,
      cursor = last,
      segments = segments,
    }
  end)
end

local function render(ns, win, buf, selection)
  if not selection or selection.active or vim.api.nvim_win_get_buf(win) ~= buf then return end
  if selection.bufnr and selection.bufnr ~= buf then return end
  local is_line = selection.kind == "line"
  local is_excl = selection.exclusive == true
  for _, segment in ipairs(selection.segments or {}) do
    local first, last = segment[1], segment[2]
    if first and last then
      local start_row = first[2] - 1
      local start_col = math.max(0, first[3] - 1)
      local end_row = last[2] - 1
      local end_col
      if is_line then
        local line = vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1] or ""
        start_col = 0
        end_col = #line
      elseif is_excl then
        end_col = math.max(start_col, last[3])
      else
        end_col = end_col_inclusive(buf, last[2], last[3])
      end
      vim.api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
        end_row = end_row,
        end_col = end_col,
        hl_group = "ViewSplitSavedSelection",
        hl_eol = is_line,
        priority = 200,
        ephemeral = true,
        strict = false,
      })
    end
  end
end

function M.clear(state)
  if not state then return end
  state.selection = nil
  pcall(vim.cmd.redraw)
end

function M.setup(states, group)
  ensure_selection_hl()
  local ns = vim.api.nvim_create_namespace("viewsplit-visual")
  local leaving_visual_win = nil
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = ensure_selection_hl,
  })
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf)
      local state = states[win]
      if not state or vim.api.nvim_win_get_buf(win) ~= buf then return false end
      local active = win == vim.api.nvim_get_current_win()
      configure_window(win, active)
      local sel = state.selection
      if sel and (not active or not sel.active) then
        render(ns, win, buf, sel)
      end
      return false
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local current = vim.api.nvim_get_current_win()
      local mode = vim.api.nvim_get_mode().mode
      if mode:match("^[vV\22]") then
        leaving_visual_win = current
        pcall(vim.cmd, "normal! \27")
        leaving_visual_win = nil
      end
      for win, state in pairs(states) do
        if win ~= current and state.selection then
          state.selection.active = false
        end
        configure_window(win, win == current)
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
      if mode:match("^[vV\22]") then
        local selection = capture(win, vim.api.nvim_win_get_buf(win), mode:sub(1, 1))
        if selection then
          selection.active = false
          state.selection = selection
        end
        leaving_visual_win = win
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
      if old_mode:match("^[vV\22]") and not new_mode:match("^[vV\22]") then
        if leaving_visual_win ~= nil then
          leaving_visual_win = nil
          return
        end
        local op = vim.v.operator or ""
        if op ~= "" then
          state.selection = nil
          return
        end
        local selection = capture(win, vim.api.nvim_get_current_buf())
        if selection then
          selection.active = false
          state.selection = selection
        end
      elseif new_mode:match("^[vV\22]") then
        leaving_visual_win = nil
        local selection = capture(win, vim.api.nvim_get_current_buf(), new_mode:sub(1, 1))
        if selection then
          selection.active = true
          state.selection = selection
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local state = states[win]
      if not state or not vim.api.nvim_win_is_valid(win) then return end
      local mode = vim.api.nvim_get_mode().mode
      if mode:match("^[vV\22]") then
        local selection = capture(win, vim.api.nvim_win_get_buf(win), mode:sub(1, 1))
        if selection then
          selection.active = true
          state.selection = selection
        end
      end
    end,
  })
  local left_mouse = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
  vim.on_key(function(key, typed)
    local raw = (typed and typed ~= "") and typed or key
    if raw == left_mouse or key == left_mouse then
      local ok, mp = pcall(vim.fn.getmousepos)
      if ok and mp and mp.winid and mp.winid ~= 0 then
        local cur = vim.api.nvim_get_current_win()
        if mp.winid == cur then
          local state = states[cur]
          if state and state.selection and not state.selection.active then
            state.selection = nil
            vim.schedule(function() pcall(vim.cmd.redraw) end)
          end
        end
      end
    end
  end, ns)
end

return M
