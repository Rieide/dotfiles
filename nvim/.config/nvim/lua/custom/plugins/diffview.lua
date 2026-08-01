---@module 'lazy'
---@type LazySpec
return {
  'sindrets/diffview.nvim',
  cmd = {
    'DiffviewOpen',
    'DiffviewClose',
    'DiffviewToggleFiles',
    'DiffviewFocusFiles',
    'DiffviewRefresh',
    'DiffviewFileHistory',
  },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Git [d]iff view' },
    { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git file [h]istory' },
    { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'Git repository [H]istory' },
    { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Git diffview close' },
  },
  opts = {
    use_icons = vim.g.have_nerd_font,
  },
}
