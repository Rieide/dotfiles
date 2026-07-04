-- Add indentation guides even on blank lines

---@module 'lazy'
---@type LazySpec
return {
  'lukas-reineke/indent-blankline.nvim',
  enabled = false,
  -- Enable `lukas-reineke/indent-blankline.nvim`
  -- See `:help ibl`
  main = 'ibl',
  ---@module 'ibl'
  ---@type ibl.config
  opts = {
    scope = {
      enabled = false,
    },
  },
}
