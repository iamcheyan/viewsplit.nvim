local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local viewsplit = require("viewsplit")
viewsplit.setup({ selection = true })

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "one two three four",
  "multibyte: あいうえお",
})
local a = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(a, buf)
vim.cmd("vsplit")
local b = vim.api.nvim_get_current_win()

local function leave_selection(win, keys)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  vim.wait(20)
end

leave_selection(a, "vll<Esc>")
local sa = viewsplit.selection_state(a)
assert(sa and sa.segments and sa.kind == "char", "view A should retain a characterwise selection")

leave_selection(b, "vllll<Esc>")
local sb = viewsplit.selection_state(b)
assert(sb and sb.segments and sb.kind == "char", "view B should retain its characterwise selection")
assert(sa.segments[1][2][3] ~= sb.segments[1][2][3], "the two view selections should differ")
assert(viewsplit.selection_state(a).segments[1][2][3] == sa.segments[1][2][3], "view A state must survive selecting in B")
assert(vim.api.nvim_buf_get_lines(buf, 0, -1, true)[1] == "one two three four", "selection capture must not edit text")

print("selection_spec: OK")
