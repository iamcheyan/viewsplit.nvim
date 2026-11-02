local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local Marks = require("viewsplit.marks")
local Jumps = require("viewsplit.jumps")
local View = require("viewsplit.view")

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "top", "one", "two", "three", "bottom" })
local a = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(a, buf)
vim.cmd("vsplit")
local b = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(b, buf)

local sa, sb = View.new(a), View.new(b)
assert(Marks.set(sa, "a", { 2, 1 }))
assert(Marks.set(sb, "a", { 4, 2 }))
assert(Marks.get(sa, "a")[1] == 2 and Marks.get(sb, "a")[1] == 4, "view marks must differ")
assert(Marks.delete(sb, "a"))
assert(Marks.get(sa, "a")[1] == 2, "deleting B mark must preserve A")

sa.jumplist = {
  { bufnr = buf, lnum = 1, col = 0 },
  { bufnr = buf, lnum = 5, col = 0 },
}
sa.jump_index = 2
assert(Jumps.back(sa), "per-view jump back should move")
assert(vim.api.nvim_win_get_cursor(a)[1] == 1, "back should restore the first cursor position")
assert(Jumps.forward(sa), "per-view jump forward should move")
assert(vim.api.nvim_win_get_cursor(a)[1] == 5, "forward should restore the next cursor position")
assert(not Jumps.forward(sa), "forward should stop at the newest entry")

print("view_state_spec: OK")
