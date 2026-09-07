---@module 'lazy'
---@type LazySpec
local function non_utf8_encoding()
  local encoding = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
  return encoding ~= 'utf-8' and encoding or ''
end

local function navic_is_available()
  local ok, navic = pcall(require, 'nvim-navic')
  return ok and navic.is_available()
end

local function current_function()
  local navic = require 'nvim-navic'
  local function_kinds = {
    [vim.lsp.protocol.SymbolKind.Constructor] = true,
    [vim.lsp.protocol.SymbolKind.Function] = true,
    [vim.lsp.protocol.SymbolKind.Method] = true,
  }

  local context = navic.get_data() or {}
  for i = #context, 1, -1 do
    local symbol = context[i]
    if function_kinds[symbol.kind] then return symbol.name:gsub('%%', '%%%%'):gsub('[\r\n]', ' ') end
  end

  return ''
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
    {
      'SmiteshP/nvim-navic',
      -- Register its LspAttach handler before startup-time language servers attach.
      lazy = false,
      opts = {
        icons = { enabled = false },
        lsp = { auto_attach = true },
      },
    },
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
        winbar = { 'neo-tree' },
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
      lualine_c = {
        filename,
        {
          current_function,
          cond = navic_is_available,
        },
      },
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
