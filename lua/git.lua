-- ═════════════════════════════════════════════════════════════════════
--  Git integration — zero plugins
--  (1) Inline blame ghost text on current line
--  (2) Alt+d side-by-side diff vs HEAD (iwhite)
--  (3) Git workflow: status / stage / commit / push / log
-- ═════════════════════════════════════════════════════════════════════

local M = {}
local ns = vim.api.nvim_create_namespace('git_blame')
local path_cache = {}
local path_cache_count = 0
local PATH_CACHE_MAX = 500
-- dir -> git root cache is now shared in lua/utils/git_root.lua
local git_root = require('utils.git_root')

local function set_path_cache(buf, value)
  if not path_cache[buf] then path_cache_count = path_cache_count + 1 end
  path_cache[buf] = value
  if path_cache_count > PATH_CACHE_MAX then
    local pruned = {}
    local n = 0
    for b, v in pairs(path_cache) do
      if vim.api.nvim_buf_is_valid(b) then pruned[b] = v; n = n + 1 end
    end
    path_cache = pruned
    path_cache_count = n
  end
end

local blame_enabled = false  -- disabled by default, toggle with <leader>tb
local last_blame = { buf = -1, line = -1, text = '' }
if _G._blame_timer then pcall(function() _G._blame_timer:stop(); _G._blame_timer:close() end) end
local blame_timer = vim.uv.new_timer()
local UNCOMMITTED_HASH = string.rep('0', 40)
_G._blame_timer = blame_timer
local diff_tempfile = nil
local diff_session = nil
local clear_blame

-- ── Helpers ─────────────────────────────────────────────────────────

local function reset_last_blame()
  last_blame = { buf = -1, line = -1, text = '' }
end

local function stop_blame_timer()
  if blame_timer and not blame_timer:is_closing() then
    blame_timer:stop()
  end
end

local function confirm_write_if_modified(buf, action)
  if not vim.bo[buf].modified then return true end
  local choice = vim.fn.confirm('Save changes before ' .. action .. '?', '&Yes\n&No', 1)
  if choice ~= 1 then return false end
  local ok, err = pcall(vim.cmd, 'write')
  if not ok then
    vim.notify('Write failed: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function is_regular_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= '' then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or name:match('^%w+://') then return false end
  return true
end

local function relpath_from_root(root, abs)
  local prefix = root .. '/'
  if abs:sub(1, #prefix) == prefix then
    return abs:sub(#prefix + 1)
  end
  return nil
end

local function truncate(text, max_len)
  if not text or text == '' then return '' end
  if #text <= max_len then return text end
  return text:sub(1, max_len - 3) .. '...'
end

local function get_git_info(buf)
  if not is_regular_buffer(buf) then return nil end

  local abs = vim.api.nvim_buf_get_name(buf)
  local cached = path_cache[buf]
  if cached and cached.abs == abs then
    return cached.ok and cached or nil
  end

  local dir = vim.fn.fnamemodify(abs, ':h')

  -- Sync version — only for on-demand commands (diff, stage, commit)
  local root = git_root.get(dir)
  if not root then
    set_path_cache(buf, { abs = abs, ok = false })
    return nil
  end

  local relpath = relpath_from_root(root, abs)
  if not relpath then
    set_path_cache(buf, { abs = abs, ok = false })
    return nil
  end

  local tracked_obj = vim.system(
    { 'git', 'ls-files', '--error-unmatch', '--', relpath },
    { cwd = root, text = true }
  ):wait()

  local info = {
    abs = abs,
    root = root,
    relpath = relpath,
    tracked = tracked_obj.code == 0,
    ok = true,
  }

  set_path_cache(buf, info)
  return info
end

--- Fully async version of get_git_info — never blocks the editor.
--- Calls callback(info) on success, callback(nil) on failure.
local function get_git_info_async(buf, callback)
  if not is_regular_buffer(buf) then return callback(nil) end

  local abs = vim.api.nvim_buf_get_name(buf)
  local cached = path_cache[buf]
  if cached and cached.abs == abs then
    return callback(cached.ok and cached or nil)
  end

  local dir = vim.fn.fnamemodify(abs, ':h')

  -- Check directory root cache first (avoids git rev-parse entirely)
  local cached_root, known = git_root.peek(dir)
  if known then
    if not cached_root then
      set_path_cache(buf, { abs = abs, ok = false })
      return callback(nil)
    end
    local relpath = relpath_from_root(cached_root, abs)
    if not relpath then
      set_path_cache(buf, { abs = abs, ok = false })
      return callback(nil)
    end
    vim.system(
      { 'git', 'ls-files', '--error-unmatch', '--', relpath },
      { cwd = cached_root, text = true },
      function(tracked_obj)
        local info = {
          abs = abs, root = cached_root, relpath = relpath,
          tracked = tracked_obj.code == 0, ok = true,
        }
        set_path_cache(buf, info)
        callback(info)
      end
    )
    return
  end

  -- No cache — async git rev-parse, then async ls-files
  vim.system(
    { 'git', 'rev-parse', '--show-toplevel' },
    { cwd = dir, text = true },
    function(root_obj)
      if root_obj.code ~= 0 then
        set_path_cache(buf, { abs = abs, ok = false })
        return callback(nil)
      end
      local root = vim.trim(root_obj.stdout)
      git_root.store(dir, root)

      local relpath = relpath_from_root(root, abs)
      if not relpath then
        set_path_cache(buf, { abs = abs, ok = false })
        return callback(nil)
      end

      vim.system(
        { 'git', 'ls-files', '--error-unmatch', '--', relpath },
        { cwd = root, text = true },
        function(tracked_obj)
          local info = {
            abs = abs, root = root, relpath = relpath,
            tracked = tracked_obj.code == 0, ok = true,
          }
          set_path_cache(buf, info)
          callback(info)
        end
      )
    end
  )
end

-- ═════════════════════════════════════════════════════════════════════
--  (1) INLINE BLAME — ghost text on current line
-- ═════════════════════════════════════════════════════════════════════

local function format_relative_time(epoch)
  local delta = os.time() - (tonumber(epoch) or 0)
  if delta < 60 then return 'just now' end
  if delta < 3600 then return math.floor(delta / 60) .. 'm ago' end
  if delta < 86400 then return math.floor(delta / 3600) .. 'h ago' end
  if delta < 2592000 then return math.floor(delta / 86400) .. 'd ago' end
  if delta < 31536000 then return math.floor(delta / 2592000) .. 'mo ago' end
  return math.floor(delta / 31536000) .. 'y ago'
end

local function format_blame(commit, author, epoch, summary)
  if not author or author == 'Not Committed Yet' or commit == UNCOMMITTED_HASH then
    return {
      { '  working tree', 'GhostBlameHash' },
      { '  Uncommitted changes', 'GhostBlameSummary' },
    }
  end

  local short_commit = truncate(commit or '', 8)
  local short_author = truncate(author, 18)
  local short_summary = truncate(summary or '', 56)
  local chunks = {
    { '  ' .. short_commit, 'GhostBlameHash' },
    { '  ' .. short_author, 'GhostBlameAuthor' },
    { ', ' .. format_relative_time(epoch), 'GhostBlameMeta' },
  }

  if short_summary ~= '' then
    chunks[#chunks + 1] = { '  ' .. short_summary, 'GhostBlameSummary' }
  end

  return chunks
end

local function update_blame(buf, line)
  if not blame_enabled then return end
  if not is_regular_buffer(buf) then return end
  if vim.b[buf].bigfile then return end

  get_git_info_async(buf, function(info)
    if not info or not info.tracked then
      vim.schedule(function() clear_blame(buf) end)
      return
    end

    -- Async blame for single line
    vim.system(
      { 'git', 'blame', '-L', line .. ',' .. line, '--porcelain', '--', info.relpath },
      { cwd = info.root, text = true },
      function(obj)
        if obj.code ~= 0 then return end

        local author, epoch, summary, commit
        for l in obj.stdout:gmatch('[^\n]+') do
          if not commit then commit = l:match('^(%x+)') end
          if l:match('^author ') then author = l:sub(8) end
          if l:match('^author%-time ') then epoch = l:sub(13) end
          if l:match('^summary ') then summary = l:sub(9) end
        end

        local text = format_blame(commit, author, epoch, summary)

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then return end
          if vim.api.nvim_get_current_buf() ~= buf then return end
          if vim.api.nvim_win_get_cursor(0)[1] ~= line then return end
          if not blame_enabled then return end

          vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
          vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, {
            virt_text = text,
            virt_text_pos = 'eol',
            hl_mode = 'combine',
            priority = 1,
          })
          last_blame = { buf = buf, line = line, text = table.concat(vim.tbl_map(function(chunk)
            return chunk[1]
          end, text)) }
        end)
      end
    )
  end)
end

clear_blame = function(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  reset_last_blame()
end

local function schedule_blame(buf, line)
  if not blame_enabled then return end
  if not is_regular_buffer(buf) then return end
  if vim.b[buf].bigfile then return end

  if last_blame.buf == buf and last_blame.line == line then return end

  stop_blame_timer()
  blame_timer:start(require('config').blame_debounce_ms, 0, vim.schedule_wrap(function()
    update_blame(buf, line)
  end))
end

-- ═════════════════════════════════════════════════════════════════════
--  (2a) FAST IN-MEMORY DIFF vs HEAD  (Alt+d — zero disk I/O)
-- ═════════════════════════════════════════════════════════════════════

local function cleanup_diff_session(close_window)
  if not diff_session then return end

  local session = diff_session
  diff_session = nil

  if vim.o.diffopt ~= session.saved_diffopt then
    vim.o.diffopt = session.saved_diffopt
  end

  for _, win in ipairs({ session.head_win, session.base_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_set_current_win, win)
      pcall(vim.cmd, 'diffoff')
    end
  end

  if close_window then
    if session.head_win and vim.api.nvim_win_is_valid(session.head_win) then
      pcall(vim.api.nvim_win_close, session.head_win, true)
    elseif session.head_buf and vim.api.nvim_buf_is_valid(session.head_buf) then
      pcall(vim.api.nvim_buf_delete, session.head_buf, { force = true })
    end
  end

  if session.base_win and vim.api.nvim_win_is_valid(session.base_win) then
    pcall(vim.api.nvim_set_current_win, session.base_win)
  end
end

local function diff_against_head()
  local buf = vim.api.nvim_get_current_buf()

  if diff_session then
    local request_win = vim.api.nvim_get_current_win()
    local same_buf = buf == diff_session.base_buf or buf == diff_session.head_buf
    cleanup_diff_session(true)
    if same_buf then return end
    if request_win and vim.api.nvim_win_is_valid(request_win) then
      pcall(vim.api.nvim_set_current_win, request_win)
    end
    buf = vim.api.nvim_get_current_buf()
  end

  if not is_regular_buffer(buf) then
    vim.notify('No file to diff', vim.log.levels.WARN)
    return
  end

  local info = get_git_info(buf)
  if not info then
    vim.notify('Not a git file', vim.log.levels.WARN)
    return
  end

  local abs = info.abs

  -- Get HEAD version
  local stdout = ''
  if info.tracked then
    local obj = vim.system(
      { 'git', 'show', 'HEAD:' .. info.relpath },
      { cwd = info.root, text = true }
    ):wait()

    if obj.code == 0 then
      stdout = obj.stdout
    else
      vim.notify('No HEAD version found, diffing against empty file', vim.log.levels.INFO)
    end
  else
    vim.notify('Untracked file: diffing against empty file', vim.log.levels.INFO)
  end

  -- Set diffopt to ignore whitespace
  local saved_diffopt = vim.o.diffopt
  if not saved_diffopt:match('iwhiteall') then
    vim.o.diffopt = saved_diffopt .. ',iwhiteall'
  end

  -- Remember current window
  local cur_win = vim.api.nvim_get_current_win()
  local ft = vim.bo[buf].filetype

  -- Create vertical split on the LEFT with HEAD content
  vim.cmd('aboveleft vnew')
  local head_win = vim.api.nvim_get_current_win()
  local head_buf = vim.api.nvim_get_current_buf()
  local lines = vim.split(stdout, '\n', { plain = true })
  -- Remove trailing empty line from git show
  if #lines > 0 and lines[#lines] == '' then
    table.remove(lines)
  end
  vim.api.nvim_buf_set_lines(head_buf, 0, -1, false, lines)

  vim.bo[head_buf].buftype = 'nofile'
  vim.bo[head_buf].bufhidden = 'wipe'
  vim.bo[head_buf].swapfile = false
  vim.bo[head_buf].modifiable = false
  vim.bo[head_buf].filetype = ft
  vim.api.nvim_buf_set_name(head_buf, 'HEAD: ' .. vim.fn.fnamemodify(abs, ':t'))

  diff_session = {
    saved_diffopt = saved_diffopt,
    base_buf = buf,
    head_buf = head_buf,
    head_win = head_win,
    base_win = cur_win,
  }

  -- Enable diff in both windows
  vim.cmd('diffthis')
  vim.api.nvim_set_current_win(cur_win)
  vim.cmd('diffthis')

  -- Restore diffopt when diff buffer is closed
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = head_buf,
    once = true,
    callback = function()
      cleanup_diff_session(false)
    end,
  })

  -- q closes the diff view
  vim.keymap.set('n', 'q', function()
    cleanup_diff_session(true)
  end, { buffer = head_buf, nowait = true, desc = 'Close diff' })
end

-- ═════════════════════════════════════════════════════════════════════
--  (2b) DIFFTOOL vs HEAD  (<leader>D — nvim.difftool builtin 0.12)
-- ═════════════════════════════════════════════════════════════════════

local difftool_loaded = false

local function cleanup_diff_temp()
  if diff_tempfile then
    vim.fn.delete(diff_tempfile)
    diff_tempfile = nil
  end
end

local function difftool_against_head()
  local buf = vim.api.nvim_get_current_buf()

  if not is_regular_buffer(buf) then
    vim.notify('No file to diff', vim.log.levels.WARN)
    return
  end

  local info = get_git_info(buf)
  if not info then
    vim.notify('Not a git file', vim.log.levels.WARN)
    return
  end

  if not confirm_write_if_modified(buf, 'opening difftool') then return end

  -- Get HEAD version
  local head_content = ''
  if info.tracked then
    local obj = vim.system(
      { 'git', 'show', 'HEAD:' .. info.relpath },
      { cwd = info.root, text = true }
    ):wait()
    if obj.code == 0 then
      head_content = obj.stdout
    else
      vim.notify('No HEAD version — diffing against empty', vim.log.levels.INFO)
    end
  else
    vim.notify('Untracked file — diffing against empty', vim.log.levels.INFO)
  end

  -- Write HEAD content to a temp file (same extension for syntax)
  cleanup_diff_temp()
  local ext = vim.fn.fnamemodify(info.abs, ':e')
  diff_tempfile = vim.fn.tempname() .. '_HEAD.' .. ext
  local f = io.open(diff_tempfile, 'w')
  if f then
    f:write(head_content)
    f:close()
  end

  -- Load builtin difftool once
  if not difftool_loaded then
    vim.cmd.packadd('nvim.difftool')
    difftool_loaded = true
  end

  require('difftool').open(diff_tempfile, info.abs)
end

-- ═════════════════════════════════════════════════════════════════════
--  (3) GIT WORKFLOW — status / stage / commit / push / log
-- ═════════════════════════════════════════════════════════════════════

local function git_status()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  local cwd = info and info.root or vim.fn.getcwd()

  vim.system({ 'git', 'status', '-sb' }, { cwd = cwd, text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        vim.notify('Not a git repo', vim.log.levels.WARN)
        return
      end
      -- Scratch float
      local lines = vim.split(vim.trim(obj.stdout), '\n', { plain = true })
      local sbuf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, lines)
      vim.bo[sbuf].buftype = 'nofile'
      vim.bo[sbuf].bufhidden = 'wipe'
      vim.bo[sbuf].modifiable = false
      local w = math.min(math.floor(vim.o.columns * 0.6), 80)
      local h = math.min(#lines + 1, math.floor(vim.o.lines * 0.6))
      local win = vim.api.nvim_open_win(sbuf, true, {
        relative = 'editor',
        width = w, height = h,
        col = math.floor((vim.o.columns - w) / 2),
        row = math.floor((vim.o.lines - h) / 2),
        style = 'minimal',
        border = 'single',
        title = ' git status ',
        title_pos = 'center',
      })
      vim.keymap.set('n', 'q', function()
        pcall(vim.api.nvim_win_close, win, true)
      end, { buffer = sbuf, nowait = true })
      vim.keymap.set('n', '<Esc>', function()
        pcall(vim.api.nvim_win_close, win, true)
      end, { buffer = sbuf, nowait = true })
    end)
  end)
end

local function git_stage_file()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  if not info then vim.notify('Not a git file', vim.log.levels.WARN); return end
  if not confirm_write_if_modified(buf, 'staging this file') then return end

  vim.system({ 'git', 'add', '--', info.relpath }, { cwd = info.root }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        vim.notify('Staged: ' .. info.relpath, vim.log.levels.INFO)
      else
        vim.notify('Stage failed: ' .. (obj.stderr or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function git_stage_all()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  local cwd = info and info.root or vim.fn.getcwd()

  vim.system({ 'git', 'add', '-A' }, { cwd = cwd }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        vim.notify('Staged all changes', vim.log.levels.INFO)
      else
        vim.notify('Stage all failed: ' .. (obj.stderr or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function git_commit()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  local cwd = info and info.root or vim.fn.getcwd()

  local msg = vim.fn.input('Commit message: ')
  if msg == '' then vim.notify('Commit aborted', vim.log.levels.INFO); return end

  vim.system({ 'git', 'commit', '-m', msg }, { cwd = cwd, text = true }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local summary = vim.trim(obj.stdout):match('[^\n]+') or 'done'
        vim.notify('Committed: ' .. summary, vim.log.levels.INFO)
      else
        vim.notify('Commit failed: ' .. vim.trim(obj.stderr or obj.stdout or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function git_push()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  local cwd = info and info.root or vim.fn.getcwd()

  vim.notify('Pushing...', vim.log.levels.INFO)
  vim.system({ 'git', 'push' }, { cwd = cwd, text = true }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        vim.notify('Pushed successfully', vim.log.levels.INFO)
      else
        vim.notify('Push failed: ' .. vim.trim(obj.stderr or obj.stdout or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function git_log_file()
  local buf = vim.api.nvim_get_current_buf()
  local info = get_git_info(buf)
  if not info or not info.tracked then
    vim.notify('Not a tracked git file', vim.log.levels.WARN)
    return
  end

  local obj = vim.system(
    { 'git', 'log', '--oneline', '-30', '--', info.relpath },
    { cwd = info.root, text = true }
  ):wait()

  if obj.code ~= 0 or obj.stdout == '' then
    vim.notify('No git log available', vim.log.levels.INFO)
    return
  end

  local lines = vim.split(vim.trim(obj.stdout), '\n', { plain = true })
  local sbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, lines)
  vim.bo[sbuf].buftype = 'nofile'
  vim.bo[sbuf].bufhidden = 'wipe'
  vim.bo[sbuf].modifiable = false
  local w = math.min(math.floor(vim.o.columns * 0.8), 100)
  local h = math.min(#lines + 1, math.floor(vim.o.lines * 0.7))
  local win = vim.api.nvim_open_win(sbuf, true, {
    relative = 'editor',
    width = w, height = h,
    col = math.floor((vim.o.columns - w) / 2),
    row = math.floor((vim.o.lines - h) / 2),
    style = 'minimal',
    border = 'single',
    title = ' git log: ' .. info.relpath .. ' ',
    title_pos = 'center',
  })
  vim.keymap.set('n', 'q', function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = sbuf, nowait = true })
  vim.keymap.set('n', '<Esc>', function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = sbuf, nowait = true })
end

-- ═════════════════════════════════════════════════════════════════════
--  SETUP — autocmds + keymaps
-- ═════════════════════════════════════════════════════════════════════

function M.setup()
  local augroup = vim.api.nvim_create_augroup('GitBlame', { clear = true })

  pcall(vim.api.nvim_del_user_command, 'BlameToggle')

  -- Show blame on CursorHold only (no process spawns during active editing)
  vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold' }, {
    group = augroup,
    callback = function(ev)
      schedule_blame(ev.buf, vim.api.nvim_win_get_cursor(0)[1])
    end,
  })

  -- Clear blame on InsertEnter / BufLeave / WinLeave only (NOT CursorMoved)
  -- CursorHold naturally replaces stale blame — no need to clear on every motion
  vim.api.nvim_create_autocmd({ 'InsertEnter', 'BufLeave', 'WinLeave' }, {
    group = augroup,
    callback = function(ev)
      stop_blame_timer()
      clear_blame(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = augroup,
    callback = function(ev)
      if path_cache[ev.buf] then
        path_cache[ev.buf] = nil
        path_cache_count = path_cache_count - 1
      end
      if last_blame.buf == ev.buf then
        reset_last_blame()
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufFilePost', {
    group = augroup,
    callback = function(ev)
      if path_cache[ev.buf] then
        path_cache[ev.buf] = nil
        path_cache_count = path_cache_count - 1
      end
    end,
  })

  -- Toggle blame on/off
  vim.api.nvim_create_user_command('BlameToggle', function()
    blame_enabled = not blame_enabled
    if blame_enabled then
      local buf = vim.api.nvim_get_current_buf()
      schedule_blame(buf, vim.api.nvim_win_get_cursor(0)[1])
      _G._toggle_msg('Git blame: ON')
    else
      stop_blame_timer()
      clear_blame(vim.api.nvim_get_current_buf())
      _G._toggle_msg('Git blame: OFF')
    end
  end, { desc = 'Toggle inline git blame' })

  -- ── Keymaps ─────────────────────────────────────────────────────
  -- Alt+d = fast in-memory diff vs HEAD (zero disk I/O)
  vim.keymap.set('n', '<A-d>', diff_against_head, { desc = 'Diff file vs HEAD (iwhite)' })

  -- <leader>D = nvim.difftool diff vs HEAD (builtin 0.12)
  vim.keymap.set('n', '<leader>D', difftool_against_head, { desc = 'Difftool file vs HEAD' })

  -- <leader>tb to toggle blame
  vim.keymap.set('n', '<leader>tb', '<Cmd>BlameToggle<CR>', { desc = 'Toggle git blame' })

  -- ── Git workflow (<leader>G namespace) ──────────────────────────
  vim.keymap.set('n', '<leader>Gs', git_status,     { desc = 'Git status' })
  vim.keymap.set('n', '<leader>Ga', git_stage_file,  { desc = 'Git add (current file)' })
  vim.keymap.set('n', '<leader>GA', git_stage_all,   { desc = 'Git add -A (all)' })
  vim.keymap.set('n', '<leader>Gc', git_commit,      { desc = 'Git commit' })
  vim.keymap.set('n', '<leader>Gp', git_push,        { desc = 'Git push' })
  vim.keymap.set('n', '<leader>Gl', git_log_file,    { desc = 'Git log (file)' })

  -- Clean up temp files on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = cleanup_diff_temp,
  })
end

return M