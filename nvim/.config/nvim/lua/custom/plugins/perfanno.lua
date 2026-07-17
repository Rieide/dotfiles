return {
  't-troebst/perfanno.nvim',

  cmd = {
    'PerfLoadFlat',
    'PerfLoadCallGraph',
    'PerfLoadFlameGraph',
    'PerfPickEvent',
    'PerfCycleFormat',
    'PerfAnnotate',
    'PerfAnnotateFunction',
    'PerfToggleAnnotations',
    'PerfHottestLines',
    'PerfHottestSymbols',
    'PerfHottestCallersFunction',
  },

  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-treesitter/nvim-treesitter',
  },

  keys = {
    { '<leader>pl', '<cmd>PerfLoadCallGraph<CR>', desc = '[P]rofile [L]oad call graph' },
    { '<leader>pa', '<cmd>PerfAnnotate<CR>', desc = '[P]rofile [A]nnotate' },
    { '<leader>pt', '<cmd>PerfToggleAnnotations<CR>', desc = '[P]rofile [T]oggle annotations' },
    { '<leader>ph', '<cmd>PerfHottestLines<CR>', desc = '[P]rofile [H]ottest lines' },
    { '<leader>ps', '<cmd>PerfHottestSymbols<CR>', desc = '[P]rofile hottest [S]ymbols' },
    { '<leader>pe', '<cmd>PerfPickEvent<CR>', desc = '[P]rofile [E]vent' },
  },

  config = function()
    local perfanno = require 'perfanno'
    local util = require 'perfanno.util'

    perfanno.setup {
      line_highlights = util.make_bg_highlights(nil, '#CC3300', 10),
      vt_highlight = util.make_fg_highlight '#CC3300',
      formats = {
        { percent = true, format = 'incl %.2f%%', minimum = 0.5 },
        { percent = false, format = '%d', minimum = 1 },
      },
      annotate_after_load = false,
      annotate_on_open = false,
      thread_support = true,
      telescope = {
        enabled = true,
        annotate = true,
      },
    }
  end,
}
