-- Run from the dotfiles root with:
-- NVIM_LOG_FILE=/tmp/blame-column-alignment-nvim.log nvim --headless \
--   -u NONE -i NONE -n -l nvim/tests/blame_column_alignment_spec.lua

local api = vim.api
local fn = vim.fn

local source = debug.getinfo(1, 'S').source
assert(source:sub(1, 1) == '@', 'test must be run from a file')

local test_file = fn.fnamemodify(source:sub(2), ':p')
local nvim_root = fn.fnamemodify(test_file, ':h:h')
local config_root = nvim_root .. '/.config/nvim'
local plugin_root = fn.stdpath 'data' .. '/lazy/blame-column.nvim'

assert(fn.isdirectory(config_root) == 1, 'unable to locate the repository Neovim config: ' .. config_root)
assert(
  fn.isdirectory(plugin_root) == 1,
  'blame-column.nvim is not installed at ' .. plugin_root .. '; start the normal config once so lazy.nvim installs it'
)

vim.opt.runtimepath:prepend(plugin_root)
vim.opt.runtimepath:prepend(config_root)

local fixture_root
local controller
local line_count = 160
local second_line_count = 64

local function fail(message)
  error(message, 2)
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    fail(('%s: expected %s, got %s'):format(label, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function git(...)
  local argv = { 'git', '-C', fixture_root, ... }
  local output = fn.system(argv)
  if vim.v.shell_error ~= 0 then
    fail(('command failed (%d): %s\n%s'):format(vim.v.shell_error, table.concat(argv, ' '), output))
  end
  return output
end

local function create_fixture()
  -- Do not let personal Git profiles, signing, or hooks affect the disposable
  -- repository. The controller's asynchronous blame job inherits this too.
  vim.env.GIT_CONFIG_GLOBAL = '/dev/null'
  vim.env.GIT_CONFIG_SYSTEM = '/dev/null'
  vim.env.GIT_CONFIG_NOSYSTEM = '1'

  fixture_root = fn.tempname() .. '-blame-column-alignment'
  assert_equal(fn.mkdir(fixture_root, 'p'), 1, 'create fixture directory')

  local long_lines = {
    [28] = true,
    [73] = true,
    [80] = true,
    [81] = true,
    [148] = true,
    [151] = true,
    [152] = true,
    [154] = true,
    [160] = true,
  }
  local lines = {}
  for row = 1, line_count do
    if long_lines[row] or row % 17 == 0 then
      lines[row] = ('// annotation %03d: %s'):format(
        row,
        ('wrapped-comment-%03d keeps source and blame rows aligned; '):format(row):rep(5)
      )
    else
      lines[row] = ('int generated_line_%03d = %d;'):format(row, row)
    end
  end

  local path = fixture_root .. '/alignment_fixture.h'
  local second_path = fixture_root .. '/alignment_second.h'
  assert_equal(fn.writefile(lines, path), 0, 'write fixture')
  local second_lines = {}
  for row = 1, second_line_count do
    second_lines[row] = ('int second_file_line_%03d = %d;'):format(row, row)
  end
  assert_equal(fn.writefile(second_lines, second_path), 0, 'write second fixture')
  git('init', '-q')
  git('config', 'core.hooksPath', '/dev/null')
  git('config', 'commit.gpgsign', 'false')
  git('config', 'user.name', 'Blame Alignment Test')
  git('config', 'user.email', 'blame-alignment@example.invalid')
  git('add', '--', 'alignment_fixture.h', 'alignment_second.h')
  git('commit', '-q', '-m', 'Create wrapped blame alignment fixture')
  return path, second_path
end

local function get_win_option(winid, name)
  return api.nvim_get_option_value(name, { win = winid })
end

local function set_win_option(winid, name, value)
  api.nvim_set_option_value(name, value, { win = winid })
end

local function win_view(winid)
  return api.nvim_win_call(winid, function() return fn.winsaveview() end)
end

local function win_foldclosed(winid, row)
  return api.nvim_win_call(winid, function() return fn.foldclosed(row) end)
end

local function pair_snapshot(source_winid, panel_winid)
  local source_cursor = api.nvim_win_get_cursor(source_winid)
  local panel_cursor = api.nvim_win_get_cursor(panel_winid)
  local source_view = win_view(source_winid)
  local panel_view = win_view(panel_winid)
  local panel_text = api.nvim_buf_get_lines(
    api.nvim_win_get_buf(panel_winid),
    panel_cursor[1] - 1,
    panel_cursor[1],
    false
  )[1]

  return {
    source_line = source_cursor[1],
    panel_line = panel_cursor[1],
    source_topline = source_view.topline,
    panel_topline = panel_view.topline,
    panel_text = panel_text,
  }
end

local function snapshot_aligned(snapshot, expected_line)
  return snapshot.source_line == snapshot.panel_line
    and (expected_line == nil or snapshot.source_line == expected_line)
    and snapshot.source_topline == snapshot.panel_topline
    and snapshot.panel_text == ('L%03d'):format(snapshot.source_line)
end

local function wait_for_alignment(label, source_winid, panel_winid, expected_line)
  local snapshot
  local aligned = vim.wait(1500, function()
    if not api.nvim_win_is_valid(source_winid) or not api.nvim_win_is_valid(panel_winid) then return false end
    snapshot = pair_snapshot(source_winid, panel_winid)
    return snapshot_aligned(snapshot, expected_line)
  end, 10)

  if not aligned then
    snapshot = api.nvim_win_is_valid(source_winid) and api.nvim_win_is_valid(panel_winid)
        and pair_snapshot(source_winid, panel_winid)
      or { source_valid = api.nvim_win_is_valid(source_winid), panel_valid = api.nvim_win_is_valid(panel_winid) }
    fail(label .. ': source/panel did not align: ' .. vim.inspect(snapshot))
  end
end

local function wait_for_open(label)
  local opened = vim.wait(5000, function()
    local session = controller.state.session
    return controller.state.status == 'open'
      and session ~= nil
      and session.file_info ~= nil
      and session.panel_winid ~= nil
      and api.nvim_win_is_valid(session.panel_winid)
  end, 10)
  if not opened then fail(label .. ': controller did not open: ' .. vim.inspect(controller.state)) end
  return controller.state.session
end

local function wait_for_refresh(label, source_winid, panel_winid, expected_count)
  local refreshed = vim.wait(5000, function()
    local session = controller.state.session
    return controller.state.status == 'open'
      and session ~= nil
      and session.request == nil
      and session.file_info ~= nil
      and #session.file_info.lines == expected_count
      and api.nvim_buf_line_count(session.panel_bufnr) == expected_count
  end, 10)
  if not refreshed then fail(label .. ': blame refresh did not reach ' .. expected_count .. ' rows') end

  api.nvim_exec_autocmds('CursorMoved', { buffer = api.nvim_win_get_buf(source_winid) })
  wait_for_alignment(label, source_winid, panel_winid, api.nvim_win_get_cursor(source_winid)[1])
end

local function feed(winid, keys)
  api.nvim_set_current_win(winid)
  local encoded = api.nvim_replace_termcodes(keys, true, false, true)
  api.nvim_feedkeys(encoded, 'nx', false)

  -- Scripted :normal/feedkeys movement in a headless -l invocation does not
  -- emit user-input CursorMoved or WinScrolled events. Dispatch the installed
  -- autocmds explicitly after the real operation for deterministic in-process
  -- coverage. A separate RPC-driven integration probe covers native
  -- WinScrolled event selection.
  api.nvim_exec_autocmds('CursorMoved', { buffer = api.nvim_win_get_buf(winid) })
  api.nvim_exec_autocmds('WinScrolled', { pattern = tostring(winid) })
  vim.wait(30)
end

local function exercise(label, driver_winid, source_winid, panel_winid, keys, expected_line)
  feed(driver_winid, keys)
  wait_for_alignment(label .. ' (' .. keys .. ')', source_winid, panel_winid, expected_line)
  assert_equal(api.nvim_get_current_win(), driver_winid, label .. ' retains the driving window')
end

local function assert_managed_options(label, source_winid, panel_winid, original_scrolloff)
  assert_equal(get_win_option(source_winid, 'wrap'), false, label .. ' source wrap disabled')
  assert_equal(get_win_option(source_winid, 'foldenable'), false, label .. ' source folds disabled')
  assert_equal(get_win_option(panel_winid, 'wrap'), false, label .. ' panel wrap disabled')
  assert_equal(get_win_option(panel_winid, 'foldenable'), false, label .. ' panel folds disabled')
  assert_equal(get_win_option(source_winid, 'cursorbind'), false, label .. ' source cursorbind disabled')
  assert_equal(get_win_option(panel_winid, 'cursorbind'), false, label .. ' panel cursorbind disabled')
  assert_equal(get_win_option(source_winid, 'scrollbind'), false, label .. ' source scrollbind disabled')
  assert_equal(get_win_option(panel_winid, 'scrollbind'), false, label .. ' panel scrollbind disabled')
  assert_equal(get_win_option(panel_winid, 'scrolloff'), original_scrolloff, label .. ' panel scrolloff inherited')
  assert_equal(api.nvim_win_get_height(panel_winid), api.nvim_win_get_height(source_winid), label .. ' equal heights')
end

local function close_and_assert_restored(label, source_winid, original, fold_row)
  api.nvim_set_current_win(source_winid)
  controller.close()
  local closed = vim.wait(1000, function()
    return controller.state.status == 'closed' and controller.state.session == nil
  end, 10)
  if not closed then fail(label .. ': controller did not close') end

  for name, value in pairs(original) do
    assert_equal(get_win_option(source_winid, name), value, label .. ' restores ' .. name)
  end
  fold_row = fold_row or 50
  assert_equal(win_foldclosed(source_winid, fold_row), fold_row, label .. ' restores the pre-existing closed fold')
end

local function setup_controller(allowed_paths)
  require('blame-column').setup {
    side = 'right',
    dynamic_width = false,
    auto_width = false,
    max_width = 14,
    hl_by_fields = false,
    structurizer_fn = function(_, line_info)
      return {
        fields = { { text = ('L%03d'):format(line_info.line_number) } },
        format = '%s',
        hl = 'Normal',
      }
    end,
    colorizer_fn = function() return {} end,
    commit_info = { enabled_from_blame = false, follow_cursor = false },
    full_commit_info = { enabled_from_blame = false },
  }

  controller = require 'custom.blame_column_controller'
  controller.setup {
    target_status = function(bufnr)
      return allowed_paths[api.nvim_buf_get_name(bufnr)] == true, 'test only permits its tracked fixtures'
    end,
  }
end

local function run()
  vim.o.columns = 62
  vim.o.lines = 22
  vim.o.laststatus = 0
  vim.o.showtabline = 0
  vim.o.equalalways = false
  vim.o.hidden = true
  vim.o.scrollopt = 'ver,jump'

  local fixture_path, second_path = create_fixture()
  setup_controller { [fixture_path] = true, [second_path] = true }

  vim.cmd.edit(fn.fnameescape(second_path))
  local source_winid = api.nvim_get_current_win()
  set_win_option(source_winid, 'wrap', false)
  set_win_option(source_winid, 'foldenable', true)
  set_win_option(source_winid, 'scrollbind', true)
  set_win_option(source_winid, 'cursorbind', true)
  set_win_option(source_winid, 'scrolloff', 2)
  set_win_option(source_winid, 'foldmethod', 'manual')
  api.nvim_win_call(source_winid, function() vim.cmd '10,12fold' end)
  local second_original = {
    wrap = false,
    foldenable = true,
    scrollbind = true,
    cursorbind = true,
    scrolloff = 2,
  }

  vim.cmd.edit(fn.fnameescape(fixture_path))

  local source_bufnr = api.nvim_get_current_buf()
  assert_equal(api.nvim_buf_line_count(source_bufnr), line_count, 'fixture line count')

  set_win_option(source_winid, 'wrap', true)
  set_win_option(source_winid, 'foldenable', true)
  set_win_option(source_winid, 'scrollbind', false)
  set_win_option(source_winid, 'cursorbind', false)
  set_win_option(source_winid, 'scrolloff', 4)
  set_win_option(source_winid, 'foldmethod', 'manual')
  api.nvim_win_call(source_winid, function() vim.cmd '50,55fold' end)

  local original = {
    wrap = true,
    foldenable = true,
    scrollbind = false,
    cursorbind = false,
    scrolloff = 4,
  }
  assert_equal(win_foldclosed(source_winid, 50), 50, 'fixture fold starts closed')

  -- First session: open in the middle of a long comment, then drive both panes.
  feed(source_winid, '80Gzz')
  controller.toggle()
  local session = wait_for_open 'mid-file open'
  local panel_winid = session.panel_winid
  assert_equal(#session.file_info.lines, line_count, 'mid-file blame record count')
  assert_equal(api.nvim_buf_line_count(session.panel_bufnr), line_count, 'mid-file panel line count')
  assert_managed_options('mid-file open', source_winid, panel_winid, original.scrolloff)
  assert_equal(win_foldclosed(source_winid, 50), -1, 'mid-file open exposes folds while aligned')
  local long_line = api.nvim_buf_get_lines(source_bufnr, 79, 80, false)[1]
  if fn.strdisplaywidth(long_line) <= api.nvim_win_get_width(source_winid) then
    fail('fixture is not narrow enough to make line 80 wrap when wrap is enabled')
  end
  wait_for_alignment('mid-file initial row', source_winid, panel_winid, 80)

  exercise('source long comment at top', source_winid, source_winid, panel_winid, '28Gzt', 28)
  exercise('source centered movement', source_winid, source_winid, panel_winid, '73Gzz', 73)
  local before_page = api.nvim_win_get_cursor(source_winid)[1]
  exercise('source page scroll', source_winid, source_winid, panel_winid, '<C-d>')
  if api.nvim_win_get_cursor(source_winid)[1] == before_page then fail('source <C-d> did not move the cursor') end
  exercise('source near-EOF bottom placement', source_winid, source_winid, panel_winid, '152Gzb', 152)
  exercise('source reaches EOF', source_winid, source_winid, panel_winid, 'G', line_count)

  exercise('panel returns to middle', panel_winid, source_winid, panel_winid, '81Gzt', 81)
  local before_panel_page = api.nvim_win_get_cursor(panel_winid)[1]
  exercise('panel page scroll', panel_winid, source_winid, panel_winid, '<C-d>')
  if api.nvim_win_get_cursor(panel_winid)[1] == before_panel_page then fail('panel <C-d> did not move the cursor') end
  exercise('panel near-EOF bottom placement', panel_winid, source_winid, panel_winid, '151Gzb', 151)
  exercise('panel reaches start', panel_winid, source_winid, panel_winid, 'gg', 1)

  exercise('source prepares live edit', source_winid, source_winid, panel_winid, '90Gzz', 90)
  api.nvim_buf_set_lines(source_bufnr, 89, 89, false, { 'int locally_inserted_line = 1;' })
  wait_for_refresh('live insert refresh', source_winid, panel_winid, line_count + 1)
  exercise('source selects inserted row', source_winid, source_winid, panel_winid, '90Gzz', 90)
  assert_equal(controller.state.session.file_info.lines[90].is_modified, true, 'live insert is rendered as modified')

  api.nvim_buf_set_lines(source_bufnr, 89, 90, false, {})
  wait_for_refresh('live delete refresh', source_winid, panel_winid, line_count)
  close_and_assert_restored('mid-file close', source_winid, original)

  -- Second session: opening on the final wrapped line used to retain a stale
  -- viewport offset. Reopen there and alternate pure scrolling and cursor moves.
  feed(source_winid, 'Gzb')
  assert_equal(api.nvim_win_get_cursor(source_winid)[1], line_count, 'prepare EOF reopen')
  controller.toggle()
  session = wait_for_open 'EOF open'
  panel_winid = session.panel_winid
  assert_managed_options('EOF open', source_winid, panel_winid, original.scrolloff)
  wait_for_alignment('EOF initial row', source_winid, panel_winid, line_count)

  exercise('source leaves EOF', source_winid, source_winid, panel_winid, '148Gzt', 148)
  exercise('source one-row scroll', source_winid, source_winid, panel_winid, '<C-e>')
  exercise('source returns to EOF', source_winid, source_winid, panel_winid, 'Gzb', line_count)
  exercise('panel leaves EOF', panel_winid, source_winid, panel_winid, '154Gzt', 154)
  exercise('panel one-row scroll', panel_winid, source_winid, panel_winid, '<C-e>')
  exercise('panel returns to EOF', panel_winid, source_winid, panel_winid, 'Gzb', line_count)
  close_and_assert_restored('EOF close', source_winid, original)

  -- Third session: the source window follows another tracked buffer. Each
  -- buffer's remembered window-local options must be restored independently.
  feed(source_winid, '80Gzz')
  controller.toggle()
  session = wait_for_open 'buffer-switch open'
  panel_winid = session.panel_winid
  wait_for_alignment('buffer-switch initial row', source_winid, panel_winid, 80)

  vim.cmd.edit(fn.fnameescape(second_path))
  wait_for_refresh('tracked buffer switch', source_winid, panel_winid, second_line_count)
  assert_managed_options('tracked buffer switch', source_winid, panel_winid, second_original.scrolloff)
  close_and_assert_restored('tracked buffer close', source_winid, second_original, 10)

  vim.cmd.edit(fn.fnameescape(fixture_path))
  for name, value in pairs(original) do
    assert_equal(get_win_option(source_winid, name), value, 'tracked buffer switch preserves first buffer ' .. name)
  end
  assert_equal(win_foldclosed(source_winid, 50), 50, 'tracked buffer switch preserves first buffer fold')

  print('PASS: blame sidebar cursors, views, rendered rows, EOF scrolling, and window options stay aligned')
end

local function cleanup()
  if controller then pcall(controller.close) end
  if fixture_root then pcall(fn.delete, fixture_root, 'rf') end
end

local ok, err = xpcall(run, debug.traceback)
cleanup()
if not ok then
  api.nvim_err_writeln('FAIL: blame sidebar alignment regression\n' .. err)
  vim.cmd 'cquit 1'
end
vim.cmd 'qa!'
