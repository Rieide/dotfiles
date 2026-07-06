---@module 'lazy'
---@type LazySpec
return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  ---@module 'flash'
  ---@type Flash.Config
  opts = {},
  keys = {
    {
      '<leader>j',
      function() require('flash').jump() end,
      mode = { 'n', 'x', 'o' },
      desc = '[J]ump with Flash',
    },
    {
      '<leader>J',
      function() require('flash').treesitter() end,
      mode = { 'n', 'x', 'o' },
      desc = '[J]ump Treesitter with Flash',
    },
  },
}
