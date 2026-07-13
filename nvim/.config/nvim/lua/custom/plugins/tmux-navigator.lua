---@module 'lazy'
---@type LazySpec
return {
  'christoomey/vim-tmux-navigator',
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatorProcessList',
  },
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
    vim.g.tmux_navigator_no_wrap = 1
    vim.g.tmux_navigator_preserve_zoom = 1
    vim.g.tmux_navigator_disable_when_zoomed = 0
    vim.g.tmux_navigator_save_on_switch = 0
  end,
  keys = {
    { '<C-h>', '<cmd><C-U>TmuxNavigateLeft<CR>', desc = 'Move focus left across Neovim/tmux' },
    { '<C-j>', '<cmd><C-U>TmuxNavigateDown<CR>', desc = 'Move focus down across Neovim/tmux' },
    { '<C-k>', '<cmd><C-U>TmuxNavigateUp<CR>', desc = 'Move focus up across Neovim/tmux' },
    { '<C-l>', '<cmd><C-U>TmuxNavigateRight<CR>', desc = 'Move focus right across Neovim/tmux' },
  },
}
