---@module 'lazy'
---@type LazySpec
return {
  'folke/trouble.nvim',
  cmd = 'Trouble',
  keys = {
    { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics' },
    { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer diagnostics' },
    { '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>', desc = 'Symbols' },
    { '<leader>xl', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', desc = 'LSP definitions/references' },
    { '<leader>xL', '<cmd>Trouble loclist toggle<cr>', desc = 'Location list' },
    { '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix list' },
  },
  ---@module 'trouble'
  ---@type trouble.Config
  opts = {
    focus = false,
    win = {
      position = 'bottom',
      size = 12,
    },
    modes = {
      diagnostics = {
        win = {
          position = 'bottom',
          size = 12,
        },
      },
      lsp = {
        focus = false,
        win = {
          position = 'bottom',
          size = 12,
        },
      },
      loclist = {
        win = {
          position = 'bottom',
          size = 12,
        },
      },
      qflist = {
        win = {
          position = 'bottom',
          size = 12,
        },
      },
      symbols = {
        focus = false,
        win = {
          position = 'right',
          size = 40,
        },
      },
    },
  },
}
