---@module 'lazy'
---@type LazySpec
return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = true,
  priority = 1000,
  ---@module 'catppuccin'
  ---@type CatppuccinOptions
  opts = {
    flavour = 'mocha',
  },
}
