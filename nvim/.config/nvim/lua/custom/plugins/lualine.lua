---@module 'lazy'
---@type LazySpec
return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  ---@module 'lualine'
  ---@type lualine.Config
  opts = {
    options = {
      icons_enabled = vim.g.have_nerd_font,
      theme = 'auto',
      component_separators = '|',
      section_separators = '',
      globalstatus = true,
      disabled_filetypes = {
        statusline = { 'dashboard', 'alpha', 'starter' },
      },
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = {
        {
          'filename',
          path = 1,
        },
      },
      lualine_x = { 'encoding', 'fileformat', 'filetype' },
      lualine_y = { 'progress' },
      lualine_z = { 'location' },
    },
    extensions = { 'lazy', 'mason', 'neo-tree', 'quickfix' },
  },
}
