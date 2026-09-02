---@module 'lazy'
local function tmux_is_zoomed()
  if not vim.env.TMUX or not vim.env.TMUX_PANE then
    return false
  end

  local socket = vim.env.TMUX:match '^[^,]+'
  local output = vim.fn.system {
    'tmux',
    '-S',
    socket,
    'display-message',
    '-p',
    '-t',
    vim.env.TMUX_PANE,
    '#{window_zoomed_flag}',
  }
  return vim.v.shell_error == 0 and vim.trim(output) == '1'
end

local function navigate(nvim_command, tmux_command, tmux_direction, zellij_direction)
  return function()
    local previous_window = vim.api.nvim_get_current_win()

    if vim.env.ZELLIJ then
      vim.cmd(nvim_command)
      if vim.api.nvim_get_current_win() ~= previous_window then
        return
      end

      vim.fn.system { 'zellij', 'action', 'move-focus', zellij_direction }
      if vim.v.shell_error ~= 0 then
        vim.notify('Zellij focus navigation failed', vim.log.levels.ERROR)
      end
      return
    end

    vim.cmd(vim.env.TMUX and tmux_command or nvim_command)
    if vim.api.nvim_get_current_win() ~= previous_window or not tmux_is_zoomed() then
      return
    end

    local script = vim.fn.expand '~/.config/tmux/scripts/navigate-zoomed'
    vim.fn.system { script, tmux_direction }
    if vim.v.shell_error ~= 0 then
      vim.notify('tmux zoom navigation failed', vim.log.levels.ERROR)
    end
  end
end

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
    {
      '<C-h>',
      navigate('wincmd h', 'TmuxNavigateLeft', 'L', 'left'),
      desc = 'Move focus left across Neovim/multiplexer',
    },
    {
      '<C-j>',
      navigate('wincmd j', 'TmuxNavigateDown', 'D', 'down'),
      desc = 'Move focus down across Neovim/multiplexer',
    },
    {
      '<C-k>',
      navigate('wincmd k', 'TmuxNavigateUp', 'U', 'up'),
      desc = 'Move focus up across Neovim/multiplexer',
    },
    {
      '<C-l>',
      navigate('wincmd l', 'TmuxNavigateRight', 'R', 'right'),
      desc = 'Move focus right across Neovim/multiplexer',
    },
  },
}
