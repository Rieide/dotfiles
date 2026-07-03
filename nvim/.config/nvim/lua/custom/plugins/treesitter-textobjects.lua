local select_textobject = function(query, group)
  return function() require('nvim-treesitter-textobjects.select').select_textobject(query, group or 'textobjects') end
end

local goto_next_start = function(query, group)
  return function() require('nvim-treesitter-textobjects.move').goto_next_start(query, group or 'textobjects') end
end

local goto_previous_start = function(query, group)
  return function() require('nvim-treesitter-textobjects.move').goto_previous_start(query, group or 'textobjects') end
end

---@module 'lazy'
---@type LazySpec
return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  branch = 'main',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  keys = {
    { 'af', select_textobject '@function.outer', mode = { 'x', 'o' }, desc = 'Around function' },
    { 'if', select_textobject '@function.inner', mode = { 'x', 'o' }, desc = 'Inside function' },
    { 'ac', select_textobject '@class.outer', mode = { 'x', 'o' }, desc = 'Around class' },
    { 'ic', select_textobject '@class.inner', mode = { 'x', 'o' }, desc = 'Inside class' },
    { ']f', goto_next_start '@function.outer', mode = { 'n', 'x', 'o' }, desc = 'Next function start' },
    { '[f', goto_previous_start '@function.outer', mode = { 'n', 'x', 'o' }, desc = 'Previous function start' },
    { ']C', goto_next_start '@class.outer', mode = { 'n', 'x', 'o' }, desc = 'Next class start' },
    { '[C', goto_previous_start '@class.outer', mode = { 'n', 'x', 'o' }, desc = 'Previous class start' },
  },
  config = function()
    require('nvim-treesitter-textobjects').setup {
      select = {
        lookahead = true,
        selection_modes = {
          ['@parameter.outer'] = 'v',
          ['@function.outer'] = 'V',
          ['@class.outer'] = 'V',
        },
        include_surrounding_whitespace = true,
      },
      move = {
        set_jumps = true,
      },
    }
  end,
}
