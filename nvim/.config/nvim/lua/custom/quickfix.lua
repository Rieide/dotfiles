local M = {}

local quickfix_height = 12

local function get_quickfix_info()
  return vim.fn.getqflist { size = 0, winid = 0 }
end

local function notify(message)
  vim.notify(message, vim.log.levels.INFO, { title = 'Quickfix' })
end

function M.toggle()
  local info = get_quickfix_info()
  if info.winid > 0 and vim.api.nvim_win_is_valid(info.winid) then
    vim.cmd.cclose()
    return
  end

  if info.size == 0 then
    notify 'Quickfix list is empty'
    return
  end

  vim.cmd(('botright copen %d'):format(quickfix_height))
end

local function jump(command, unavailable_message)
  return function()
    if get_quickfix_info().size == 0 then
      notify 'Quickfix list is empty'
      return
    end

    if not pcall(vim.cmd, command) then
      notify(unavailable_message)
      return
    end

    if vim.bo.buftype ~= 'quickfix' then vim.cmd 'normal! zz' end
  end
end

local function close_list_window()
  local window_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  vim.cmd(window_info and window_info.loclist == 1 and 'lclose' or 'cclose')
end

function M.setup()
  vim.keymap.set('n', '<leader>xQ', M.toggle, { desc = 'Toggle Quickfix list' })
  vim.keymap.set('n', '[q', jump('cprevious', 'Already at the first Quickfix item'), { desc = 'Previous Quickfix item' })
  vim.keymap.set('n', ']q', jump('cnext', 'Already at the last Quickfix item'), { desc = 'Next Quickfix item' })
  vim.keymap.set('n', '[Q', jump('cfirst', 'No valid Quickfix item'), { desc = 'First Quickfix item' })
  vim.keymap.set('n', ']Q', jump('clast', 'No valid Quickfix item'), { desc = 'Last Quickfix item' })

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('quickfix-keymaps', { clear = true }),
    pattern = 'qf',
    callback = function(event)
      vim.keymap.set('n', 'q', close_list_window, {
        buffer = event.buf,
        desc = 'Close Quickfix/location list',
      })
    end,
  })
end

return M
