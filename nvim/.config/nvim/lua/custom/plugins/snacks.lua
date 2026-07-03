return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<leader>gg',
      function()
        if vim.fn.executable 'lazygit' ~= 1 then
          vim.notify('lazygit is not installed', vim.log.levels.WARN)
          return
        end

        Snacks.lazygit()
      end,
      desc = 'LazyGit',
    },
    { '<leader>tt', function() Snacks.terminal() end, desc = 'Terminal' },
  },
  opts = {
    bigfile = { enabled = true },
    quickfile = { enabled = true },

    -- Keep Telescope/Noice/default vim.ui.input as the primary picker/message/input UI for now.
    dashboard = { enabled = false },
    explorer = { enabled = false },
    input = { enabled = false },
    notifier = { enabled = false },
    picker = { enabled = false },

    terminal = { enabled = true },
  },
}
