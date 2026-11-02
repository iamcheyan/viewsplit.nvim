local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local Selection = require("viewsplit.selection")
local states = { [1] = { winid = 1 }, [2] = { winid = 2 } }

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "AあBC", "second", "third" })
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)
local another = nil
vim.cmd("vsplit")
another = vim.api.nvim_get_current_win()
win = vim.api.nvim_list_wins()[1]
states = { [win] = { winid = win }, [another] = { winid = another } }
local group = vim.api.nvim_create_augroup("SelectionRegionsSpec", { clear = true })
Selection.setup(states, group)

local function select(keys)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  vim.wait(20)
end

vim.o.selection = "inclusive"
vim.api.nvim_set_current_win(win)
select("vlll<Esc>")
local char = states[win].selection
assert(char and char.kind == "char", "characterwise range captured")
assert(char.segments[1][1][3] == 1 and char.segments[1][2][3] == 6, "multibyte character selection uses byte boundaries")

vim.o.selection = "exclusive"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abcdef", "second", "third" })
vim.api.nvim_set_current_win(win)
select("vlll<Esc>")
local exclusive = states[win].selection
assert(exclusive.segments[1][1][3] == 1 and exclusive.segments[1][1][4] == 0, "exclusive selection starts at byte 1")
assert(exclusive.segments[1][2][3] == 3 and exclusive.segments[1][2][4] == 0, "exclusive selection ends at byte 3")
vim.o.selection = "inclusive"
vim.api.nvim_set_current_win(another)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abcdef", "second", "third" })
select("Vj<Esc>")
local linewise = states[another].selection
assert(linewise and linewise.kind == "line" and #linewise.segments == 1, "linewise selection returns one range spanning selected lines")

vim.api.nvim_set_current_win(another)
vim.api.nvim_win_set_cursor(another, { 1, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>llj<Esc>", true, false, true), "xt", false)
vim.wait(20)
local block = states[another].selection
assert(block and block.kind == "block", "blockwise selection kind captured")
assert(#block.segments >= 2, "blockwise region emits per-line segments")

print("selection_regions_spec: OK")
