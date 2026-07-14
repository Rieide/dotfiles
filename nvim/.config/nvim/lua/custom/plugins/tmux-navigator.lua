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

local function navigate(command, tmux_direction)
  return function()
    local previous_window = vim.api.nvim_get_current_win()
    vim.cmd(command)
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
    { '<C-h>', navigate('TmuxNavigateLeft', 'L'), desc = 'Move focus left across Neovim/tmux' },
    { '<C-j>', navigate('TmuxNavigateDown', 'D'), desc = 'Move focus down across Neovim/tmux' },
    { '<C-k>', navigate('TmuxNavigateUp', 'U'), desc = 'Move focus up across Neovim/tmux' },
    { '<C-l>', navigate('TmuxNavigateRight', 'R'), desc = 'Move focus right across Neovim/tmux' },
  },
}
