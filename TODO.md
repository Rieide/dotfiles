# TODO — dotfiles

Maintained roadmap for this GNU Stow-based dotfiles repository.

The active development and deployment baseline is Ubuntu 26.04 Linux with zsh
as the interactive shell. Older Ubuntu releases remain out of scope unless
support is added deliberately; the installer may attempt target steps there,
but does not add compatibility branches.

The checked items below describe the current repository baseline. Unchecked items
are actual follow-up work. `install.sh`, the stowed configuration, and Neovim's
`lazy-lock.json` are the source of truth for tools and plugins managed by this
repository; they do not claim to describe everything currently installed on a
particular machine. This file should not duplicate historical inventories.

Shared behavior belongs in this repository. Machine identity, private paths,
proxies, tokens, and experiments belong in local files such as
`~/.zshrc.local` and `~/.gitconfig.local`.

---

## 1. Current baseline

### Bootstrap and repository structure

- [x] Manage `git`, `lazygit`, `nvim`, `starship`, `tmux`, and `zsh` as Stow
      packages.
- [x] Provide a best-effort Ubuntu 26.04 bootstrap with install-only,
      stow-only, skip-remote, and dry-run modes.
- [x] Log installation failures, continue independent work, print the final
      summary, return 2 when it contains `FAILED`, and reserve 1 for fatal
      bootstrap errors.
- [x] Inventory installed versions and providers before mutation, skip satisfied
      tools, enforce configuration-driven minimums, and summarize per-tool
      postconditions in a table.
- [x] Treat Neovim as Snap-only: install Snap for apt-only machines, refresh a
      below-minimum Snap, leave the apt package untouched, and prefer `/snap/bin`.
- [x] Keep secrets and machine-local overrides out of Git via `*local*`
      ignore rules.
- [x] Keep package requirements in the auditable arrays in `install.sh` rather
      than maintaining a duplicate `packages.txt`.
- [x] Provide reusable `.editorconfig` and `.clang-format` project templates.

### Shell and CLI

- [x] Configure zsh history, completion, options, colors, aliases, and a local
      override loaded from `~/.zshrc.local`.
- [x] Integrate fzf, zoxide, direnv, Starship, and zsh-autosuggestions
      defensively so missing optional commands do not break shell startup.
- [x] Register `~/.local/bin` and `/snap/bin` without requiring those directories
      to exist when the shared shell configuration is loaded.
- [x] Add Ubuntu command-name compatibility for `batcat` and `fdfind`, plus
      eza-based `ls`, `ll`, `la`, and `tree` aliases when eza is available.
- [x] Keep zsh framework-free and avoid a shell plugin manager.
- [x] Configure Starship with Git state, language context, command duration,
      exit status, sudo state, and background jobs.

### tmux

- [x] Configure zsh, true color, mouse support, vi copy mode, `C-a` prefix,
      path-aware splits, Vim-style pane navigation, resizing, and popups.
- [x] Install TPM, `tmux-sensible`, `tmux-resurrect`, `tmux-continuum`, and
      vim-tmux-navigator at pinned commits without startup-time cloning or
      plugin updates.
- [x] Use a sesh/fzf popup for tmux and zoxide sessions, add seamless
      Neovim/tmux navigation, keep safe layout-only persistence, and retain the
      Lazygit popup and current xclip bindings.
- [x] Keep the repository-managed tmux config and pinned plugins under
      `~/.config/tmux` working with a custom `XDG_CONFIG_HOME`, and make the
      picker repair its managed PATH for an already-running tmux server.

### Git

- [x] Track a shared Git configuration with Neovim as editor, Delta as pager,
      `zdiff3` conflicts, fast-forward-only pulls, current-branch pushes, and
      practical aliases.
- [x] Include `~/.gitconfig.local` for local overrides.
- [x] Keep the public identity as the shared fallback; leave private identity
      overrides absent on the personal U26 machine unless a real need appears.
- [x] Deploy the shared Git configuration through Stow without committing the
      private identity files.
- [x] Add a global commit-time identity guard that checks author and committer
      against the path-selected profile and rejects unexpected overrides.
- [x] Add an isolated Git identity security regression suite covering multiple
      paths, common override attempts, private-file permissions, and the
      documented client-side hook bypass boundary.
- [x] Install and configure Lazygit with Neovim editing and Delta paging; expose
      it through the terminal, tmux popup, and Neovim Snacks integration.
- [x] Scan staged content with a global Gitleaks hook when available, warn and
      continue when the preferred binary is missing, keep full-history scans
      manual, and document the standard `--no-verify` bypass.

### Neovim

- [x] Replace the old LazyVim setup with a readable Kickstart-based
      configuration managed by lazy.nvim.
- [x] Use Telescope for picking/search, Neo-tree for files, bufferline for the
      buffer UI, lualine for statusline/winbar, Trouble for diagnostics and
      symbols, and Noice for message history while retaining the classic
      bottom command line.
- [x] Keep Snacks limited to low-conflict modules: bigfile, quickfile,
      terminal, and indent/chunk scope UI.
- [x] Configure LSP for C/C++ (`clangd`), Python (`pyright`), TypeScript, and
      Lua, including clangd compile-database warnings and source/header switch.
- [x] Configure blink.cmp, LuaSnip, friendly-snippets, lazydev, Treesitter,
      Treesitter text objects, autopairs, and mini.ai/mini.surround.
- [x] Keep formatting intentional: Conform uses Stylua and clang-format, with
      format-on-save disabled and `<leader>cf` for manual formatting.
- [x] Lint shell files with ShellCheck and Python with Ruff through nvim-lint.
- [x] Let Mason manage the current 10-tool set:
      `clang-format`, `clangd`, `lua-language-server`, `pyright`, `ruff`,
      `shellcheck`, `shfmt`, `stylua`, `tree-sitter-cli`, and
      `typescript-language-server`.
- [x] Use Kanagawa Wave as the active theme; keep Tokyo Night, Catppuccin,
      Rose Pine, and Sonokai as alternatives.
- [x] Document daily workflows and learning priorities in
      `nvim/PRACTICE.md`.

---

## 2. Next work — reproducibility gaps

Work through these before adding another large group of editor plugins.

### Missing commands used by existing configuration

- [ ] Add `build-essential` (or at minimum `make`) and `unzip` to the bootstrap.
      Neovim health checks require them, telescope-fzf-native builds with
      `make`, and LuaSnip can build its regex module with `make`.
- [ ] Install and verify `xclip` for the current tmux clipboard bindings.
- [ ] Add `wl-clipboard` support and select `wl-copy` on Wayland while retaining
      `xclip` as the X11 fallback.

### Bootstrap validation

- [ ] Add a repository check command or script covering at least:
      `bash -n install.sh`, zsh syntax, `git diff --check`, and a headless
      Neovim startup.
- [ ] Add ShellCheck coverage for `install.sh`; keep Neovim's Mason-managed
      ShellCheck for editor diagnostics, but make repository validation easy to
      run outside Neovim.
- [ ] Test `install.sh --dry-run` and Stow conflict handling in a temporary
      HOME so bootstrap changes cannot overwrite a real home directory.
- [x] Validate bootstrap/package changes on the Ubuntu 26.04 WSL baseline and
      review a successful real-bootstrap log.

---

## 3. Optional workflow enhancements

These are candidates, not commitments. Add them only after confirming a real
workflow need.

### Shell and CLI

- [ ] Evaluate Atuin locally first. The zsh hook already exists; if adopted,
      add installation, a stowed config, history import instructions, and
      privacy filters before enabling synchronization.
- [ ] Add a ripgrep config and Bat theme only when there are concrete defaults
      worth sharing across machines.
- [ ] Evaluate `mise` for language/tool versions and task definitions without
      duplicating direnv's per-directory environment role.
- [ ] Evaluate `uv` if Python project and virtual-environment management becomes
      part of the regular workflow.
- [ ] Evaluate Yazi as a terminal file manager, preferably through a tmux popup
      rather than as another Neovim file-tree plugin.

### Git

- [ ] Evaluate `sindrets/diffview.nvim` only if reviewing multi-file diffs,
      renamed-file history, or three-way conflicts inside Neovim becomes more
      useful than the existing Gitsigns, Delta, and Lazygit workflow.
- [ ] Adopt Git LFS only for a repository that actually tracks large binary
      assets; review its filters, remote storage, and pre-push hook interaction
      before enabling it.
- [ ] Install `git-filter-repo` only for a deliberate history rewrite or
      recovery task, such as removing a leaked secret or oversized object.
- [ ] Evaluate `git-absorb` only after the standard fixup and autosquash workflow
      is familiar and multi-commit feature branches make automation worthwhile.
- [ ] Evaluate Difftastic as an optional syntax-aware difftool for large
      refactors; keep Delta as the default line-oriented pager.

### Neovim

- [ ] Add `nvim-dap` only when an actual debugging workflow is ready. Start
      with `codelldb` for C/C++ and/or `debugpy` for Python; add a UI extension
      only after the core mappings work.
- [ ] Evaluate `overseer.nvim` for repeatable build, run, and test tasks,
      especially for C/C++ projects whose output should feed quickfix or
      diagnostics.
- [ ] Evaluate Neotest only after choosing concrete test adapters. Prefer
      Overseer for custom C++/Bazel workflows that do not map cleanly to a
      Neotest adapter.
- [ ] Enable `nvim-web-devicons` only after setting up a Nerd Font and changing
      `vim.g.have_nerd_font`; it is currently declared conditionally and not
      installed in the lockfile.

Avoid adding replacements for capabilities already owned by Telescope,
Neo-tree, bufferline, Trouble, Noice, Snacks, or Grug-far unless the existing
tool has a demonstrated limitation.
