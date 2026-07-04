# TODO — dotfiles

Personal roadmap for this stow-based dotfiles repo.
Target environment: Ubuntu 26.04 / Linux / X11, zsh-oriented. Older Ubuntu releases are out of scope unless support is added deliberately.
Already installed on this WSL machine: stow, git, gh, fzf, fd/fdfind,
ripgrep (rg), bat/batcat, eza, delta, direnv, zoxide, starship, tmux, zsh,
tldr, nvim.

Each config below should become its own stow package (same flow as tmux:
create package → parse/validate → stow → verify).

---

# Part 1 — Dotfiles tooling & configs

## 1.0 Base zsh experience

Goal: build a fast, useful, and understandable zsh setup. Shared behavior goes
into the stowed `zsh/.zshrc`; machine-specific paths, proxies, secrets, and
temporary experiments stay in `~/.zshrc.local`.

- [x] Stow-managed `~/.zshrc`
- [x] Local override via `~/.zshrc.local`
- [x] Basic history, completion, shell options, colors, and aliases
- [x] No zsh plugin manager for now; keep config framework-free and explicit
- [x] Add fzf key bindings and completion
- [x] Add smarter directory jumping with `zoxide`
- [x] Add prompt with `starship`
- [x] Add modern aliases/functions around `eza`, `bat`, `fd`, and `rg`
- [x] Add `direnv` hook for per-project environments
- [x] Keep startup fast and understandable; avoid large framework-style config
- [ ] Deferred: add `atuin` after the basic zsh workflow feels stable
- [ ] Deferred: evaluate `lazygit` later as part of the Git workflow, not base zsh

## 1.1 CLI tools to install (not present yet)
- [x] `starship` — cross-shell prompt (one config for both bash & zsh)
- [x] `zoxide` — smart `cd` (`z proj`, `zi` fuzzy jump); pairs with fzf
- [ ] Deferred: `atuin` — shell history in SQLite + fuzzy search + cross-machine sync
- [x] `eza` — modern `ls` (icons, git status, tree)
- [x] `bat` — `cat` with syntax highlight; also a pager / man colorizer
- [x] `delta` — git diff pager (side-by-side, syntax highlight)
- [x] `direnv` — auto-load per-directory `.envrc` environments
- [x] `gh` — GitHub CLI (PRs, issues, clone)

## 1.2 Config files to add (as stow packages)
- [ ] Deferred: `.gitconfig` — next Git-focused task. Wire up `delta`, add aliases, and split identity:
      use `includeIf "gitdir:..."` so personal repos use Rieide/outlook and work
      repos use the work identity automatically (fixes the earlier author-leak issue).
- [ ] `.editorconfig` — consistent indent/EOL across editors (repo root)
- [x] `starship.toml` — custom two-line prompt with git, duration, status, shell, and selected language modules
- [x] `zoxide` shell init
- [ ] Deferred: `atuin` shell init & config
- [ ] `ripgrep` config (`~/.config/ripgrep/config`) + `bat` theme
- [x] shell configs: bring `.zshrc` under stow (mind `*local*` overrides)
- [ ] Decide whether `.bashrc` still needs to be managed after zsh migration

## 1.3 Structural / reproducibility
- [x] Add best-effort `install.sh` bootstrap:
      installs the current preferred Ubuntu 26.04 toolset, logs failures loudly,
      keeps going after install failures, stows packages only when their commands
      are available afterward, and keeps secrets / machine-local files manual.
- [ ] Deferred: `packages.txt` — the environment's "requirements" (apt / cargo / brew lists)
- [ ] secrets: keep using the `*local*` gitignore pattern; if secrets must be
      committed, encrypt with `sops` + `age`
- [ ] Document Ubuntu 26.04 package expectations for Part 1 tools

## 1.4 Priority order
1. [x] Base zsh integrations: starship, fzf, zoxide, eza/bat/fd aliases, direnv
2. [ ] `.gitconfig` + `includeIf` identity split (+ delta) — solves a real pain point
3. [ ] Decide whether to add `atuin`
4. [ ] Refine `install.sh` after Ubuntu 26.04 migration feedback

---

# Part 2 — Neovim migration: LazyVim → kickstart.nvim

Goal: stop treating the working-machine Neovim + LazyVim setup as a black box.
Use the current LazyVim config only as a source snapshot, extract its full plugin
and Mason-tool inventory, then rebuild a personal Neovim environment gradually
from kickstart.nvim through real use.

This is the FULL inventory of the old working-machine LazyVim setup
(base LazyVim, no extras) — nothing pre-filtered. Tick what you want to carry over.
Source snapshot: 32 lazy.nvim plugins + 8 Mason tools, extracted 2026-07-01.

Tags: `[ks]` already in kickstart by default · `[dep]` auto-pulled dependency ·
`[drop]` distro/manager glue · untagged = genuine add-on candidate.
Plugin specs use `owner/repo` (drop straight into a lazy plugin spec).

## 2.1 All 32 plugins

### Completion / snippets
- [x] `Saghen/blink.cmp` — completion engine `[ks]`; configured auto menu,
      manual docs popup, and Tab/S-Tab candidate movement
- [ ] `rafamadriz/friendly-snippets` — snippet collection `[dep]`

### LSP / formatting / lint
- [x] `neovim/nvim-lspconfig` — LSP server configs `[ks]`; clangd tuned with
      compile database warnings
- [x] `mason-org/mason.nvim` — LSP/tool installer `[ks]`; rounded UI, no auto
      update, 48h check debounce
- [x] `mason-org/mason-lspconfig.nvim` — bridge mason ↔ lspconfig `[ks]`;
      automatic enable disabled
- [x] `stevearc/conform.nvim` — formatter runner `[ks]`; format-on-save
      disabled, manual `<leader>cf` retained
- [ ] `folke/lazydev.nvim` — Lua/nvim-config LSP dev `[ks]`
- [ ] `mfussenegger/nvim-lint` — standalone linter runner

### Treesitter / editing
- [x] `nvim-treesitter/nvim-treesitter` — syntax parsing/highlight `[ks]`
- [x] `nvim-treesitter/nvim-treesitter-textobjects` — TS-based text objects
- [x] `echasnovski/mini.ai` — better a/i text objects `[ks]`
- [ ] `echasnovski/mini.pairs` — auto-pair brackets/quotes
- [ ] `windwp/nvim-ts-autotag` — auto close/rename HTML/JSX tags
- [ ] `folke/ts-comments.nvim` — commenting enhancement (nvim 0.10+)

### UI / appearance
- [x] `folke/tokyonight.nvim` — colorscheme `[ks]`; current default is
      `tokyonight-night`
- [x] `catppuccin/nvim` — alternate colorscheme
- [x] `nvim-lualine/lualine.nvim` — statusline (vs kickstart's mini.statusline)
- [x] `akinsho/bufferline.nvim` — buffer tabs across the top
- [x] `folke/noice.nvim` — cmdline / message UI (opinionated, heavier)
- [x] `folke/snacks.nvim` — QoL suite; currently using bigfile, quickfile,
      terminal, and indent/chunk scope UI
- [x] `folke/which-key.nvim` — keymap hint popup `[ks]`
- [ ] `echasnovski/mini.icons` — icon provider `[dep]`
- [x] `MunifTanjim/nui.nvim` — UI component lib `[dep]`

### Navigation / search / git / diagnostics / sessions
- [ ] `folke/flash.nvim` — fast jump / motions
- [x] `lewis6991/gitsigns.nvim` — git gutter signs `[ks]`; signs use
      `A/M/D`, untracked files remain unattached, deeper Git workflow deferred
- [x] `MagicDuck/grug-far.nvim` — project-wide search & replace UI
- [x] `folke/trouble.nvim` — diagnostics / quickfix list UI
- [x] `folke/todo-comments.nvim` — highlight TODO/FIX/etc. `[ks]`; signs
      disabled, text highlight only
- [x] `folke/persistence.nvim` — session save & restore
- [x] `nvim-lua/plenary.nvim` — Lua utility lib `[dep]`

### Framework / manager
- [ ] `LazyVim/LazyVim` — the distro being abandoned `[drop]`
- [ ] `folke/lazy.nvim` — plugin manager `[drop]` (kickstart bundles it)

## 2.2 All 8 Mason tools (LSP / formatters — NOT plugins; install separately)

### LSP servers
- [x] clangd — C/C++
- [x] lua-language-server — Lua
- [ ] pyright — Python
- [ ] rust-analyzer — Rust
- [ ] typescript-language-server — TS/JS

### Formatters / CLI
- [x] stylua — Lua formatter
- [ ] shfmt — shell formatter
- [x] tree-sitter-cli — treesitter CLI

## 2.3 Follow-up
- [ ] Port custom keymaps/options/autocmds from old `lua/config/*`
- [x] Decide statusline: mini.statusline (kickstart) vs lualine
- [x] Add the new nvim config as its own stow package under dotfiles
- [x] Polish installed plugin behavior before adding more plugins
- [ ] Low priority: decide whether `flash.nvim`, `nvim-lint`, `lazydev.nvim`,
      Python/Rust/TypeScript LSPs, and `shfmt` are actually needed
