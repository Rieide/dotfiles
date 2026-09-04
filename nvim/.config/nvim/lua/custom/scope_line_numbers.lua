local M = {}

local ns = vim.api.nvim_create_namespace 'scope_line_numbers'
local cursor_ns = vim.api.nvim_create_namespace 'scope_line_numbers_cursor'
local listener
local cursor_marks = {}

local function brighten(color, amount)
  local function channel(shift)
    local value = bit.rshift(color, shift) % 0x100
    return math.floor(value + (0xff - value) * amount + 0.5)
  end

  return bit.lshift(channel(16), 16) + bit.lshift(channel(8), 8) + channel(0)
end

local function update_highlight()
  local active = vim.api.nvim_get_hl(0, { name = 'CursorLineNr', link = false })
  local normal = vim.api.nvim_get_hl(0, { name = 'LineNr', link = false })
  local color = active.fg or normal.fg or 0x74c0fc

  vim.api.nvim_set_hl(0, 'ScopeLineNr', { fg = brighten(color, 0.5) })
end

local function clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
end

local function preserve_cursor_line(win, buf)
  if win ~= vim.api.nvim_get_current_win() or not vim.api.nvim_win_is_valid(win) then return end
  if vim.api.nvim_win_get_buf(win) ~= buf then return end

  cursor_marks[buf] = vim.api.nvim_buf_set_extmark(buf, cursor_ns, vim.api.nvim_win_get_cursor(win)[1] - 1, 0, {
    id = cursor_marks[buf],
    number_hl_group = 'CursorLineNr',
    priority = 501,
    invalidate = true,
  })
end

local function clear_cursor_line(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, cursor_ns, 0, -1)
  cursor_marks[buf] = nil
end

local function render(win, buf, scope, prev)
  if prev and prev.buf ~= buf then clear(prev.buf) end
  clear(buf)
  if not scope or not vim.api.nvim_buf_is_valid(buf) then return end

  for line = scope.from, scope.to do
    vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, {
      number_hl_group = 'ScopeLineNr',
      priority = 500,
    })
  end

  preserve_cursor_line(win, buf)
end

function M.setup()
  if listener then return end

  update_highlight()
  local group = vim.api.nvim_create_augroup('scope_line_numbers', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = update_highlight,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufEnter', 'WinEnter' }, {
    group = group,
    callback = function(event) preserve_cursor_line(vim.api.nvim_get_current_win(), event.buf) end,
  })
  vim.api.nvim_create_autocmd('WinLeave', {
    group = group,
    callback = function(event) clear_cursor_line(event.buf) end,
  })

  listener = Snacks.scope.attach(function(win, buf, scope, prev) render(win, buf, scope, prev) end)
end

return M
