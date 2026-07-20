local api = vim.api

local config = require 'blame-column.config'
local git = require 'blame-column.git'
local utils = require 'blame-column.utils'

local M = {
  state = {
    status = 'closed',
    session = nil,
  },
}

local controller_opts = {}
local next_session_id = 0
local attached_source_sessions = {}
local attached_source_buffers = {}

local function function_upvalue(callback, wanted_name)
  for index = 1, math.huge do
    local name, value = debug.getupvalue(callback, index)
    if not name then return nil end
    if name == wanted_name then return value end
  end
end

local parse_blame_output = function_upvalue(git.async_get_git_blame, 'parse_blame_output')

local binding_window_options = {
  'scrollbind',
  'cursorbind',
}

local source_window_options = {
  'wrap',
  'foldenable',
  'scrollbind',
  'cursorbind',
}

local panel_window_options = {
  'wrap',
  'foldenable',
  'number',
  'relativenumber',
  'cursorline',
  'signcolumn',
  'list',
  'winfixwidth',
  'scrollbind',
  'cursorbind',
  'scrolloff',
  'winbar',
}

local function win_valid(winid)
  return winid ~= nil and api.nvim_win_is_valid(winid)
end

local function buf_valid(bufnr)
  return bufnr ~= nil and api.nvim_buf_is_valid(bufnr)
end

local function normalize_path(path)
  if path == '' then return '' end
  local absolute = vim.fn.fnamemodify(path, ':p')
  return vim.fs and vim.fs.normalize(absolute) or absolute
end

local function copy_target(target)
  return {
    bufnr = target.bufnr,
    path = target.path,
    changedtick = target.changedtick,
  }
end

local function same_target(left, right)
  return left ~= nil
    and right ~= nil
    and left.bufnr == right.bufnr
    and left.path == right.path
    and left.changedtick == right.changedtick
end

local function same_file(left, right)
  return left ~= nil and right ~= nil and left.bufnr == right.bufnr and left.path == right.path
end

local function get_window_option(winid, name)
  return api.nvim_get_option_value(name, { win = winid })
end

local function set_window_option(winid, name, value)
  api.nvim_set_option_value(name, value, { win = winid })
end

local function get_restorable_window_option(winid, name)
  if name == 'scrolloff' then return api.nvim_get_option_value(name, { win = winid, scope = 'local' }) end
  return get_window_option(winid, name)
end

local function capture_window_options(winid, names)
  local values = {}
  for _, name in ipairs(names or panel_window_options) do
    values[name] = get_restorable_window_option(winid, name)
  end
  return values
end

local function restore_window_options(winid, values)
  if not win_valid(winid) or not values then return end
  for name, value in pairs(values) do
    pcall(set_window_option, winid, name, value)
  end
end

local function restore_controller_changes(winid, original, managed, names)
  if not win_valid(winid) or not original or not managed then return end
  for _, name in ipairs(names or panel_window_options) do
    if original[name] ~= managed[name] then
      local ok, current = pcall(get_restorable_window_option, winid, name)
      if ok and current == managed[name] then pcall(set_window_option, winid, name, original[name]) end
    end
  end
end

local function marker_entry(marker)
  return marker .. ':' .. marker
end

local function add_window_marker(winid, marker)
  local current = get_window_option(winid, 'winhighlight')
  local entry = marker_entry(marker)
  set_window_option(winid, 'winhighlight', current == '' and entry or (current .. ',' .. entry))
end

local function remove_window_marker(winid, marker)
  if not win_valid(winid) or not marker then return false end
  local entry = marker_entry(marker)
  local current = get_window_option(winid, 'winhighlight')
  local retained = {}
  local found = false
  for item in current:gmatch '[^,]+' do
    if item == entry then
      found = true
    else
      retained[#retained + 1] = item
    end
  end
  if found then set_window_option(winid, 'winhighlight', table.concat(retained, ',')) end
  return found
end

local function take_inherited_marker(session, winid)
  if remove_window_marker(winid, session.source_marker) then return 'source' end
  if remove_window_marker(winid, session.panel_marker) then return 'panel' end
end

local function collect_inherited_markers(session)
  for _, winid in ipairs(api.nvim_list_wins()) do
    if winid ~= session.source_winid and winid ~= session.panel_winid then
      local parent_kind = take_inherited_marker(session, winid)
      if parent_kind then session.inherited_windows[winid] = parent_kind end
    end
  end
end

local function current_target(session)
  if not win_valid(session.source_winid) then return nil end

  local bufnr = api.nvim_win_get_buf(session.source_winid)
  if not buf_valid(bufnr) then return nil end

  return {
    bufnr = bufnr,
    path = normalize_path(api.nvim_buf_get_name(bufnr)),
    changedtick = api.nvim_buf_get_changedtick(bufnr),
  }
end

local function refresh_public_state(session, status)
  if session and M.state.session ~= session then return end

  M.state.status = status or (session and session.status) or 'closed'
  M.state.session = session
  M.state.source_winid = session and session.source_winid or nil
  M.state.source_bufnr = session and session.source_bufnr or nil
  M.state.source_path = session and session.source_path or nil
  M.state.panel_winid = session and session.panel_winid or nil
  M.state.panel_bufnr = session and session.panel_bufnr or nil
  M.state.file_info = session and session.file_info or nil
  M.state.request = session and session.request or nil
end

local function session_live(session)
  return M.state.session == session and session.status ~= 'closing'
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.ERROR, { title = 'blame-column.nvim' })
end

local function target_status(bufnr)
  if not controller_opts.target_status then return true end

  local ok, available, message = pcall(controller_opts.target_status, bufnr, config.opts)
  if not ok then return false, 'Unable to check blame target: ' .. tostring(available) end
  return available, message
end

local function buffer_is_displayed(bufnr)
  if not buf_valid(bufnr) then return false end
  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(winid) == bufnr then return true end
  end
  return false
end

local function windows_showing_buffer(bufnr)
  local result = {}
  if not buf_valid(bufnr) then return result end

  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(winid) == bufnr then result[#result + 1] = winid end
  end
  return result
end

local function window_id_set()
  local result = {}
  for _, winid in ipairs(api.nvim_list_wins()) do
    result[winid] = true
  end
  return result
end

local function detail_buffer_owned_by(session, bufnr)
  if session.detail_buffers[bufnr] then return true end

  local ok, commit_info = pcall(require, 'blame-column.commit_info_window')
  return ok and commit_info.state.commit_info_bufnr == bufnr
end

local function normalize_inherited_windows(session)
  if not session.bindings_applied or not session.source_restore or not session.inherited_windows then return end

  for winid, parent_kind in pairs(session.inherited_windows) do
    if win_valid(winid) then
      local bufnr = api.nvim_win_get_buf(winid)
      if not detail_buffer_owned_by(session, bufnr) then
        if parent_kind == 'panel' then
          if api.nvim_win_get_config(winid).relative == '' then
            restore_controller_changes(winid, session.panel_restore, session.panel_managed)
          else
            restore_controller_changes(winid, session.panel_restore, session.panel_managed, binding_window_options)
          end
        end
        if parent_kind == 'source' then
          local names = source_window_options
          if api.nvim_win_get_config(winid).relative ~= '' then names = binding_window_options end
          restore_controller_changes(winid, session.source_restore, session.source_managed, names)
        end
      end
    end
    session.inherited_windows[winid] = nil
  end
end

local function schedule_inherited_window_normalization(session)
  if session.inherited_normalization_scheduled then return end
  session.inherited_normalization_scheduled = true

  vim.schedule(function()
    session.inherited_normalization_scheduled = false
    if session_live(session) then normalize_inherited_windows(session) end
  end)
end

local function wipe_buffer(bufnr)
  if not buf_valid(bufnr) or buffer_is_displayed(bufnr) then return end
  pcall(api.nvim_buf_delete, bufnr, { force = true })
end

local function close_detail(session)
  local commit_info = require 'blame-column.commit_info_window'
  local buffers = {}

  if commit_info.state.commit_info_bufnr then
    buffers[commit_info.state.commit_info_bufnr] = true
  end
  for bufnr in pairs(session.detail_buffers or {}) do
    buffers[bufnr] = true
  end

  pcall(commit_info.close, false)
  for bufnr in pairs(buffers) do
    if buf_valid(bufnr) then pcall(api.nvim_buf_delete, bufnr, { force = true }) end
  end
  session.detail_buffers = {}
end

local function detail_is_active(session)
  local commit_info = require 'blame-column.commit_info_window'
  if buf_valid(commit_info.state.commit_info_bufnr) or win_valid(commit_info.state.commit_info_winid) then return true end

  for bufnr in pairs(session.detail_buffers) do
    if buf_valid(bufnr) then return true end
    session.detail_buffers[bufnr] = nil
  end
  return false
end

local function restore_panel_window(session, winid)
  if not win_valid(winid) then return end

  if session.panel_managed then
    restore_controller_changes(winid, session.panel_restore, session.panel_managed)
  else
    restore_window_options(winid, session.panel_restore)
  end
end

local function replace_panel_with_normal_buffer(session, winid)
  if not win_valid(winid) then return true end

  local replacement = api.nvim_create_buf(true, false)
  local ok, err = pcall(api.nvim_win_set_buf, winid, replacement)
  if not ok and win_valid(winid) then
    ok, err = pcall(api.nvim_win_call, winid, function()
      vim.cmd('noautocmd buffer ' .. replacement)
    end)
  end
  if not ok then
    pcall(api.nvim_buf_delete, replacement, { force = true })
    return false, err
  end

  restore_panel_window(session, winid)
  return true
end

local function dispose_panel_view(session, winid)
  if not win_valid(winid) then return end

  local closed = pcall(api.nvim_win_close, winid, true)

  if not closed and win_valid(winid) then
    local replaced, err = replace_panel_with_normal_buffer(session, winid)
    if not replaced then
      restore_window_options(winid, session.panel_restore)
      notify('Unable to clean up blame panel: ' .. tostring(err))
    end
  end
end

local function dispose_panel(session, disposition)
  local winid = session.panel_winid
  local bufnr = session.panel_bufnr
  local panel_views = windows_showing_buffer(bufnr)
  local canonical_shows_panel = win_valid(winid) and buf_valid(bufnr) and api.nvim_win_get_buf(winid) == bufnr

  if win_valid(winid) and not canonical_shows_panel then
    if disposition == 'error' then
      -- The split exists but setup failed before the blame buffer was fully
      -- installed. Close that controller-created split when another normal
      -- window remains; if it became the last window, keep it usable.
      local closed = pcall(api.nvim_win_close, winid, true)
      if not closed then restore_panel_window(session, winid) end
    else
      restore_panel_window(session, winid)
    end
  end

  for _, panel_view in ipairs(panel_views) do
    -- During the canonical WinClosed callback that window is already being
    -- disposed by Neovim. Any duplicate views still need explicit cleanup.
    if disposition ~= 'panel_closed' or panel_view ~= winid then dispose_panel_view(session, panel_view) end
  end

  wipe_buffer(bufnr)
end

local restore_source_window_options

local function begin_close(session)
  if M.state.session ~= session or session.status == 'closing' then return false end

  session.status = 'closing'
  session.request_seq = session.request_seq + 1
  session.request = nil
  refresh_public_state(session, 'closing')
  return true
end

local function finish_close(session, disposition)
  if M.state.session ~= session then return end

  M.state.session = nil
  refresh_public_state(nil, 'closed')

  if session.layout_timer then
    pcall(function()
      session.layout_timer:stop()
      if not session.layout_timer:is_closing() then session.layout_timer:close() end
    end)
    session.layout_timer = nil
  end
  collect_inherited_markers(session)
  remove_window_marker(session.source_winid, session.source_marker)
  remove_window_marker(session.panel_winid, session.panel_marker)
  if session.attached_source_bufnr then attached_source_sessions[session.attached_source_bufnr] = nil end
  session.attached_source_bufnr = nil
  if session.augroup then pcall(api.nvim_del_augroup_by_id, session.augroup) end
  close_detail(session)
  normalize_inherited_windows(session)

  if session.bindings_applied then restore_source_window_options(session, false) end

  dispose_panel(session, disposition)
end

local function close_session(session, disposition)
  if begin_close(session) then finish_close(session, disposition or 'close') end
end

local function fail_session(session, message)
  if M.state.session ~= session or session.status == 'closing' then return end
  close_session(session, 'error')
  notify(message)
end

restore_source_window_options = function(session, unconditional)
  if not win_valid(session.source_winid) or not session.source_restore or not session.source_managed then return end
  if session.source_options_bufnr
    and api.nvim_win_get_buf(session.source_winid) ~= session.source_options_bufnr
  then
    return
  end

  if unconditional then
    restore_window_options(session.source_winid, session.source_restore)
  else
    restore_controller_changes(
      session.source_winid,
      session.source_restore,
      session.source_managed,
      source_window_options
    )
  end
  session.source_options_bufnr = nil
  session.source_options_suspended = nil
  session.suspended_source_view = nil
end

local function apply_source_window_options(session)
  local winid = session.source_winid
  local bufnr = api.nvim_win_get_buf(winid)
  local original = capture_window_options(winid, source_window_options)
  local managed = vim.tbl_extend('force', vim.deepcopy(original), {
    wrap = false,
    foldenable = false,
    -- Native scrollbind can propagate a panel buffer redraw back into the
    -- source. CursorMoved/WinScrolled callbacks below synchronize explicitly.
    scrollbind = false,
    cursorbind = false,
  })

  session.source_restore = original
  session.source_managed = managed
  session.source_options_bufnr = bufnr
  session.source_options_suspended = nil
  session.suspended_source_view = nil

  local ok, err = xpcall(function()
    for _, name in ipairs(source_window_options) do
      set_window_option(winid, name, managed[name])
    end
  end, debug.traceback)
  if not ok then
    restore_source_window_options(session, true)
    error(err)
  end
end

local function suspend_source_window_options(session, bufnr)
  if not session.bindings_applied
    or session.source_options_suspended
    or session.source_options_bufnr ~= bufnr
    or not win_valid(session.source_winid)
    or api.nvim_get_current_win() ~= session.source_winid
  then
    return false
  end

  session.suspended_source_view = api.nvim_win_call(session.source_winid, function() return vim.fn.winsaveview() end)
  restore_controller_changes(
    session.source_winid,
    session.source_restore,
    session.source_managed,
    source_window_options
  )
  session.source_options_suspended = true
  return true
end

local function resume_source_window_options(session)
  if not session.source_options_suspended
    or not win_valid(session.source_winid)
    or api.nvim_win_get_buf(session.source_winid) ~= session.source_options_bufnr
  then
    return false
  end

  for _, name in ipairs(source_window_options) do
    set_window_option(session.source_winid, name, session.source_managed[name])
  end

  local saved_view = session.suspended_source_view
  session.source_options_suspended = nil
  session.suspended_source_view = nil
  if saved_view then
    local panel_valid = win_valid(session.panel_winid)
    local source_scrollbind = session.source_managed.scrollbind
    local panel_scrollbind = session.panel_managed and session.panel_managed.scrollbind or false
    local ok, err = xpcall(function()
      set_window_option(session.source_winid, 'scrollbind', false)
      if panel_valid then set_window_option(session.panel_winid, 'scrollbind', false) end
      api.nvim_win_call(session.source_winid, function() vim.fn.winrestview(saved_view) end)
    end, debug.traceback)
    pcall(set_window_option, session.source_winid, 'scrollbind', source_scrollbind)
    if panel_valid then pcall(set_window_option, session.panel_winid, 'scrollbind', panel_scrollbind) end
    if not ok then error(err) end
  end
  return true
end

local function set_buffer_lines(bufnr, lines)
  api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  local ok, err = pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
  pcall(api.nvim_set_option_value, 'modifiable', false, { buf = bufnr })
  if not ok then error(err) end
end

local function blank_panel(session, line_count)
  if not buf_valid(session.panel_bufnr) then return end
  local lines = {}
  for _ = 1, math.max(1, line_count) do
    lines[#lines + 1] = ''
  end
  api.nvim_buf_clear_namespace(session.panel_bufnr, -1, 0, -1)
  set_buffer_lines(session.panel_bufnr, lines)
end

local function resize_pending_panel(session, line_count)
  if not buf_valid(session.panel_bufnr) then return end

  local lines = api.nvim_buf_get_lines(session.panel_bufnr, 0, -1, false)
  while #lines > line_count do
    table.remove(lines)
  end
  while #lines < line_count do
    lines[#lines + 1] = ''
  end
  if #lines == 0 then lines[1] = '' end
  set_buffer_lines(session.panel_bufnr, lines)
end

local function render_buffer(bufnr, file_info)
  local enriched_lines = utils.get_enriched_lines(file_info, config.opts.structurizer_fn)
  local formatted_lines = utils.get_formatted_lines(enriched_lines)

  utils.create_hl_groups(file_info, config.opts.colorizer_fn)
  api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
  set_buffer_lines(bufnr, formatted_lines)

  if config.opts.hl_by_fields then
    utils.hl_blame_by_fields(bufnr, enriched_lines)
  else
    utils.hl_blame_by_lines(bufnr, enriched_lines)
  end
end

local function managed_sync_window(session, winid)
  return winid == session.source_winid or winid == session.panel_winid
end

local function window_view(winid)
  return api.nvim_win_call(winid, function() return vim.fn.winsaveview() end)
end

local function clamped_column(bufnr, row, column)
  local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ''
  return math.min(math.max(column, 0), #line)
end

local function align_bound_view(session, active_winid, other_winid, active_view)
  local source_scrollbind = get_window_option(session.source_winid, 'scrollbind')
  local panel_scrollbind = get_window_option(session.panel_winid, 'scrollbind')
  set_window_option(session.source_winid, 'scrollbind', false)
  set_window_option(session.panel_winid, 'scrollbind', false)

  local ok, err = xpcall(function()
    api.nvim_win_call(other_winid, function()
      local view = vim.fn.winsaveview()
      view.topline = active_view.topline
      view.topfill = active_view.topfill
      vim.fn.winrestview(view)
    end)
  end, debug.traceback)

  pcall(set_window_option, session.source_winid, 'scrollbind', source_scrollbind)
  pcall(set_window_option, session.panel_winid, 'scrollbind', panel_scrollbind)
  if not ok then error(err) end

  if source_scrollbind and panel_scrollbind then
    api.nvim_win_call(active_winid, function() vim.cmd 'syncbind' end)
  end
end

local function synchronize_windows(session, active_winid, force_view)
  if session.syncing
    or not session.bindings_applied
    or not session_live(session)
    or not managed_sync_window(session, active_winid)
    or not win_valid(session.source_winid)
    or not win_valid(session.panel_winid)
    or not buf_valid(session.panel_bufnr)
    or api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr
    or api.nvim_win_get_tabpage(session.source_winid) ~= api.nvim_win_get_tabpage(session.panel_winid)
  then
    return false
  end

  local source_line_count = api.nvim_buf_line_count(api.nvim_win_get_buf(session.source_winid))
  local panel_line_count = api.nvim_buf_line_count(session.panel_bufnr)
  if source_line_count ~= panel_line_count then active_winid = session.source_winid end

  local other_winid = active_winid == session.source_winid and session.panel_winid or session.source_winid
  session.syncing = true
  local ok, err = xpcall(function()
    local active_cursor = api.nvim_win_get_cursor(active_winid)
    local other_bufnr = api.nvim_win_get_buf(other_winid)
    local row = math.min(active_cursor[1], api.nvim_buf_line_count(other_bufnr))
    local other_cursor = api.nvim_win_get_cursor(other_winid)
    local column = other_winid == session.panel_winid and 0 or clamped_column(other_bufnr, row, other_cursor[2])

    if other_cursor[1] ~= row or other_cursor[2] ~= column then
      api.nvim_win_set_cursor(other_winid, { row, column })
    end

    local active_view = window_view(active_winid)
    local other_view = window_view(other_winid)
    if force_view or active_view.topline ~= other_view.topline or active_view.topfill ~= other_view.topfill then
      align_bound_view(session, active_winid, other_winid, active_view)
    end
  end, debug.traceback)
  session.syncing = false

  if not ok and session_live(session) then
    local message = 'Unable to synchronize blame windows: ' .. tostring(err)
    begin_close(session)
    restore_source_window_options(session, true)
    vim.schedule(function()
      if M.state.session ~= session then return end
      finish_close(session, 'error')
      notify(message)
    end)
    return false
  end
  return ok
end

local function update_panel_preserving_source_view(session, update)
  if not session.bindings_applied
    or not win_valid(session.source_winid)
    or not win_valid(session.panel_winid)
    or not buf_valid(session.panel_bufnr)
    or api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr
  then
    return update()
  end

  local source_winid = session.source_winid
  local panel_winid = session.panel_winid
  local source_bufnr = api.nvim_win_get_buf(source_winid)
  local source_view = window_view(source_winid)
  local bindings = {
    source_scrollbind = get_window_option(source_winid, 'scrollbind'),
    source_cursorbind = get_window_option(source_winid, 'cursorbind'),
    panel_scrollbind = get_window_option(panel_winid, 'scrollbind'),
    panel_cursorbind = get_window_option(panel_winid, 'cursorbind'),
  }

  local function restore_bindings()
    if not session_live(session) then return end
    if win_valid(source_winid) then
      pcall(set_window_option, source_winid, 'scrollbind', bindings.source_scrollbind)
      pcall(set_window_option, source_winid, 'cursorbind', bindings.source_cursorbind)
    end
    if win_valid(panel_winid) then
      pcall(set_window_option, panel_winid, 'scrollbind', bindings.panel_scrollbind)
      pcall(set_window_option, panel_winid, 'cursorbind', bindings.panel_cursorbind)
    end
  end

  local unbound, unbind_err = xpcall(function()
    set_window_option(source_winid, 'scrollbind', false)
    set_window_option(source_winid, 'cursorbind', false)
    set_window_option(panel_winid, 'scrollbind', false)
    set_window_option(panel_winid, 'cursorbind', false)
  end, debug.traceback)
  if not unbound then
    restore_bindings()
    error(unbind_err, 0)
  end

  local updated, update_err = xpcall(update, debug.traceback)
  local restored, restore_err = xpcall(function()
    if not session_live(session)
      or not win_valid(source_winid)
      or api.nvim_win_get_buf(source_winid) ~= source_bufnr
      or not win_valid(panel_winid)
      or not buf_valid(session.panel_bufnr)
      or api.nvim_win_get_buf(panel_winid) ~= session.panel_bufnr
    then
      return
    end

    api.nvim_win_call(source_winid, function() vim.fn.winrestview(source_view) end)

    local source_cursor = api.nvim_win_get_cursor(source_winid)
    local panel_line_count = api.nvim_buf_line_count(session.panel_bufnr)
    local panel_row = math.min(source_cursor[1], panel_line_count)
    api.nvim_win_set_cursor(panel_winid, { panel_row, 0 })

    local aligned_source_view = window_view(source_winid)
    api.nvim_win_call(panel_winid, function()
      local panel_view = vim.fn.winsaveview()
      panel_view.topline = math.min(aligned_source_view.topline, panel_line_count)
      panel_view.topfill = aligned_source_view.topfill
      vim.fn.winrestview(panel_view)
    end)
  end, debug.traceback)
  restore_bindings()

  if not updated then error(update_err, 0) end
  if not restored then error(restore_err, 0) end
end

local function vertical_window_change(winid)
  local event = vim.v.event or {}
  local change = event[tostring(winid)] or event[winid]
  return type(change) == 'table' and (change.topline ~= 0 or change.topfill ~= 0)
end

local function scrolled_managed_window(session, match)
  local source_changed = vertical_window_change(session.source_winid)
  local panel_changed = vertical_window_change(session.panel_winid)
  if not source_changed and not panel_changed then return nil end

  if source_changed ~= panel_changed then return source_changed and session.source_winid or session.panel_winid end

  local matched = tonumber(match)
  if managed_sync_window(session, matched) then return matched end

  local current = api.nvim_get_current_win()
  if managed_sync_window(session, current) then return current end
  return session.source_winid
end

local reconcile
local split_parent_winid

local function panel_is_beside_source(session)
  local panel_position = api.nvim_win_get_position(session.panel_winid)
  local source_position = api.nvim_win_get_position(session.source_winid)
  local panel_top, panel_left = panel_position[1], panel_position[2]
  local source_top, source_left = source_position[1], source_position[2]
  local panel_bottom = panel_top + api.nvim_win_get_height(session.panel_winid) - 1
  local source_bottom = source_top + api.nvim_win_get_height(session.source_winid) - 1
  if panel_top ~= source_top or panel_bottom ~= source_bottom then return false end

  if config.opts.side == 'right' then
    return panel_left == source_left + api.nvim_win_get_width(session.source_winid) + 1
  end
  return source_left == panel_left + api.nvim_win_get_width(session.panel_winid) + 1
end

local function rendered_target_is_current(session)
  local target = current_target(session)
  return target and same_target(target, session.rendered_target)
end

local function open_commit_info(session)
  if not session_live(session) or not session.file_info or not rendered_target_is_current(session) then
    if session_live(session) then reconcile(session, 'detail-revalidate', false) end
    return
  end
  if not win_valid(session.panel_winid) or api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr then return end

  local row = api.nvim_win_get_cursor(session.panel_winid)[1]
  local line_info = session.file_info.lines[row]
  if not line_info or line_info.is_modified then return end

  close_detail(session)
  local commit_info = require 'blame-column.commit_info_window'
  local ok, err = pcall(commit_info.open, line_info, config.opts.commit_info, config.opts.mappings)
  if not ok then
    close_detail(session)
    notify('Unable to open commit details: ' .. tostring(err))
    return
  end

  local detail_bufnr = commit_info.state.commit_info_bufnr
  if not buf_valid(detail_bufnr) then return end

  session.detail_buffers[detail_bufnr] = true
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = detail_bufnr })
  api.nvim_create_autocmd('BufWipeout', {
    group = session.augroup,
    buffer = detail_bufnr,
    once = true,
    callback = function() session.detail_buffers[detail_bufnr] = nil end,
    desc = 'Forget a closed blame commit detail buffer',
  })
  vim.keymap.set('n', config.opts.mappings.close_commit_info, function() close_detail(session) end, {
    buffer = detail_bufnr,
    silent = true,
    desc = 'Close blame commit details',
  })
end

local function open_full_commit_info(session)
  if not session_live(session) or not session.file_info or not rendered_target_is_current(session) then
    if session_live(session) then reconcile(session, 'detail-revalidate', false) end
    return
  end

  local row = api.nvim_win_get_cursor(session.panel_winid)[1]
  local line_info = session.file_info.lines[row]
  if line_info and not line_info.is_modified then config.opts.full_commit_info.opener_fn(line_info) end
end

local function create_panel_keymaps(session)
  vim.keymap.set('n', config.opts.mappings.close_commit_info_from_blame, function()
    if detail_is_active(session) then
      close_detail(session)
      return
    end
    close_session(session, 'close')
  end, {
    buffer = session.panel_bufnr,
    silent = true,
    desc = 'Close blame detail or panel',
  })

  if config.opts.commit_info.enabled_from_blame then
    vim.keymap.set('n', config.opts.mappings.open_commit_info_from_blame, function() open_commit_info(session) end, {
      buffer = session.panel_bufnr,
      silent = true,
      desc = 'Open blame commit details',
    })
  end

  if config.opts.full_commit_info.enabled_from_blame then
    vim.keymap.set('n', config.opts.mappings.open_full_commit_info_from_blame, function()
      open_full_commit_info(session)
    end, {
      buffer = session.panel_bufnr,
      silent = true,
      desc = 'Open full blame commit details',
    })
  end
end

local function panel_layout_is_valid(session)
  if not win_valid(session.panel_winid) or not win_valid(session.source_winid) then return false end
  if api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr then return false end
  if api.nvim_win_get_tabpage(session.panel_winid) ~= api.nvim_win_get_tabpage(session.source_winid) then return false end
  if #windows_showing_buffer(session.panel_bufnr) ~= 1 then return false end

  local panel_config = api.nvim_win_get_config(session.panel_winid)
  local source_config = api.nvim_win_get_config(session.source_winid)
  return panel_config.relative == ''
    and not panel_config.external
    and source_config.relative == ''
    and not source_config.external
    and panel_is_beside_source(session)
end

local function schedule_panel_integrity_check(session)
  if session.panel_check_scheduled then return end
  session.panel_check_scheduled = true

  vim.schedule(function()
    session.panel_check_scheduled = false
    if not session_live(session) then return end

    if not win_valid(session.panel_winid) then
      close_session(session, 'panel_closed')
    elseif api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr then
      close_session(session, 'panel_detached')
    elseif not panel_layout_is_valid(session) then
      close_session(session, 'layout_invalid')
    end
  end)
end

local function recorded_window_kind(session, winid)
  if winid == session.source_winid then return 'source' end
  if winid == session.panel_winid then return 'panel' end
  if session.inherited_windows[winid] then return session.inherited_windows[winid] end
end

local function managed_parent_kind(session, winid)
  local recorded = recorded_window_kind(session, winid)
  if recorded then return recorded end

  for index = #session.new_window_contexts, 1, -1 do
    local context = session.new_window_contexts[index]
    if context.parent_kind and not context.windows_before[winid] then return context.parent_kind end
  end
end

split_parent_winid = function(winid)
  local split = api.nvim_win_get_config(winid).split
  local axis = (split == 'left' or split == 'right') and 'row'
    or ((split == 'above' or split == 'below') and 'col' or nil)
  if not axis then return nil end

  local tabnr = vim.fn.win_id2tabwin(winid)[1]
  local layout = vim.fn.winlayout(tabnr)
  local path = {}
  local function find_leaf(node)
    if node[1] == 'leaf' then return node[2] == winid end
    for index, child in ipairs(node[2]) do
      path[#path + 1] = { node = node, index = index }
      if find_leaf(child) then return true end
      path[#path] = nil
    end
    return false
  end
  if not find_leaf(layout) then return nil end

  local parent_is_before = split == 'right' or split == 'below'
  local function edge_leaf(node, use_last)
    if node[1] == 'leaf' then return node[2] end
    local children = node[2]
    return edge_leaf(children[use_last and #children or 1], use_last)
  end

  for index = #path, 1, -1 do
    local entry = path[index]
    if entry.node[1] == axis then
      local sibling_index = entry.index + (parent_is_before and -1 or 1)
      local sibling = entry.node[2][sibling_index]
      if sibling then return edge_leaf(sibling, parent_is_before) end
    end
  end
end

local function remember_context_windows(session, context)
  if not context then return end

  local current_windows = window_id_set()
  for winid in pairs(current_windows) do
    if winid ~= session.source_winid
      and winid ~= session.panel_winid
      and not context.windows_before[winid]
      and not session.processed_new_windows[winid]
    then
      session.processed_new_windows[winid] = true
      local parent = api.nvim_win_get_config(winid).relative == '' and split_parent_winid(winid) or nil
      local parent_kind = take_inherited_marker(session, winid)
      if not parent_kind and parent then parent_kind = recorded_window_kind(session, parent) end
      if not parent_kind and parent and not session.known_windows[parent] and not session.processed_new_windows[parent] then
        parent_kind = context.parent_kind
      end
      if not parent then parent_kind = context.parent_kind end
      if parent_kind then session.inherited_windows[winid] = parent_kind end
    end
  end
  session.known_windows = current_windows
end

local function rescan_window_context(session, context)
  if not session_live(session) then return end
  remember_context_windows(session, context)
  schedule_inherited_window_normalization(session)
  schedule_panel_integrity_check(session)
end

local function schedule_window_context_rescan(session, context)
  if not context then return end
  vim.schedule(function() rescan_window_context(session, context) end)
end

local function create_panel_autocmds(session)
  session.known_windows = window_id_set()
  session.processed_new_windows = {}
  session.last_entered_window = api.nvim_get_current_win()

  local uv = vim.uv or vim.loop
  session.layout_timer = uv.new_timer()
  if session.layout_timer then
    session.layout_timer:start(50, 50, vim.schedule_wrap(function()
      if session_live(session) and not panel_layout_is_valid(session) then close_session(session, 'layout_invalid') end
    end))
  end

  api.nvim_create_autocmd('WinClosed', {
    group = session.augroup,
    pattern = tostring(session.panel_winid),
    callback = function()
      if begin_close(session) then finish_close(session, 'panel_closed') end
    end,
    desc = 'Clean up blame panel after its window closes',
  })

  api.nvim_create_autocmd({ 'BufWinLeave', 'BufHidden', 'BufWipeout' }, {
    group = session.augroup,
    buffer = session.panel_bufnr,
    callback = function() schedule_panel_integrity_check(session) end,
    desc = 'Clean up blame panel after its buffer is replaced',
  })

  api.nvim_create_autocmd('BufWinEnter', {
    group = session.augroup,
    buffer = session.panel_bufnr,
    callback = function() schedule_panel_integrity_check(session) end,
    desc = 'Reject duplicate blame panel views',
  })

  api.nvim_create_autocmd('WinNewPre', {
    group = session.augroup,
    callback = function()
      local parent = api.nvim_get_current_win()
      local context = {
        parent_kind = managed_parent_kind(session, parent),
        windows_before = window_id_set(),
      }
      session.fallback_window_context = nil
      session.new_window_contexts[#session.new_window_contexts + 1] = context
      vim.schedule(function()
        for index = #session.new_window_contexts, 1, -1 do
          if session.new_window_contexts[index] == context then
            table.remove(session.new_window_contexts, index)
            rescan_window_context(session, context)
            schedule_window_context_rescan(session, context)
            break
          end
        end
      end)
    end,
    desc = 'Remember whether a new window inherits managed bindings',
  })

  api.nvim_create_autocmd('WinNew', {
    group = session.augroup,
    callback = function()
      local context = table.remove(session.new_window_contexts) or session.fallback_window_context
      session.fallback_window_context = nil
      if not context then
        context = {
          parent_kind = managed_parent_kind(session, session.last_entered_window),
          windows_before = session.known_windows,
        }
      end
      remember_context_windows(session, context)
      session.known_windows = window_id_set()
      schedule_inherited_window_normalization(session)
      schedule_panel_integrity_check(session)
      schedule_window_context_rescan(session, context)
    end,
    desc = 'Normalize windows derived from a managed blame view',
  })

  api.nvim_create_autocmd({ 'WinResized', 'TabEnter' }, {
    group = session.augroup,
    callback = function()
      schedule_panel_integrity_check(session)
      vim.schedule(function()
        if not session_live(session) then return end
        local current = api.nvim_get_current_win()
        synchronize_windows(session, managed_sync_window(session, current) and current or session.source_winid, true)
      end)
    end,
    desc = 'Keep the blame panel beside its source window',
  })

  api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = session.augroup,
    callback = function()
      local current = api.nvim_get_current_win()
      if managed_sync_window(session, current) then synchronize_windows(session, current, false) end
    end,
    desc = 'Keep blame cursors on the same source line',
  })

  api.nvim_create_autocmd('WinScrolled', {
    group = session.augroup,
    callback = function(args)
      if not session_live(session) then return end
      local panel_scrolled = vertical_window_change(session.panel_winid)
      local active = scrolled_managed_window(session, args.match)
      if active then synchronize_windows(session, active, false) end

      if panel_scrolled then
        local commit_info = require 'blame-column.commit_info_window'
        if commit_info.state.commit_info_bufnr then
          close_detail(session)
          if config.opts.commit_info.follow_cursor then open_commit_info(session) end
        end
      end
    end,
    desc = 'Keep blame viewports aligned while scrolling',
  })

  api.nvim_create_autocmd('CursorMoved', {
    group = session.augroup,
    buffer = session.panel_bufnr,
    callback = function()
      if not session_live(session) then return end
      local commit_info = require 'blame-column.commit_info_window'
      if not commit_info.state.commit_info_bufnr then return end
      close_detail(session)
      if config.opts.commit_info.follow_cursor then open_commit_info(session) end
    end,
    desc = 'Keep blame details aligned with the panel cursor',
  })
end

local function configure_panel_window(session)
  local window_opts = config.opts.window_opts
  for _, name in ipairs({ 'wrap', 'number', 'relativenumber', 'cursorline', 'signcolumn', 'list' }) do
    set_window_option(session.panel_winid, name, window_opts[name])
  end
  set_window_option(session.panel_winid, 'wrap', false)
  set_window_option(session.panel_winid, 'foldenable', false)
  set_window_option(session.panel_winid, 'scrolloff', get_window_option(session.source_winid, 'scrolloff'))
  set_window_option(session.panel_winid, 'winfixwidth', true)

  if get_window_option(session.source_winid, 'winbar') ~= '' then
    set_window_option(session.panel_winid, 'winbar', ' ')
  end
end

local function initialize_window_sync(session)
  session.bindings_applied = true

  local ok, err = xpcall(function()
    set_window_option(session.panel_winid, 'scrollbind', false)
    set_window_option(session.panel_winid, 'cursorbind', false)
    apply_source_window_options(session)

    local source_cursor = api.nvim_win_get_cursor(session.source_winid)
    local panel_line_count = api.nvim_buf_line_count(session.panel_bufnr)
    api.nvim_win_set_cursor(session.panel_winid, { math.min(source_cursor[1], panel_line_count), 0 })

    set_window_option(session.panel_winid, 'scrollbind', false)
    if not synchronize_windows(session, session.source_winid, true) then
      error 'Unable to initialize blame synchronization'
    end
    session.panel_managed = capture_window_options(session.panel_winid)
  end, debug.traceback)
  if not ok then
    restore_source_window_options(session, true)
    error(err)
  end

  session.source_marker = 'CustomBlameSource' .. session.id
  session.panel_marker = 'CustomBlamePanel' .. session.id
  add_window_marker(session.source_winid, session.source_marker)
  add_window_marker(session.panel_winid, session.panel_marker)
end

local function create_panel(session, file_info)
  local panel_bufnr = api.nvim_create_buf(false, true)
  session.panel_bufnr = panel_bufnr
  refresh_public_state(session)

  api.nvim_set_option_value('buftype', 'nofile', { buf = panel_bufnr })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = panel_bufnr })
  api.nvim_set_option_value('swapfile', false, { buf = panel_bufnr })
  api.nvim_set_option_value('filetype', 'blame', { buf = panel_bufnr })
  api.nvim_buf_set_name(panel_bufnr, string.format('blame://column/%d', session.id))
  render_buffer(panel_bufnr, file_info)

  local open_window = controller_opts.open_panel_window or api.nvim_open_win
  session.panel_winid = open_window(panel_bufnr, false, {
    split = config.opts.side == 'right' and 'right' or 'left',
    win = session.source_winid,
  })
  if win_valid(session.panel_winid) and session.panel_winid ~= session.source_winid then
    session.panel_restore = capture_window_options(session.panel_winid)
  end
  refresh_public_state(session)

  if not win_valid(session.panel_winid)
    or session.panel_winid == session.source_winid
    or not win_valid(session.source_winid)
    or api.nvim_win_get_buf(session.panel_winid) ~= panel_bufnr
    or api.nvim_win_get_tabpage(session.panel_winid) ~= api.nvim_win_get_tabpage(session.source_winid)
    or api.nvim_win_get_config(session.panel_winid).relative ~= ''
    or api.nvim_win_get_config(session.source_winid).relative ~= ''
    or not panel_is_beside_source(session)
  then
    error 'Unable to create a dedicated blame split'
  end
  if #windows_showing_buffer(panel_bufnr) ~= 1 then error 'Blame panel buffer was opened in more than one window' end

  configure_panel_window(session)
  local width = math.max(1, utils.calculate_max_width(file_info, config.opts))
  api.nvim_win_set_width(session.panel_winid, width)

  create_panel_keymaps(session)
  initialize_window_sync(session)
  create_panel_autocmds(session)
end

local function render_result(session, file_info, target)
  if type(file_info) ~= 'table' or type(file_info.lines) ~= 'table' or type(file_info.general) ~= 'table' then
    error 'Git blame returned invalid data'
  end

  if session.panel_winid then
    if not win_valid(session.panel_winid)
      or not buf_valid(session.panel_bufnr)
      or api.nvim_win_get_buf(session.panel_winid) ~= session.panel_bufnr
    then
      error 'Blame panel was replaced while Git blame was running'
    end

    update_panel_preserving_source_view(session, function()
      render_buffer(session.panel_bufnr, file_info)
      if config.opts.dynamic_width then
        local width = math.max(1, utils.calculate_max_width(file_info, config.opts))
        api.nvim_win_set_width(session.panel_winid, width)
      end
    end)
  else
    create_panel(session, file_info)
  end

  session.file_info = file_info
  session.rendered_target = copy_target(target)
  session.status = 'open'
  if session.bindings_applied and not synchronize_windows(session, session.source_winid, true) then
    error 'Unable to realign the refreshed blame panel'
  end
end

local function handle_result(session, request, file_info)
  if not session_live(session) or session.request ~= request then return end

  local actual = current_target(session)
  if not actual or not same_target(actual, request) then
    session.request = nil
    refresh_public_state(session)
    vim.schedule(function()
      if session_live(session) then reconcile(session, 'callback-drift', false) end
    end)
    return
  end

  if file_info == nil then
    fail_session(session, 'Unable to read Git blame for ' .. vim.fn.fnamemodify(request.path, ':t'))
    return
  end

  local ok, err = xpcall(function() render_result(session, file_info, request) end, debug.traceback)
  if not ok then
    fail_session(session, 'Unable to open blame panel: ' .. tostring(err))
    return
  end

  if not session_live(session) or session.request ~= request then return end
  session.request = nil
  refresh_public_state(session, 'open')
end

local function write_buffer_binary(bufnr, filepath)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')
  if vim.bo[bufnr].eol then content = content .. '\n' end

  local file, err = io.open(filepath, 'wb')
  if not file then error('Unable to write temporary blame contents: ' .. tostring(err)) end
  local wrote, write_err = file:write(content)
  if not wrote then
    pcall(function() file:close() end)
    error('Unable to write temporary blame contents: ' .. tostring(write_err))
  end
  local closed, close_err = file:close()
  if not closed then error('Unable to flush temporary blame contents: ' .. tostring(close_err)) end
end

local function async_get_git_blame(bufnr, callback)
  local filepath = api.nvim_buf_get_name(bufnr)
  if vim.fn.fnamemodify(filepath, ':t'):sub(1, 1) ~= '-' then
    return git.async_get_git_blame(bufnr, callback)
  end
  if type(parse_blame_output) ~= 'function' then error 'Unable to load the pinned blame parser' end

  -- The pinned plugin builds a shell command whose path can be parsed as an
  -- option. Keep its parser, but use an argv-form command with an explicit --.

  local directory = vim.fn.fnamemodify(filepath, ':h')
  local git_root = vim.trim(vim.fn.system { 'git', '-C', directory, 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error ~= 0 or git_root == '' then
    callback(nil)
    return
  end

  local normalized_root = normalize_path(git_root):gsub('/+$', '')
  local normalized_file = normalize_path(filepath)
  local root_prefix = normalized_root == '' and '/' or normalized_root .. '/'
  if normalized_file:sub(1, #root_prefix) ~= root_prefix then
    callback(nil)
    return
  end
  local relative_path = normalized_file:sub(#root_prefix + 1)

  local tempfile = vim.fn.tempname()
  local wrote, write_err = pcall(write_buffer_binary, bufnr, tempfile)
  if not wrote then
    vim.fn.delete(tempfile)
    error(write_err)
  end
  local stdout = {}
  local started, jobid = pcall(vim.fn.jobstart, {
      'git',
      '-C',
      git_root,
      'blame',
      '--porcelain',
      '--contents',
      tempfile,
      '--',
      './' .. relative_path,
    },
    {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then stdout = data end
      end,
      on_exit = function(_, exit_code)
        vim.fn.delete(tempfile)
        if exit_code ~= 0 then
          callback(nil)
          return
        end

        local ok, file_info = pcall(parse_blame_output, stdout)
        callback(ok and file_info or nil)
      end,
    })
  if not started then
    vim.fn.delete(tempfile)
    error(jobid)
  end
  if jobid <= 0 then
    vim.fn.delete(tempfile)
    error('Unable to start Git blame job: ' .. tostring(jobid))
  end
end

local function request_blame(session, target, clear_panel, force, reason)
  if not session_live(session) then return end
  if not force and session.request and same_target(session.request, target) then return end

  session.request_seq = session.request_seq + 1
  local request = copy_target(target)
  request.seq = session.request_seq
  request.reason = reason

  session.request = request
  session.target = copy_target(target)
  session.source_bufnr = target.bufnr
  session.source_path = target.path
  session.file_info = nil
  session.rendered_target = nil
  close_detail(session)

  if session.panel_bufnr then
    local prepared, prepare_err = xpcall(function()
      local line_count = api.nvim_buf_line_count(target.bufnr)
      update_panel_preserving_source_view(session, function()
        if clear_panel then
          blank_panel(session, line_count)
        else
          resize_pending_panel(session, line_count)
        end
      end)
      if not synchronize_windows(session, session.source_winid, true) then
        error 'Unable to realign the pending blame panel'
      end
    end, debug.traceback)
    if not prepared then
      if session_live(session) and session.request == request then
        fail_session(session, 'Unable to prepare blame refresh: ' .. tostring(prepare_err))
      end
      return
    end
  else
    session.status = 'opening'
  end
  if not session_live(session) or session.request ~= request then return end
  refresh_public_state(session)

  local ok, err = pcall(async_get_git_blame, target.bufnr, function(file_info)
    handle_result(session, request, file_info)
  end)
  if not ok and session_live(session) and session.request == request then
    fail_session(session, 'Unable to start Git blame: ' .. tostring(err))
  end
end

reconcile = function(session, reason, force)
  if not session_live(session) then return end

  local target = current_target(session)
  if not target then
    close_session(session, 'source_closed')
    return
  end

  local changed_file = not same_file(target, session.target)
  if changed_file then
    local available, message = target_status(target.bufnr)
    if not available then
      close_session(session, 'target_unavailable')
      if message then notify(message, vim.log.levels.INFO) end
      return
    end
  end

  if not force and same_target(target, session.target) then return end

  local clear_panel = changed_file or reason == 'file-renamed' or reason == 'reloaded'
  request_blame(session, target, clear_panel, force, reason)
end

local function schedule_source_reconcile(session, reason, force)
  if force or not session.source_reconcile_reason then session.source_reconcile_reason = reason end
  session.source_reconcile_force = session.source_reconcile_force or force
  if session.source_reconcile_scheduled then return end
  session.source_reconcile_scheduled = true
  vim.schedule(function()
    session.source_reconcile_scheduled = false
    local scheduled_reason = session.source_reconcile_reason or 'buffer-entered'
    local scheduled_force = session.source_reconcile_force or false
    session.source_reconcile_reason = nil
    session.source_reconcile_force = nil
    if session_live(session) then reconcile(session, scheduled_reason, scheduled_force) end
  end)
end

local function attach_source_buffer(session, bufnr)
  if session.attached_source_bufnr == bufnr then return end
  if session.attached_source_bufnr then attached_source_sessions[session.attached_source_bufnr] = nil end
  session.attached_source_bufnr = nil

  attached_source_sessions[bufnr] = session
  session.attached_source_bufnr = bufnr
  if attached_source_buffers[bufnr] then return end

  local attached = api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      local active = attached_source_sessions[bufnr]
      if not active or not session_live(active) or not win_valid(active.source_winid) then return end
      if api.nvim_win_get_buf(active.source_winid) ~= bufnr then return end
      schedule_source_reconcile(active, 'lines-changed', true)
    end,
    on_detach = function()
      attached_source_sessions[bufnr] = nil
      attached_source_buffers[bufnr] = nil
    end,
  })
  if attached then
    attached_source_buffers[bufnr] = true
  else
    attached_source_sessions[bufnr] = nil
    session.attached_source_bufnr = nil
  end
end

local function create_source_autocmds(session)
  api.nvim_create_autocmd('BufLeave', {
    group = session.augroup,
    callback = function(args)
      suspend_source_window_options(session, args.buf)
    end,
    desc = 'Preserve per-buffer source options before leaving a managed blame buffer',
  })

  api.nvim_create_autocmd('BufWinLeave', {
    group = session.augroup,
    callback = function(args)
      if session.source_options_bufnr ~= args.buf or api.nvim_get_current_win() ~= session.source_winid then return end
      if not session.source_options_suspended then suspend_source_window_options(session, args.buf) end
      session.source_options_bufnr = nil
      session.source_options_suspended = nil
      session.suspended_source_view = nil
    end,
    desc = 'Forget restored source options after its buffer leaves the blame window',
  })

  api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = session.augroup,
    callback = function(args)
      if not session_live(session) or not win_valid(session.source_winid) then return end
      if api.nvim_win_get_buf(session.source_winid) ~= args.buf then return end

      if args.event == 'BufWinEnter' and session.bindings_applied and session.source_options_bufnr ~= args.buf then
        local ok, err = xpcall(function()
          apply_source_window_options(session)
          if win_valid(session.panel_winid) then
            set_window_option(session.panel_winid, 'scrolloff', get_window_option(session.source_winid, 'scrolloff'))
            if session.panel_managed then
              session.panel_managed.scrolloff = get_restorable_window_option(session.panel_winid, 'scrolloff')
            end
          end
          synchronize_windows(session, session.source_winid, true)
        end, debug.traceback)
        if not ok then
          fail_session(session, 'Unable to manage the new blame source buffer: ' .. tostring(err))
          return
        end
      end

      attach_source_buffer(session, args.buf)
      schedule_source_reconcile(session, 'buffer-entered', false)
    end,
    desc = 'Follow the source window blame target',
  })

  api.nvim_create_autocmd('BufFilePost', {
    group = session.augroup,
    callback = function(args)
      if not session_live(session) or not win_valid(session.source_winid) then return end
      if api.nvim_win_get_buf(session.source_winid) ~= args.buf then return end
      reconcile(session, 'file-renamed', true)
    end,
    desc = 'Refresh blame after a source buffer rename',
  })

  api.nvim_create_autocmd('BufReadPost', {
    group = session.augroup,
    callback = function(args)
      if not session_live(session) or not win_valid(session.source_winid) then return end
      if api.nvim_win_get_buf(session.source_winid) ~= args.buf then return end
      -- BufReadPost can run before the final changedtick is visible. Coalesce
      -- it with BufEnter and capture one stable snapshot on the next loop.
      schedule_source_reconcile(session, 'reloaded', true)
    end,
    desc = 'Refresh blame after reloading the source buffer',
  })

  api.nvim_create_autocmd('WinEnter', {
    group = session.augroup,
    callback = function()
      if not session_live(session) then return end
      local fallback = session.fallback_window_context
      local current = api.nvim_get_current_win()
      if fallback and fallback.windows_before[current] then session.fallback_window_context = nil end
      session.last_entered_window = current

      if session.source_options_suspended then
        local ok, err = xpcall(function()
          if resume_source_window_options(session) then
            synchronize_windows(session, session.source_winid, true)
          end
        end, debug.traceback)
        if not ok then
          restore_source_window_options(session, true)
          fail_session(session, 'Unable to resume blame source options: ' .. tostring(err))
          return
        end
      end

      if managed_sync_window(session, current) then synchronize_windows(session, current, true) end
      if current == session.source_winid then close_detail(session) end
    end,
    desc = 'Close blame details when returning to the source',
  })

  api.nvim_create_autocmd('WinLeave', {
    group = session.augroup,
    callback = function()
      if not session_live(session) then return end
      local leaving = api.nvim_get_current_win()
      local parent_kind = leaving == session.source_winid and 'source'
        or (leaving == session.panel_winid and 'panel')
        or nil
      if parent_kind and #session.new_window_contexts == 0 then
        local context = {
          parent_kind = parent_kind,
          windows_before = window_id_set(),
        }
        session.fallback_window_context = context
        vim.schedule(function()
          if session.fallback_window_context == context then session.fallback_window_context = nil end
        end)
      end
    end,
    desc = 'Track windows derived from a managed blame view',
  })

  api.nvim_create_autocmd('WinClosed', {
    group = session.augroup,
    pattern = tostring(session.source_winid),
    callback = function()
      if not begin_close(session) then return end
      vim.schedule(function()
        if M.state.session == session then finish_close(session, 'source_closed') end
      end)
    end,
    desc = 'Clean up blame after the source window closes',
  })

  attach_source_buffer(session, api.nvim_win_get_buf(session.source_winid))
end

local function begin_session(source_winid)
  if not win_valid(source_winid) then return end

  local bufnr = api.nvim_win_get_buf(source_winid)
  local available, message = target_status(bufnr)
  if not available then
    if message then notify(message, vim.log.levels.INFO) end
    return
  end

  next_session_id = next_session_id + 1
  local session = {
    id = next_session_id,
    status = 'opening',
    request_seq = 0,
    source_winid = source_winid,
    source_tabpage = api.nvim_win_get_tabpage(source_winid),
    detail_buffers = {},
    inherited_windows = {},
    new_window_contexts = {},
  }
  session.augroup = api.nvim_create_augroup('CustomBlameColumn' .. session.id, { clear = true })

  M.state.session = session
  refresh_public_state(session, 'opening')
  create_source_autocmds(session)

  local target = current_target(session)
  if not target then
    close_session(session, 'source_closed')
    return
  end
  request_blame(session, target, true, false, 'initial')
end

local function current_window_belongs_to(session)
  local winid = api.nvim_get_current_win()
  if winid == session.source_winid or winid == session.panel_winid then return true end

  local bufnr = api.nvim_get_current_buf()
  return bufnr == session.panel_bufnr or session.detail_buffers[bufnr] == true
end

function M.toggle()
  local session = M.state.session
  if not session then
    begin_session(api.nvim_get_current_win())
    return
  end

  if session.status == 'closing' then return end

  if session.status == 'opening' and api.nvim_get_current_win() == session.source_winid then
    local target = current_target(session)
    if target and same_target(target, session.target) then return end
    reconcile(session, 'toggle-revalidate', false)
    return
  end

  if current_window_belongs_to(session) then
    close_session(session, 'close')
    return
  end

  close_session(session, 'close')
  begin_session(api.nvim_get_current_win())
end

function M.close()
  local session = M.state.session
  if session then close_session(session, 'close') end
end

function M.setup(opts)
  controller_opts = opts or {}
  M.close()

  pcall(api.nvim_del_user_command, 'BlameColumnToggle')
  api.nvim_create_user_command('BlameColumnToggle', M.toggle, {})
end

return M
