---@module 'lazy'
---@type LazySpec
return {
  'MagicDuck/grug-far.nvim',
  cmd = 'GrugFar',
  keys = {
    {
      '<leader>sR',
      function() require('grug-far').open() end,
      desc = '[S]earch and [R]eplace',
    },
  },
  ---@module 'grug-far'
  ---@type GrugFarOptionsOverride
  opts = {},
}
