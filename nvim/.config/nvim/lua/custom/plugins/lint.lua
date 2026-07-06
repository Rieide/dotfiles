---@module 'lazy'
---@type LazySpec
return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require 'lint'

    lint.linters_by_ft = {
      bash = { 'shellcheck' },
      python = { 'ruff' },
      sh = { 'shellcheck' },
    }

    local lint_group = vim.api.nvim_create_augroup('custom-lint', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
      group = lint_group,
      callback = function() lint.try_lint() end,
    })

    vim.keymap.set('n', '<leader>cl', function() lint.try_lint() end, { desc = '[C]ode [L]int buffer' })
  end,
}
