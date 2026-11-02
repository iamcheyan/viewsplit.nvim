local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local folds = require("viewsplit.folds")
local function fold_state(win)
  return vim.api.nvim_win_call(win, function() return vim.fn.foldclosed(3) end)
end
local api = vim.api

local buf = api.nvim_create_buf(true, false)
api.nvim_buf_set_lines(buf, 0, -1, false, {
  "head", "start {{{", "inside one", "inside two", "end }}}", "tail",
})
local a = api.nvim_get_current_win()
api.nvim_win_set_buf(a, buf)
api.nvim_win_set_option(a, "foldmethod", "marker")
api.nvim_win_set_option(a, "foldlevel", 0)
api.nvim_win_set_option(a, "foldenable", true)
vim.cmd("vsplit")
local b = api.nvim_get_current_win()
api.nvim_win_set_buf(b, buf)
api.nvim_win_set_option(b, "foldmethod", "marker")
api.nvim_win_set_option(b, "foldlevel", 0)
api.nvim_win_set_option(b, "foldenable", true)

api.nvim_set_current_win(a)
api.nvim_win_set_cursor(a, { 3, 0 })
vim.cmd("normal! zc")
assert(fold_state(a) == 2, "view A should close marker fold")
local sa = { winid = a }
folds.capture(sa)

api.nvim_set_current_win(b)
api.nvim_win_set_option(b, "foldmethod", "marker")
api.nvim_win_set_option(b, "foldlevel", 99)
vim.cmd("normal! zR")
assert(fold_state(b) == -1, "view B should initially remain open")
api.nvim_win_call(b, function()
  vim.api.nvim_win_set_cursor(b, { 3, 0 })
  vim.cmd("normal! zc")
end)
local sb = { winid = b }
folds.capture(sb)
assert(fold_state(b) == 2, "view B should have its own closed fold")

api.nvim_set_current_win(a)
folds.restore(sa)
assert(fold_state(a) == 2, "restoring view A should restore its fold")
api.nvim_set_current_win(b)
folds.restore(sb)
assert(fold_state(b) == 2, "restoring view B should restore its fold")

print("folds_spec: OK")
