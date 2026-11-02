local M = {}
local api = vim.api
local View = require("viewsplit.view")
local Search = require("viewsplit.search")
local Selection = require("viewsplit.selection")
local Folds = require("viewsplit.folds")
local Jumps = require("viewsplit.jumps")
local Marks = require("viewsplit.marks")
local Scroll = require("viewsplit.scroll")

M._state = {}
M._options = { search = true, folds = false, jumps = false, marks = false, selection = false, scroll = false }

local function ensure(win)
  if not api.nvim_win_is_valid(win) then return nil end
  local state = M._state[win]
  if not state then
    state = View.new(win)
    M._state[win] = state
  end
  return state
end

function M.current_view()
  return ensure(api.nvim_get_current_win())
end

function M.view(win)
  return ensure(win or api.nvim_get_current_win())
end

function M.current_view_id()
  return api.nvim_get_current_win()
end

function M.selection_state(win)
  local state = M.view(win)
  return state and state.selection or nil
end

function M.clear_selection(win)
  local state = M.view(win)
  if state then
    Selection.clear(state)
  end
end

function M.clear_search(win)
  local state = M.view(win)
  if state then
    Search.clear(state)
  end
end

function M.set_search(win, pattern)
  local state = M.view(win)
  if state then
    Search.set(state, pattern)
  end
end

function M.get_search(win)
  local state = M.view(win)
  return state and state.search_pattern ~= "" and state.search_pattern or nil
end

function M.restore_search_reg(win)
  local state = M.view(win)
  if state then
    Search.restore(state)
  end
end

function M.update_search_prompt(win)
  local state = M.view(win)
  if state then
    Search.update_prompt(state)
  end
end

function M.lens_info(win)
  local state = M.view(win)
  return state and Search.lens_info(state) or nil
end

function M.set_mark(name, pos, win)
  return Marks.set(M.view(win), name, pos)
end

function M.get_mark(name, win)
  return Marks.get(M.view(win), name)
end

function M.del_mark(name, win)
  return Marks.delete(M.view(win), name)
end

function M.jump_back(win)
  return Jumps.back(M.view(win))
end

function M.jump_forward(win)
  return Jumps.forward(M.view(win))
end

function M.sync()
  -- Document contents are already shared by Neovim's buffer model.
  -- This command intentionally refreshes window-local derived state only.
  for win, state in pairs(M._state) do
    if api.nvim_win_is_valid(win) then
      Search.set(state, state.search_pattern)
    else
      M._state[win] = nil
    end
  end
end

function M.info()
  local state = M.current_view()
  vim.notify(vim.inspect(state), vim.log.levels.INFO, { title = "ViewSplit" })
  return state
end

function M.setup(opts)
  opts = opts or {}
  M._options = vim.tbl_deep_extend("force", M._options, opts)
  local group = api.nvim_create_augroup("ViewSplit", { clear = true })
  M._state = {}
  for _, win in ipairs(api.nvim_list_wins()) do ensure(win) end

  if M._options.search then Search.setup(M._state, group) end
  if M._options.selection then Selection.setup(M._state, group) end
  if M._options.folds then Folds.setup(M._state, group) end
  if M._options.jumps then Jumps.setup(M._state, group) end
  if M._options.scroll then Scroll.setup(M._state, group) end
  api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      for _, win in ipairs(api.nvim_list_wins()) do ensure(win) end
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local win = tonumber(ev.match)
      local state = win and M._state[win]
      if state then Search.clear(state); M._state[win] = nil end
    end,
  })
  api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function() View.capture(M.current_view()) end,
  })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local state = M.current_view()
      View.restore(state)
      if M._options.folds then Folds.restore(state) end
    end,
  })

  api.nvim_create_user_command("ViewSync", M.sync, {})
  api.nvim_create_user_command("ViewInfo", M.info, {})
  return M
end

return M
