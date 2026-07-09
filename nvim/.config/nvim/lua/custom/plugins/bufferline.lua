local keys = {
  { '<leader>bp', '<Cmd>BufferLinePick<CR>', desc = '[B]uffer [P]ick' },
  { '<leader><Left>', '<Cmd>BufferLineCyclePrev<CR>', desc = 'Previous buffer' },
  { '<leader><Right>', '<Cmd>BufferLineCycleNext<CR>', desc = 'Next buffer' },
  { '<leader>bn', '<Cmd>BufferLineCycleNext<CR>', desc = '[B]uffer [N]ext' },
  { '<leader>bN', '<Cmd>BufferLineCyclePrev<CR>', desc = '[B]uffer Previous' },
}

local function go_to_buffer_ordinal_command(i) return ('<Cmd>lua require("bufferline").go_to(%d, true)<CR>'):format(i) end

for i = 1, 99 do
  local suffix = tostring(i)
  if i < 10 then suffix = suffix .. '<CR>' end

  table.insert(keys, {
    '<leader>' .. suffix,
    go_to_buffer_ordinal_command(i),
    desc = 'Go to buffer ordinal ' .. i,
  })
  table.insert(keys, {
    '<leader>b' .. suffix,
    go_to_buffer_ordinal_command(i),
    desc = '[B]uffer go to ordinal ' .. i,
  })
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
