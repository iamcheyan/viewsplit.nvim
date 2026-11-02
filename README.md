# viewsplit.nvim

A small Neovim 0.12+ plugin for managing view-local state across windows that show the same buffer.

The document remains one Neovim buffer. Buffer text, undo history, diagnostics, Treesitter, and Git integrations keep Neovim's normal shared behavior. View state is keyed by window ID.

## Installation

```lua
{
  "viewsplit.nvim",
  opts = {
    search = true,
    selection = false,
  },
}
```

Or call the public setup function directly:

```lua
require("viewsplit").setup()
```

Calling `setup()` with no options enables the implemented per-window search layer. Other behavior remains opt-in.

## Implemented

### Window-local search

Each view remembers its own `/` or `?` search pattern and window-local match. Entering a view restores its pattern to Neovim's search register so `n` and `N` continue that view's search. Global `hlsearch` stays disabled to avoid painting every split with the same search register.

```lua
require("viewsplit").setup({ search = true })
```

The search layer uses `matchadd(..., { window = win })`. It does not take over mappings for `n`/`N` or alter plugin configuration.

### Selection state (experimental)

Set `selection = true` to retain characterwise Visual selection coordinates per view and render saved selections for inactive sibling windows through Neovim 0.12's per-window ephemeral decoration provider. Neovim still has only one active native Visual selection; the plugin draws saved selections as overlays. Linewise/blockwise fidelity, exclusive-selection semantics and tracking a range through edits need further validation.

## API

- `setup(opts)` — initialize the plugin; repeated calls replace its autocmd group.
- `current_view()` — return the state table for the focused window.
- `view(winid)` — return state for a window.
- `current_view_id()` — return the focused window ID.
- `selection_state(winid)` — return the saved selection, if enabled and captured.
- `:ViewInfo` — show the focused view's state.
- `:ViewSync` — reapply stored window-local search matches.

View state is currently process-local and keyed by `winid`; it is discarded when a window closes.

## Tests

Run with Neovim 0.12 or newer:

```sh
nvim --headless -u NONE -l tests/search_spec.lua
nvim --headless -u NONE -l tests/selection_spec.lua
```

If `nvim-hlslens` is installed at the normal lazy.nvim data path, the search spec also loads its current implementation with incremental search disabled, matching the configuration used alongside this plugin.

## Roadmap

The full view-state model is staged so each layer can be tested without changing document semantics:

1. Search register, count/prompt behavior, and search highlighting.
2. Fold and viewport restoration.
3. Per-view jump history and cursor history.
4. Named per-view marks.
5. Independent Visual selections and plugin compatibility.
6. Compatibility checks for lazy.nvim, hlslens, satellite, flash, Treesitter, Snacks, mini.nvim, and blink.cmp.

The current release is an early implementation of the first layer plus experimental characterwise selection snapshots. The remaining stages are not implemented yet.
