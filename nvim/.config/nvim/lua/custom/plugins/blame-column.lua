local day_seconds = 24 * 60 * 60

local heat_levels = {
  { max_days = 6, group = 'BlameHeatFresh', color = '#E46876' },
  { max_days = 29, group = 'BlameHeatRecent', color = '#FF9E64' },
  { max_days = 89, group = 'BlameHeatMonth', color = '#E6C384' },
  { max_days = 179, group = 'BlameHeatQuarter', color = '#98BB6C' },
  { max_days = 364, group = 'BlameHeatYear', color = '#7E9CD8' },
  { max_days = math.huge, group = 'BlameHeatOld', color = '#727169' },
}

local function age_in_days(line_info)
  if line_info.is_modified or not line_info.author_time then return 0 end
  return math.max(0, math.floor((os.time() - line_info.author_time) / day_seconds))
end

local function format_age(days)
  if days < 30 then return string.format('%2d d.', days) end
  if days < 365 then return string.format('%2d m.', math.floor(days / 30)) end
  return string.format('%2d y.', math.floor(days / 365))
end

local function heat_group(days)
  for _, level in ipairs(heat_levels) do
    if days <= level.max_days then return level.group end
  end
end

local function truncate_author(author)
  return vim.fn.strcharpart(vim.trim(author or ''), 0, 5)
end

local function structurize(_, line_info)
  local days = age_in_days(line_info)
  local author = line_info.is_modified and 'local' or truncate_author(line_info.author)

  return {
    fields = {
      { text = '▌', hl = heat_group(days) },
      { text = format_age(days), hl = 'BlameColumnTime' },
      { text = author, hl = 'BlameColumnAuthor' },
    },
    format = '%s %s %s',
  }
end

local function set_heat_highlights()
  for _, level in ipairs(heat_levels) do
    vim.api.nvim_set_hl(0, level.group, { fg = level.color })
  end
end

local function blame_target_status(bufnr, opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, 'Blame is only available for tracked files'
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' or vim.bo[bufnr].buftype ~= '' then
    return false, 'Blame is only available for tracked files'
  end

  local filetype = vim.bo[bufnr].filetype
  if vim.tbl_contains(opts.ignore_filetypes, filetype) then
    return false, 'Blame is not available for this buffer type'
  end

  local filename = vim.fn.fnamemodify(path, ':t')
  if vim.tbl_contains(opts.ignore_filenames, filename) then
    return false, 'Blame is not available for this buffer'
  end

  local directory = vim.fn.fnamemodify(path, ':h')
  vim.fn.system { 'git', '-C', directory, 'rev-parse', '--verify', 'HEAD' }
  if vim.v.shell_error ~= 0 then
    return false, 'Blame requires a Git repository with at least one commit'
  end

  vim.fn.system { 'git', '-C', directory, 'ls-files', '--error-unmatch', '--', path }
  if vim.v.shell_error ~= 0 then
    return false, 'Blame is only available for tracked files'
  end

  return true
end

local function toggle_blame_column()
  require('custom.blame_column_controller').toggle()
end

---@module 'lazy'
---@type LazySpec
return {
  'Yu-Leo/blame-column.nvim',
  cmd = 'BlameColumnToggle',
  keys = {
    { '<leader>hB', toggle_blame_column, desc = 'git full-file [B]lame panel' },
  },
  opts = {
    side = 'right',
    dynamic_width = true,
    auto_width = true,
    max_width = 18,
    ignore_filetypes = { 'neo-tree', 'toggleterm', 'NvimTree' },
    ignore_filenames = { '' },
    hl_by_fields = true,
    structurizer_fn = structurize,
    colorizer_fn = function() return {} end,
    full_commit_info = {
      enabled_from_blame = false,
    },
  },
  config = function(_, opts)
    require('blame-column').setup(opts)

    -- The plugin checks the process cwd by default. Check the source buffer
    -- instead so files opened from another repository behave correctly.
    require('blame-column.utils').is_blame_availible = function(current_opts)
      return blame_target_status(vim.api.nvim_get_current_buf(), current_opts)
    end
    require('custom.blame_column_controller').setup { target_status = blame_target_status }
    set_heat_highlights()

    local group = vim.api.nvim_create_augroup('custom-blame-column', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = group,
      callback = set_heat_highlights,
    })
  end,
}
