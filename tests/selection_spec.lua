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
vim.api.nvim_set_current_win(b)
assert(viewsplit.selection_state(b) == nil, "a view with no Visual selection must not have a phantom range")
vim.api.nvim_win_set_cursor(b, { 1, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v", true, false, true), "xt", false)
vim.wait(20)
local active = viewsplit.selection_state(b)
assert(active and active.active and active.segments[1][1][3] == 1, "entering Visual mode captures the live anchor position")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "xt", false)
vim.wait(20)
local escaped = viewsplit.selection_state(b)
assert(escaped and escaped.segments[1][1][3] == 1 and escaped.segments[1][2][3] == 1, "Escape saves a one-character selection at the cursor")

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

-- Regression: switching windows while Visual mode is active must capture the
-- leaving window's exact range, exit Visual mode in the target window, and
-- never overwrite the leaving window's selection when selecting in the target.
vim.api.nvim_set_current_win(a)
vim.api.nvim_win_set_cursor(a, { 1, 0 })
vim.api.nvim_feedkeys("vll", "xt", false) -- select "one" (bytes 1..3)
vim.api.nvim_set_current_win(b)
assert(vim.api.nvim_get_mode().mode == "n", "entering target split must exit Visual mode")
local sa_switch = viewsplit.selection_state(a)
assert(sa_switch and not sa_switch.active and sa_switch.segments[1][1][3] == 1 and sa_switch.segments[1][2][3] == 3,
  "leaving view A in Visual mode must save its exact range (1..3)")

vim.api.nvim_win_set_cursor(b, { 1, 4 })
vim.api.nvim_feedkeys("vll", "xt", false) -- select "two" (bytes 5..7)
vim.api.nvim_set_current_win(a)
assert(vim.api.nvim_get_mode().mode == "n", "switching back to view A must exit Visual mode")
local sa_back = viewsplit.selection_state(a)
local sb_back = viewsplit.selection_state(b)
assert(sa_back and sa_back.segments[1][1][3] == 1 and sa_back.segments[1][2][3] == 3,
  "view A saved selection must not be overwritten when switching back from B")
assert(sb_back and sb_back.segments[1][1][3] == 5 and sb_back.segments[1][2][3] == 7,
  "view B saved selection must be preserved (5..7)")

-- Regression: clear_selection clears only the specified window's selection.
viewsplit.clear_selection(a)
assert(viewsplit.selection_state(a) == nil, "clear_selection(a) must clear view A selection")
assert(viewsplit.selection_state(b) ~= nil, "clear_selection(a) must preserve view B selection")

-- Regression: operator in Visual mode (e.g. yank `y`) clears the selection instead of leaving a stale overlay.
vim.api.nvim_set_current_win(b)
vim.api.nvim_win_set_cursor(b, { 1, 0 })
vim.api.nvim_feedkeys("vlly", "xt", false)
assert(viewsplit.selection_state(b) == nil, "yanking a Visual selection must clear the saved selection")

print("selection_spec: OK")
