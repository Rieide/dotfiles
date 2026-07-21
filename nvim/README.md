# Neovim Config

Stow package for `~/.config/nvim`.

Neovim's main configuration entrypoint is usually `init.lua` or `init.vim` in
`~/.config/nvim`. This package starts from a kickstart.nvim-style setup and
should grow gradually through real use instead of copying a full distribution
blindly.

Current migration state:

- stowed as the active `~/.config/nvim` package
- based on kickstart.nvim with local plugin modules under
  `lua/custom/plugins`
- Telescope is the primary picker
- native Quickfix is the persistent result list for searches and other
  multi-location producers
- Neo-tree is the file explorer
- bufferline owns the top buffer UI and visible-buffer number jumps
- lualine owns the statusline and winbar
- Noice owns message UI while keeping the classic bottom cmdline
- Snacks is limited to low-conflict modules: bigfile, quickfile, terminal, and
  indent/chunk scope UI
- Conform has format-on-save disabled; use `<leader>cf` for intentional manual
  formatting
- clangd is configured with compile database warnings for C/C++ buffers

Practice notes for daily Neovim use live in `PRACTICE.md`.

A proposed profiler workflow covering source heat annotations, a compact
hotspot sidebar, and a Snacks-hosted flamegraph panel is documented in
[`PERF_VISUALIZATION_PLAN.md`](PERF_VISUALIZATION_PLAN.md). It is a plan, not
part of the current baseline.

Useful validation commands:

```sh
/snap/bin/nvim --headless '+lua print("nvim-ok")' '+quitall'
git diff --check
```

For clean bootstrap simulation, use temporary XDG directories before running
Lazy sync:

```sh
XDG_DATA_HOME=/tmp/nvim-data-bootstrap \
XDG_CACHE_HOME=/tmp/nvim-cache-bootstrap \
XDG_STATE_HOME=/tmp/nvim-state-bootstrap \
/snap/bin/nvim --headless '+Lazy! sync' '+quitall'
```
