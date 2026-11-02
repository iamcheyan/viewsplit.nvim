local M = {}
local api = vim.api
local View = require("viewsplit.view")
local Search = require("viewsplit.search")
local Selection = require("viewsplit.selection")

M._state = {}
M._options = { search = true, folds = false, jumps = false, marks = false, selection = false }

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
  api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(api.nvim_list_wins()) do ensure(win) end
      end)
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
    callback = function() View.restore(M.current_view()) end,
  })

  api.nvim_create_user_command("ViewSync", M.sync, {})
  api.nvim_create_user_command("ViewInfo", M.info, {})
  return M
end

return M
