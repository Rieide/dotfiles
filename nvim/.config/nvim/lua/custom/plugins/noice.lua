return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
  },
  keys = {
    { '<leader>nl', function() require('noice').cmd 'last' end, desc = 'Last message' },
    { '<leader>nh', function() require('noice').cmd 'history' end, desc = 'Message history' },
    { '<leader>na', function() require('noice').cmd 'all' end, desc = 'All messages' },
    { '<leader>nd', function() require('noice').cmd 'dismiss' end, desc = 'Dismiss messages' },
  },
  opts = {
    cmdline = {
      enabled = true,
      view = 'cmdline',
    },
    popupmenu = {
      enabled = false,
    },
    messages = {
      enabled = true,
      view = 'mini',
      view_error = 'mini',
      view_warn = 'mini',
      view_history = 'messages',
    },
    lsp = {
      progress = {
        enabled = false,
      },
      hover = {
        enabled = false,
      },
      signature = {
        enabled = false,
      },
    },
    presets = {
      bottom_search = false,
      command_palette = false,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },
  },
}
