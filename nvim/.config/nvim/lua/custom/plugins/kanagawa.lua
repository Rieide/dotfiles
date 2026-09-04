---@module 'lazy'
---@type LazySpec
return {
  'rebelot/kanagawa.nvim',
  lazy = false,
  priority = 1000,
  config = function() vim.cmd.colorscheme 'deepseek-wave' end,
}
