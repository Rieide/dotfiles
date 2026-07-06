---@module 'lazy'
---@type LazySpec
return {
  'rebelot/kanagawa.nvim',
  lazy = false,
  priority = 1000,
  ---@module 'kanagawa'
  ---@type KanagawaConfig
  opts = {
    theme = 'wave',
    commentStyle = { italic = false },
    keywordStyle = { italic = false },
  },
  config = function(_, opts)
    require('kanagawa').setup(opts)
    vim.cmd.colorscheme 'kanagawa'
  end,
}
