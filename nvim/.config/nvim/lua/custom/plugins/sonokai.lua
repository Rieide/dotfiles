---@module 'lazy'
---@type LazySpec
return {
  'sainnhe/sonokai',
  lazy = false,
  priority = 1000,
  init = function()
    vim.g.sonokai_style = 'default'
    vim.g.sonokai_enable_italic = 0
    vim.g.sonokai_better_performance = 1
  end,
}
