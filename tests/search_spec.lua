local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)

local viewsplit = require("viewsplit")
viewsplit.setup({ selection = true })

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "config nvim config nvim" })
local a = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(a, buf)
vim.cmd("vsplit")
local b = vim.api.nvim_get_current_win()

local function search(win, pattern)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("/" .. pattern .. "<CR>", true, false, true), "xt", false)
  vim.wait(30)
end

search(a, "config")
search(b, "nvim")
assert(not vim.o.hlsearch, "viewsplit must not enable global hlsearch")
assert(viewsplit.current_view().search_pattern == "nvim", "current view should expose its own pattern")

vim.api.nvim_set_current_win(a)
assert(vim.fn.getreg("/") == "config", "entering view A should restore its search register")
vim.api.nvim_set_current_win(b)
assert(vim.fn.getreg("/") == "nvim", "entering view B should restore its search register")

local ma, mb = vim.fn.getmatches(a), vim.fn.getmatches(b)
assert(#ma == 1 and ma[1].pattern == "config", "view A should retain only its own match")
assert(#mb == 1 and mb[1].pattern == "nvim", "view B should retain only its own match")

-- Regression: a saved session script or plugin setting `set hlsearch` must be
-- intercepted so switching views and restoring `@/` never globally illuminates
-- one split's search pattern inside the other split.
vim.cmd("set hlsearch")
assert(not vim.o.hlsearch, "OptionSet guard must keep global hlsearch disabled")
vim.api.nvim_set_current_win(a)
assert(not vim.o.hlsearch, "switching to view A must keep global hlsearch disabled")
print("search_spec: OK")
