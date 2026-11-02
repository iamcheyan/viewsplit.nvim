local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local viewsplit = require("viewsplit")
viewsplit.setup({ selection = true })

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one two three four" })
local a = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(a, buf)
vim.cmd("vsplit")
local b = vim.api.nvim_get_current_win()

local function select_in_window(win, keys)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  vim.wait(30)
end

select_in_window(a, "vll<Esc>")
local sa = viewsplit.selection_state(a)
assert(sa and sa.first and sa.last,
  "view A should retain its selection as view state")

select_in_window(b, "vllll<Esc>")
local sb = viewsplit.selection_state(b)
assert(sb and sb.first and sb.last,
  "view B should retain its selection as view state")
assert(sa.first[2] ~= sb.first[2] or sa.last[2] ~= sb.last[2], "the selections should differ")
assert(viewsplit.selection_state(a).last[2] == sa.last[2], "switching to B must not overwrite A selection")

print("selection_spec: OK")
