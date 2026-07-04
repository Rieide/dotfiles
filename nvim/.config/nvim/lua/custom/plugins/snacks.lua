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
    indent = {
      enabled = true,
      indent = {
        enabled = true,
        char = '│',
      },
      animate = {
        enabled = true,
        style = 'out',
        easing = 'linear',
        duration = {
          step = 15,
          total = 250,
        },
      },
      scope = {
        enabled = true,
        char = '│',
        underline = false,
      },
      chunk = {
        enabled = true,
        char = {
          corner_top = '╭',
          corner_bottom = '╰',
          horizontal = '─',
          vertical = '│',
          arrow = '>',
        },
      },
    },
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
