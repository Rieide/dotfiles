---@module 'lazy'
---@type LazySpec
local function non_utf8_encoding()
  local encoding = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
  return encoding ~= 'utf-8' and encoding or ''
end

local filename = {
  'filename',
  path = 1,
  symbols = {
    modified = ' [+]',
    readonly = ' [-]',
  },
}

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
      lualine_c = {},
      lualine_x = { non_utf8_encoding },
      lualine_y = { 'progress' },
      lualine_z = { 'location' },
    },
    winbar = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { filename },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    inactive_winbar = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { filename },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    extensions = { 'lazy', 'mason', 'neo-tree', 'quickfix' },
  },
}
