---@module 'lazy'
---@type LazySpec
return {
  'nvim-telescope/telescope.nvim',
  enabled = true,
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function() return vim.fn.executable 'make' == 1 end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local themes = require 'telescope.themes'
    local telescope = require 'telescope'

    telescope.setup {
      defaults = {
        sorting_strategy = 'descending',
        scroll_strategy = 'limit',
        layout_strategy = 'flex',
        layout_config = {
          horizontal = {
            anchor = 'S',
            width = 0.92,
            height = 0.48,
            prompt_position = 'bottom',
            preview_width = 0.55,
            preview_cutoff = 120,
          },
          vertical = {
            anchor = 'S',
            width = 0.92,
            height = 0.48,
            prompt_position = 'bottom',
            preview_cutoff = 999,
          },
          flip_columns = 120,
        },
        winblend = 30,
        initial_mode = 'normal',
        border = true,
        path_display = { 'smart' },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        live_grep = {
          additional_args = {
            '--hidden',
            '--glob',
            '!.git/',
            '--glob',
            '!build/',
            '--glob',
            '!node_modules/',
          },
        },
        grep_string = {
          additional_args = {
            '--hidden',
            '--glob',
            '!.git/',
            '--glob',
            '!build/',
            '--glob',
            '!node_modules/',
          },
        },
        oldfiles = {
          only_cwd = true,
        },
        current_buffer_fuzzy_find = {
          skip_empty_lines = true,
        },
        lsp_references = {
          include_declaration = false,
          include_current_line = true,
        },
      },
      extensions = {
        ['ui-select'] = { themes.get_dropdown() },
      },
    }

    pcall(telescope.load_extension, 'fzf')
    pcall(telescope.load_extension, 'ui-select')

    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = '[F]ind [F]iles' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = '[F]ind by [G]rep' })
    vim.keymap.set({ 'n', 'v' }, '<leader>fw', builtin.grep_string, { desc = '[F]ind current [W]ord' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = '[F]ind [B]uffers' })
    vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = '[F]ind [R]ecent files' })
    vim.keymap.set('n', '<leader>fs', builtin.lsp_document_symbols, { desc = '[F]ind document [S]ymbols' })
    vim.keymap.set('n', '<leader>fS', builtin.lsp_dynamic_workspace_symbols, { desc = '[F]ind workspace [S]ymbols' })
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
      callback = function(event)
        local buf = event.buf

        vim.keymap.set('n', '<leader>fd', builtin.lsp_definitions, { buffer = buf, desc = '[F]ind [D]efinitions' })
        vim.keymap.set('n', '<leader>fD', vim.lsp.buf.declaration, { buffer = buf, desc = '[F]ind [D]eclarations' })
        vim.keymap.set('n', '<leader>fi', builtin.lsp_implementations, { buffer = buf, desc = '[F]ind [I]mplementations' })
        vim.keymap.set('n', '<leader>ft', builtin.lsp_type_definitions, { buffer = buf, desc = '[F]ind [T]ype definitions' })
        vim.keymap.set('n', '<leader>fR', builtin.lsp_references, { buffer = buf, desc = '[F]ind [R]eferences' })

        vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
        vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
        vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
        vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
        vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
        vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
      end,
    })

    vim.keymap.set(
      'n',
      '<leader>/',
      function()
        builtin.current_buffer_fuzzy_find(themes.get_dropdown {
          winblend = 30,
          previewer = false,
        })
      end,
      { desc = '[/] Fuzzily search in current buffer' }
    )

    vim.keymap.set(
      'n',
      '<leader>s/',
      function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end,
      { desc = '[S]earch [/] in Open Files' }
    )

    vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
  end,
}
