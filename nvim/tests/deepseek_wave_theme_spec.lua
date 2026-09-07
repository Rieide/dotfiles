local source = debug.getinfo(1, 'S').source:sub(2)
local package_root = vim.fs.dirname(vim.fs.dirname(source))
local config_root = package_root .. '/.config/nvim'
local kanagawa_root = vim.fn.stdpath 'data' .. '/lazy/kanagawa.nvim'
local lualine_root = vim.fn.stdpath 'data' .. '/lazy/lualine.nvim'

assert(vim.fn.isdirectory(kanagawa_root) == 1, 'kanagawa.nvim is not installed at ' .. kanagawa_root)
assert(vim.fn.isdirectory(lualine_root) == 1, 'lualine.nvim is not installed at ' .. lualine_root)

vim.opt.runtimepath:prepend(config_root)
vim.opt.runtimepath:append(kanagawa_root)
vim.opt.runtimepath:append(lualine_root)
vim.cmd.colorscheme 'deepseek-wave'

assert(vim.g.colors_name == 'deepseek-wave', 'deepseek-wave did not become the active colorscheme')

local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
assert(normal.bg == tonumber('000000', 16), 'Normal must use a true-black background')
assert(normal.fg == tonumber('F9FAFB', 16), 'Normal foreground does not match the palette')

local cursor_line = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false })
assert(cursor_line.bg == tonumber('151517', 16), 'CursorLine must be visibly raised above the black editor canvas')

local selection = vim.api.nvim_get_hl(0, { name = 'Visual', link = false })
assert(selection.bg == tonumber('283142', 16), 'Visual does not use the DeepSeek selection surface')

local separator = vim.api.nvim_get_hl(0, { name = 'WinSeparator', link = false })
assert(separator.fg == tonumber('353638', 16), 'WinSeparator does not use the visible gray divider')

local float = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
assert(float.bg == tonumber('1B1B1C', 16), 'floating windows do not use the raised gray surface')

local completion = vim.api.nvim_get_hl(0, { name = 'Pmenu', link = false })
assert(completion.bg == tonumber('1B1B1C', 16), 'completion menus do not use the raised gray surface')

local sidebar = vim.api.nvim_get_hl(0, { name = 'NeoTreeNormal', link = false })
assert(sidebar.bg == tonumber('0F0F0F', 16), 'the sidebar does not separate from the editor canvas')

local lualine = require 'lualine.themes.auto'
local mode_colors = {
  normal = '#5686FE',
  insert = '#69DB7C',
  visual = '#B197FC',
  replace = '#F25A5A',
  command = '#F7AD31',
  terminal = '#4DABF7',
}
for mode, color in pairs(mode_colors) do
  assert(lualine[mode].a.bg == color, ('lualine %s mode does not use its semantic accent'):format(mode))
  assert(lualine[mode].a.fg == '#000000', ('lualine %s mode must remain readable'):format(mode))
  assert(lualine[mode].a.gui == nil, ('lualine %s mode must not force a font style'):format(mode))
end

local forbidden = { 'bold', 'italic', 'altfont', 'font' }
for name, spec in pairs(vim.api.nvim_get_hl(0, { link = true })) do
  for _, attribute in ipairs(forbidden) do
    assert(spec[attribute] == nil, ('%s still defines %s'):format(name, attribute))
    if type(spec.cterm) == 'table' then
      assert(spec.cterm[attribute] == nil, ('%s still defines cterm.%s'):format(name, attribute))
    end
  end
end

for index = 0, 17 do
  assert(vim.g['terminal_color_' .. index] == nil, ('terminal_color_%d must remain terminal-controlled'):format(index))
end

print 'deepseek-wave theme checks passed'
