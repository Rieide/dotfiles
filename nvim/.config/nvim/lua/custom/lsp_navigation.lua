local api = vim.api

local M = {}

local function open_location_list(options, source)
  if #options.items ~= 1 then
    vim.fn.setqflist({}, ' ', options)
    vim.cmd 'botright copen'
    return
  end

  if not api.nvim_win_is_valid(source.winid) then
    vim.notify('The source window closed before the LSP jump completed', vim.log.levels.WARN)
    return
  end

  local item = options.items[1]
  local target_bufnr = item.bufnr
  if not target_bufnr or target_bufnr <= 0 then target_bufnr = vim.fn.bufadd(item.filename) end
  vim.bo[target_bufnr].buflisted = true

  local ok, err = pcall(api.nvim_win_call, source.winid, function()
    -- Match the built-in LSP handler's jumplist and tag-stack behavior, but
    -- use :buffer so SwapExists can resolve a conflict. nvim_win_set_buf()
    -- raises E325 before the built-in handler can set the destination cursor.
    vim.cmd "normal! m'"
    vim.fn.settagstack(source.winid, {
      items = { { tagname = source.tagname, from = source.from } },
    }, 't')
    vim.cmd(('keepjumps buffer %d'):format(target_bufnr))

    local line_count = api.nvim_buf_line_count(target_bufnr)
    local row = math.max(1, math.min(item.lnum, line_count))
    local line = api.nvim_buf_get_lines(target_bufnr, row - 1, row, false)[1] or ''
    local column = math.max(0, math.min((item.col or 1) - 1, #line))
    api.nvim_win_set_cursor(source.winid, { row, column })
    vim.cmd 'normal! zv'
  end)

  if not ok then vim.notify('Unable to open LSP location: ' .. tostring(err), vim.log.levels.ERROR) end
end

function M.jump(request)
  return function()
    local source = {
      bufnr = api.nvim_get_current_buf(),
      winid = api.nvim_get_current_win(),
      from = vim.fn.getpos '.',
      tagname = vim.fn.expand '<cword>',
    }
    source.from[1] = source.bufnr

    request {
      on_list = function(options) open_location_list(options, source) end,
    }
  end
end

return M
