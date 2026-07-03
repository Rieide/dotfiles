# Neovim Config

Stow package for `~/.config/nvim`.

Neovim's main configuration entrypoint is usually `init.lua` or `init.vim` in
`~/.config/nvim`. This package starts from a kickstart.nvim-style setup and
should grow gradually through real use instead of copying a full distribution
blindly.

Current migration state:

- imported the current kickstart `init.lua`
- imported the kickstart health helper
- imported the empty `lua/custom/plugins/init.lua` extension point
- imported `.stylua.toml` and `lazy-lock.json`

The package is not stowed yet because the same files still exist as regular
files under `~/.config/nvim`. Stow ownership should be switched deliberately
after the imported snapshot is reviewed.
