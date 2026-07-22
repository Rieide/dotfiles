# Quickfix Workflow Guide

This guide describes the Quickfix workflow implemented by this Neovim
configuration. It is designed for project-wide searches and other result sets
that need to survive after the picker closes.

The short version is:

```text
Telescope finds and filters results
        ↓
Quickfix keeps the chosen result set
        ↓
[q and ]q move through the work
        ↓
<leader>xQ hides or restores the panel
```

`<leader>` is the Space key in this configuration.

## 1. The Mental Model

Quickfix consists of two separate things:

1. The **Quickfix list** stores file locations and messages.
2. The **Quickfix window** is a view of that list.

Closing the window does not clear the list. This distinction is the foundation
of the workflow: the list acts as a persistent work queue, while the panel is
shown only when an overview is useful.

The tools have deliberately separate responsibilities:

| Tool | Responsibility |
|---|---|
| Telescope | Interactively search, filter, preview, and select results |
| Quickfix | Keep a project-wide result set and process it sequentially |
| Trouble | Present diagnostics, symbols, and LSP relationships |
| Grug-far | Perform interactive project-wide search and replace |
| Location List | Keep a window-local result set, such as buffer diagnostics |

Quickfix should not replace Telescope for discovery or Trouble for diagnostic
presentation. Move results into Quickfix when they become a concrete set of
locations that you intend to inspect or edit.

## 2. Keymap Reference

### Creating a list from Telescope

These mappings work inside a Telescope picker in both insert and normal mode:

| Key | Action |
|---|---|
| `<C-q>` | Send all current picker results to Quickfix and open the panel |
| `<Tab>` | Toggle the current result's selection and move down |
| `<S-Tab>` | Toggle the current result's selection and move up |
| `<M-q>` | Send only explicitly selected results and open the panel |

`<M-q>` means Alt-q. Select at least one result before using it. If the terminal
does not transmit Alt-q reliably, use `<C-q>` for the full result set until the
terminal mapping is corrected.

### Opening, closing, and navigating

| Key | Action |
|---|---|
| `<leader>xQ` | Toggle the native Quickfix panel |
| `[q` | Jump to the previous Quickfix item |
| `]q` | Jump to the next Quickfix item |
| `[Q` | Jump to the first Quickfix item |
| `]Q` | Jump to the last Quickfix item |

The panel opens at the bottom with a height of 12 lines. Trying to open it with
an empty list produces a notification instead of an empty window.

The jump mappings work whether the panel is visible or hidden. A successful
jump recenters the destination in the source window. At either end of the list,
the configuration reports that there is no earlier or later item instead of
wrapping silently.

### Working inside the panel

The Quickfix window keeps the useful native behavior and adds one local key:

| Key | Action |
|---|---|
| `j` / `k` | Move the list cursor down or up |
| `<CR>` | Open the item under the cursor |
| `q` | Close the Quickfix window |

Moving with `j` and `k` only changes the row selected in the panel. Press
`<CR>` when you want to open that location. By contrast, `[q` and `]q` directly
jump between source locations.

## 3. Daily Workflows

### Workflow A: Review every project-wide match

Use this when every match is likely to need inspection.

1. Start live grep with `<leader>sg` or `<leader>fg`.
2. Enter the search expression and narrow the result set.
3. Press `<C-q>` to send the current result set to Quickfix.
4. Inspect the overview in the bottom panel.
5. Press `q` to reclaim screen space if the overview is no longer needed.
6. Use `]q` to move forward and `[q` to move backward while editing.
7. Press `<leader>xQ` whenever you need the overview again.

Example task:

```text
Search for: vim.keymap.set
Review:      every mapping definition across the configuration
```

### Workflow B: Build a curated work queue

Use this when the search is broad but only some results matter.

1. Open a Telescope search.
2. Move through the results.
3. Mark useful rows with `<Tab>`; use `<S-Tab>` when moving upward.
4. Press `<M-q>` to send only the marked rows to Quickfix.
5. Process the curated queue with `]q` and `[q`.

This is useful for tasks such as reviewing only configuration declarations
while ignoring comments, examples, generated files, or unrelated call sites.

### Workflow C: Keep working with the panel hidden

The panel is optional after the list has been created.

```text
<C-q>       create the list and open the panel
q           hide the panel
]q          edit the next location
]q          continue forward
[q          revisit the previous location
<leader>xQ  restore the overview
```

This is the recommended editing loop because the source buffer retains most of
the screen while Quickfix still owns the ordered result set.

### Workflow D: Review Git hunks

Gitsigns is another Quickfix producer in this configuration:

| Key | Result source |
|---|---|
| `<leader>hq` | Hunks in the current file |
| `<leader>hQ` | Hunks across the repository |

After creating the list, use the same `<leader>xQ`, `[q`, `]q`, `[Q`, and `]Q`
workflow. Quickfix navigation is intentionally independent of the tool that
created the list.

### Workflow E: Handle multiple LSP targets

Telescope-backed LSP pickers, such as references and definitions, support the
same `<C-q>` and selection workflow as other Telescope pickers.

The custom declaration navigation also uses Quickfix when the language server
returns multiple locations. This means the navigation keys remain the same
after either a text search or an LSP request produces a multi-location result.

For an overview focused on LSP relationships rather than an editing queue,
continue to prefer Trouble:

```text
<leader>xl  LSP definitions/references
<leader>xx  workspace diagnostics
<leader>xX  current-buffer diagnostics
```

## 4. Quickfix Versus Location List

They use the same window filetype but have different scopes:

| List | Scope | Typical use here |
|---|---|---|
| Quickfix | Global to the Neovim session | Project searches, Git hunks, multiple locations |
| Location List | Attached to one window | Diagnostics or window-specific results |

`<leader>q` calls `vim.diagnostic.setloclist`, so it creates a diagnostic
Location List rather than a Quickfix list. `<leader>xL` displays a Location List
through Trouble.

Inside either a native Quickfix or Location List window, `q` closes the correct
kind of window. The `[q` and `]q` mappings are specifically for the global
Quickfix list.

## 5. Native Commands Worth Knowing

The personal mappings cover the daily loop, but these native commands make the
behavior easier to understand and provide a fallback:

| Command | Meaning |
|---|---|
| `:copen` | Open the current Quickfix list |
| `:cclose` | Close the Quickfix window |
| `:cnext` / `:cprevious` | Jump to the next or previous item |
| `:cfirst` / `:clast` | Jump to the first or last item |
| `:cc {number}` | Jump directly to an item number |
| `:chistory` | Show Quickfix list history |
| `:colder` / `:cnewer` | Move through older or newer Quickfix lists |

Quickfix history has no custom keymaps in this design. Use it manually when a
new search replaces a useful list, and add mappings only if this becomes a
frequent part of the workflow.

To deliberately clear the current list:

```vim
:lua vim.fn.setqflist({}, 'r')
```

After it is cleared, `<leader>xQ` reports that the list is empty.

## 6. Behavioral Rules

The implementation follows these rules:

- Sending Telescope results replaces the active Quickfix contents; it does not
  append unrelated searches into one queue.
- The Quickfix list is a snapshot. Continuing to type in a new Telescope search
  does not update an already-created list.
- Closing the panel preserves the list.
- Navigation does not wrap at the first or last item.
- Opening a source item does not automatically close the panel.
- No plugin owns the Quickfix display; the panel is Neovim's native window.
- Trouble remains responsible for diagnostics, symbols, and LSP-oriented views.
- Grug-far remains responsible for project-wide replacement.

These boundaries keep the workflow predictable and prevent multiple plugins
from presenting different frontends for the same Quickfix state.

## 7. Troubleshooting

### “Quickfix list is empty”

No producer has populated the current list, or it was deliberately cleared.
Run a Telescope search and press `<C-q>`, or create a list through Gitsigns or
an LSP multi-location result.

### Alt-q does not send selected results

Some terminal or tmux configurations handle Meta keys differently. Confirm that
Alt-q reaches Neovim as `<M-q>`. Until then, use `<C-q>` to send all filtered
results. Avoid substituting `<C-s>`, because terminal flow control can consume
that key.

### The list contains stale or invalid locations

Quickfix stores a snapshot of filenames and positions. If files were renamed,
deleted, or heavily edited, rerun the producer and replace the list.

### `j` and `k` do not open the source file

That is intentional. They browse rows inside the panel. Press `<CR>` to open the
selected row, or use `[q` and `]q` for direct source-to-source navigation.

### Trouble does not open with `<leader>xQ`

Also intentional. `<leader>xQ` now controls the native Quickfix window. Trouble
is still available through its diagnostic, symbol, LSP, and Location List
mappings.

## 8. Practice Exercises

### Exercise 1: Full result set

1. Run `<leader>sg`.
2. Search for `vim.keymap.set`.
3. Press `<C-q>`.
4. Close the panel with `q`.
5. Visit several matches with `]q` and `[q`.
6. Restore the panel with `<leader>xQ`.

### Exercise 2: Selected result set

1. Search for `require` with Telescope.
2. Select three useful results with `<Tab>`.
3. Press `<M-q>`.
4. Confirm that only those three entries are in Quickfix.
5. Jump to the first and last entries with `[Q` and `]Q`.

### Exercise 3: Compare scopes

1. Create a project-wide Quickfix list from Telescope.
2. Open diagnostics with `<leader>q` to create a Location List.
3. Observe that the two lists have different scopes and producers.
4. Close either native list window with `q`.

### Exercise 4: Use Quickfix as a work queue

1. Search for a small cleanup target across several files.
2. Send the matches to Quickfix.
3. Hide the panel.
4. Edit one location at a time with `]q`.
5. Reopen the panel at the end to review the remaining context.

## 9. Configuration Reference

The workflow is implemented in these files:

- [Quickfix module](.config/nvim/lua/custom/quickfix.lua): panel toggle,
  navigation, notifications, and the local `q` mapping
- [Telescope configuration](.config/nvim/lua/custom/plugins/telescope.lua):
  sending all or selected picker results to Quickfix
- [Trouble configuration](.config/nvim/lua/custom/plugins/trouble.lua):
  diagnostics, symbols, LSP, and Location List ownership
- [Main configuration](.config/nvim/init.lua): diagnostic Location List setup
- [Practice notes](PRACTICE.md): compact daily-use reference

No additional Quickfix plugin is required.
