local keys = {
  { '<leader>bp', '<Cmd>BufferLinePick<CR>', desc = '[B]uffer [P]ick' },
  { '<leader><Left>', '<Cmd>BufferLineCyclePrev<CR>', desc = 'Previous buffer' },
  { '<leader><Right>', '<Cmd>BufferLineCycleNext<CR>', desc = 'Next buffer' },
  { '<leader>bn', '<Cmd>BufferLineCycleNext<CR>', desc = '[B]uffer [N]ext' },
  { '<leader>bN', '<Cmd>BufferLineCyclePrev<CR>', desc = '[B]uffer Previous' },
}

for i = 1, 9 do
  table.insert(keys, { '<leader>' .. i, '<Cmd>BufferLineGoToBuffer ' .. i .. '<CR>', desc = 'Go to visible buffer ' .. i })
  table.insert(keys, { '<leader>b' .. i, '<Cmd>BufferLineGoToBuffer ' .. i .. '<CR>', desc = '[B]uffer go to visible ' .. i })
end

---@module 'lazy'
---@type LazySpec
return {
  'akinsho/bufferline.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  keys = keys,
  ---@module 'bufferline'
  ---@type bufferline.UserConfig
  opts = {
    options = {
      mode = 'buffers',
      numbers = function(opts) return tostring(opts.ordinal) end,
      diagnostics = 'nvim_lsp',
      always_show_bufferline = false,
      show_buffer_close_icons = false,
      show_close_icon = false,
      separator_style = 'thin',
      offsets = {
        {
          filetype = 'neo-tree',
          text = 'Files',
          text_align = 'left',
          separator = true,
        },
      },
    },
  },
}
