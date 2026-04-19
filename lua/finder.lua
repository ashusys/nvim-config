-- ═════════════════════════════════════════════════════════════════════
--  Finder — fzf specialist pickers (git diff, arglist, buffer grep)
--  Consumes .editorignore via fd --ignore-file
--  General file/grep: fff.nvim (sl/sk/go/ga).  This module: \fd \fw \fa \gb \gq
-- ═════════════════════════════════════════════════════════════════════

local cfg = require('config')
local HOME = cfg.home
local CONFIG = vim.fn.stdpath('config')
local EDITORIGNORE = CONFIG .. '/.editorignore'
local CACHE_DIR = HOME .. '/.cache/nvim'
local CACHE_FILE = CACHE_DIR .. '/codebase_files.txt'
local PROJECT_ROOT = cfg.project_root and vim.fn.expand(cfg.project_root) or nil
local CACHE_TTL = cfg.cache_ttl

vim.fn.mkdir(CACHE_DIR, 'p')

-- ── fd command (respects editorignore, stays on one filesystem) ─────
local fd_cmd = table.concat({
  'fd', '--type f', '--hidden', '--no-require-git',
  '--threads=' .. cfg.fd_threads, '--one-file-system',
  '--ignore-file', EDITORIGNORE,
}, ' ')

local rg_cmd = table.concat({
  'rg', '--vimgrep', '--ignore-case', '--fixed-strings',
  '--threads=' .. cfg.rg_threads, '--mmap',
  '--max-columns=2000', '--max-columns-preview',
  '--ignore-file', EDITORIGNORE,
}, ' ')

local preview_cmd = [[sh -c 'if [ -z {2q} ]; then head -80 {1q}; else s=$(( {2} > 10 ? {2} - 10 : 1 )); e=$(( {2} + 10 )); sed -n "${s},${e}p" {1q}; fi']]

local fzf_cmd = table.concat({
  'fzf',
  '--delimiter=:',
  '--multi',
  '--layout=reverse',
  '--header-first',
  "--bind 'ctrl-a:toggle-all'",
  '--bind=ctrl-t:toggle-preview',
  '--preview-window=hidden',
  '--preview=' .. vim.fn.shellescape(preview_cmd),
  '--algo=v2',
  '--no-sort',
}, ' ')

-- ═════════════════════════════════════════════════════════════════════
--  Precached file index (async, non-blocking, TTL-validated)
-- ═════════════════════════════════════════════════════════════════════

local cache_building = false
local cache_build_started_at = 0

local function cache_file_count_sync()
  local result = vim.system({ 'wc', '-l', CACHE_FILE }, { text = true }):wait()
  if result.code ~= 0 then return '0' end
  return vim.trim((result.stdout or ''):match('^%s*(%d+)') or '0')
end

local _has_ionice = vim.fn.executable('ionice') == 1

local function build_cache_command(root)
  local base = fd_cmd
    .. ' . '
    .. vim.fn.shellescape(root)
    .. ' > '
    .. vim.fn.shellescape(CACHE_FILE)
    .. ' 2>/dev/null'
  if vim.g.cache_high_priority then
    return (_has_ionice and 'ionice -c2 -n0 ' or '') .. base
  end
  return 'nice -n 19' .. (_has_ionice and ' ionice -c 3' or '') .. ' ' .. base
end

local function is_cache_valid()
  if vim.fn.filereadable(CACHE_FILE) == 0 then return false end
  return (os.time() - vim.fn.getftime(CACHE_FILE)) < CACHE_TTL
end

local function rebuild_cache(force)
  if cache_building and cache_build_started_at > 0 and (vim.uv.now() - cache_build_started_at) > 120000 then
    cache_building = false
    cache_build_started_at = 0
  end
  if cache_building then return end
  if not PROJECT_ROOT or vim.fn.isdirectory(PROJECT_ROOT) == 0 then
    if force then
      vim.notify('Cache root missing: ' .. tostring(PROJECT_ROOT), vim.log.levels.WARN)
    end
    return
  end
  if not force and is_cache_valid() then return end
  cache_building = true
  cache_build_started_at = vim.uv.now()
  local job_id = vim.fn.jobstart(build_cache_command(PROJECT_ROOT), {
    detach = true,
    on_exit = function(_, code)
      cache_building = false
      cache_build_started_at = 0
      if code == 0 then
        vim.system({ 'wc', '-l', CACHE_FILE }, { text = true }, function(wc)
          vim.schedule(function()
            local count = vim.trim((wc.stdout or ''):match('^%s*(%d+)') or '0')
            vim.notify(string.format('Cache ready: %s files (%ds TTL)', count, CACHE_TTL), vim.log.levels.INFO)
          end)
        end)
      else
        vim.schedule(function()
          vim.notify('Cache rebuild failed (exit ' .. tostring(code) .. ')', vim.log.levels.WARN)
        end)
      end
    end,
  })
  if job_id <= 0 then
    cache_building = false
    cache_build_started_at = 0
    vim.notify('Cache rebuild failed to start', vim.log.levels.ERROR)
  end
end

-- Build on load if stale (48h TTL means this almost always skips)
rebuild_cache()

-- Invalidate cache when oil performs file CRUD (create/rename/delete)
vim.api.nvim_create_autocmd('User', {
  pattern = 'OilMutationComplete',
  group = vim.api.nvim_create_augroup('FinderCacheInvalidate', { clear = true }),
  callback = function()
    cache_building = false
    rebuild_cache(true)
    vim.notify('File cache rebuilding (oil mutation)', vim.log.levels.INFO)
  end,
})

-- ── Cache commands ──────────────────────────────────────────────────

vim.api.nvim_create_user_command('CacheRebuild', function()
  cache_building = false  -- force
  rebuild_cache(true)
end, { desc = 'Force rebuild file cache' })

vim.api.nvim_create_user_command('CacheStatus', function()
  local info = { 'Cache: ' .. CACHE_FILE }
  if vim.fn.filereadable(CACHE_FILE) == 1 then
    local age = os.time() - vim.fn.getftime(CACHE_FILE)
    info[#info + 1] = string.format('Age: %ds / %ds TTL  |  Valid: %s', age, CACHE_TTL, is_cache_valid() and 'YES' or 'NO')
    info[#info + 1] = 'Files: ' .. cache_file_count_sync()
  else
    info[#info + 1] = 'Not built yet'
  end
  print(table.concat(info, '\n'))
end, { desc = 'Show cache status' })

-- ═════════════════════════════════════════════════════════════════════
--  UI primitives
-- ═════════════════════════════════════════════════════════════════════

local function float_win(buf)
  buf = (buf and vim.api.nvim_buf_is_valid(buf)) and buf or vim.api.nvim_create_buf(false, true)
  local w = math.floor(vim.o.columns * 0.8)
  local h = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = w, height = h,
    col = math.floor((vim.o.columns - w) / 2),
    row = math.floor((vim.o.lines - h) / 2),
    style = 'minimal',
    border = 'single',
  })
  return { buf = buf, win = win }
end

local function fzf_pick(input_cmd, header, callback, opts)
  opts = opts or {}
  local tmp = vim.fn.tempname()
  local f = float_win()
  local cmd
  local escaped_header = vim.fn.shellescape(header)
  if opts.live_reload then
    local bind = string.format(" --bind 'change:reload(%s)' --ansi ", opts.live_reload)
    cmd = fzf_cmd .. ' --header=' .. escaped_header .. ' ' .. bind .. ' > ' .. tmp
  elseif opts.from_string then
    -- Use 'printf' with a literal format string to prevent %xx in filenames
    -- being interpreted as format specifiers.
    cmd = "printf '%s' " .. vim.fn.shellescape(input_cmd) .. ' | ' .. fzf_cmd .. ' --header=' .. escaped_header .. ' > ' .. tmp
  else
    cmd = input_cmd .. ' | ' .. fzf_cmd .. ' --header=' .. escaped_header .. ' > ' .. tmp
  end

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function(_, code)
      pcall(vim.api.nvim_win_close, f.win, true)
      for _, file in ipairs(opts.cleanup_files or {}) do
        pcall(vim.fn.delete, file)
      end
      if code ~= 0 then vim.fn.delete(tmp); return end
      local results = vim.fn.readfile(tmp)
      vim.fn.delete(tmp)
      if #results > 0 then vim.schedule(function() callback(results) end) end
    end,
  })
  vim.cmd('startinsert')
end

-- ═════════════════════════════════════════════════════════════════════
--  Result handlers
-- ═════════════════════════════════════════════════════════════════════

local function handle_files(names, prefix)
  if prefix then
    for i, n in ipairs(names) do names[i] = prefix .. n end
  end
  if #names == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(names[1]))
  else
    if vim.fn.argc() > 0 then vim.cmd('argdelete *') end
    for _, n in ipairs(names) do vim.cmd('argadd ' .. vim.fn.fnameescape(n)) end
  end
end

local function handle_grep(output)
  local qf = {}
  for _, line in ipairs(output) do
    local file, row, col, text = line:match('^(.-):(%d+):(%d+):(.*)$')
    if file then
      qf[#qf + 1] = { filename = file, lnum = tonumber(row), col = tonumber(col), text = text }
    end
  end
  vim.fn.setqflist({}, ' ', { title = 'Grep Results', items = qf })
  if #qf == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(qf[1].filename))
    vim.api.nvim_win_set_cursor(0, { qf[1].lnum, qf[1].col - 1 })
  else
    vim.cmd('copen')
  end
end

local function handle_buffer_lines(results)
  local current = vim.fn.expand('%:p')
  if #results == 1 then
    local ln = results[1]:match('^%s*(%d+)')
    if ln then vim.api.nvim_win_set_cursor(0, { tonumber(ln), 0 }) end
  else
    local qf = {}
    for _, line in ipairs(results) do
      local ln, text = line:match('^%s*(%d+)%s*(.*)$')
      if ln then qf[#qf + 1] = { filename = current, lnum = tonumber(ln), col = 1, text = text } end
    end
    vim.fn.setqflist({}, ' ', { title = 'Buffer Lines', items = qf })
    vim.cmd('copen')
  end
end

-- ═════════════════════════════════════════════════════════════════════
--  Finders
-- ═════════════════════════════════════════════════════════════════════

local function find_file()
  local cwd = vim.fn.getcwd()
  local use_cache = PROJECT_ROOT and cwd:find(PROJECT_ROOT, 1, true) and vim.fn.filereadable(CACHE_FILE) == 1 and is_cache_valid()
  local input_cmd, header

  if use_cache then
    local age = os.time() - vim.fn.getftime(CACHE_FILE)
    input_cmd = 'cat ' .. CACHE_FILE
    header = string.format('Find File [CACHED %ds/%ds]', age, CACHE_TTL)
  else
    input_cmd = fd_cmd
    header = string.format('Find File [LIVE %dt]', cfg.fd_threads)
  end

  fzf_pick(input_cmd, header, handle_files)
end

local function find_buffer()
  local bufs = {}
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.name ~= '' and not b.name:match('term:') then
      bufs[#bufs + 1] = vim.fn.fnamemodify(b.name, ':~:.')
    end
  end
  if #bufs == 0 then return end
  fzf_pick(table.concat(bufs, '\n'), 'Buffers', handle_files, { from_string = true })
end

local function find_gitdiff()
  local against = vim.fn.input('Compare against: ')
  if against == '' then return end
  local git_dir = vim.fs.find('.git', { upward = true })[1]
  if not git_dir then return vim.notify('Not a git repo', vim.log.levels.WARN) end
  local prefix = vim.fs.dirname(git_dir) .. '/'
  local git_cmd = 'git diff --name-only ' .. vim.fn.shellescape(against) .. '...HEAD'
  fzf_pick(git_cmd, 'Git Diff', function(names) handle_files(names, prefix) end)
end

local function find_git_working()
  local git_dir = vim.fs.find('.git', { upward = true })[1]
  if not git_dir then return vim.notify('Not a git repo', vim.log.levels.WARN) end
  local prefix = vim.fs.dirname(git_dir) .. '/'
  fzf_pick('git diff --name-only HEAD', 'Staged & Unstaged', function(names) handle_files(names, prefix) end)
end

-- ═════════════════════════════════════════════════════════════════════
--  Grep
-- ═════════════════════════════════════════════════════════════════════

local function live_grep()
  fzf_pick('', 'Live Grep', handle_grep, { live_reload = rg_cmd .. ' {q} -- || true' })
end

-- Regex grep variant (no --fixed-strings)
local rg_regex_cmd = rg_cmd:gsub(' %-%-fixed%-strings', '')
local function live_grep_regex()
  fzf_pick('', 'Live Grep [REGEX]', handle_grep, { live_reload = rg_regex_cmd .. ' {q} -- || true' })
end

local function live_args_grep()
  local args = vim.fn.argv()
  if #args == 0 then return end
  local escaped = {}
  for i, arg in ipairs(args) do
    escaped[i] = vim.fn.shellescape(arg)
  end
  local files = table.concat(escaped, ' ')
  fzf_pick('', 'Grep Arglist', handle_grep, { live_reload = rg_cmd .. ' {q} ' .. files .. ' -- || true' })
end

local function live_buffer_grep()
  local f = vim.fn.expand('%:p')
  if f == '' then return end
  fzf_pick(
    'cat -n ' .. vim.fn.shellescape(f),
    'Buffer Lines',
    handle_buffer_lines
  )
end

-- ═════════════════════════════════════════════════════════════════════
--  Refine
-- ═════════════════════════════════════════════════════════════════════

local function refine_arglist()
  local args = vim.fn.argv()
  if #args == 0 then return end
  fzf_pick(table.concat(args, '\n'), 'Arglist', handle_files, { from_string = true })
end

local function refine_quickfix()
  local qf = vim.fn.getqflist()
  if #qf == 0 then return end
  local lines, map = {}, {}
  for i, e in ipairs(qf) do
    local l = string.format('%s:%d:%d:%s', vim.fn.bufname(e.bufnr), e.lnum, e.col, e.text)
    lines[#lines + 1] = l
    map[l] = i
  end
  fzf_pick(table.concat(lines, '\n'), 'Quickfix', function(sel)
    local filtered = {}
    for _, l in ipairs(sel) do
      if map[l] then filtered[#filtered + 1] = qf[map[l]] end
    end
    vim.fn.setqflist({}, ' ', { title = 'Refined', items = filtered })
    vim.cmd('copen')
  end)
end

-- ═════════════════════════════════════════════════════════════════════
--  Keymaps — namespaced, no prefix conflicts
--
--  <leader>f*  Find   (files, git, arglist, native, qf history)
--  <leader>g*  Grep   (project, buffer, arglist, native, quickfix)
--  <leader>bb  Buffer (fzf picker)
--
--  Fast g-prefix aliases (leader-free, 0ms added latency):
--  go = find files (fzf)    ga = live grep (project)
-- ═════════════════════════════════════════════════════════════════════

local map = vim.keymap.set

-- Find namespace (go/sl/\ff also set by fff.nvim — these serve as fallbacks).
-- No <leader>o — reserved for opencode.nvim (<leader>oa, <leader>os, …).
map('n', '<leader>ff', find_file,        { desc = 'Find files (fzf)' })
map('n', 'go',         find_file,        { desc = 'Find files (go open)' })
map('n', 'sl',         find_file,        { desc = 'sl: find files (s-locate)' })
map('n', '<leader>fd', find_gitdiff,     { desc = 'Find git diff' })
map('n', '<leader>fw', find_git_working, { desc = 'Find git working' })
map('n', '<leader>fa', refine_arglist,   { desc = 'Filter arglist' })
map('n', '<leader>fb', '<Cmd>ls<CR>:b<Space>', { desc = 'Find buffer (native)' })
map('n', '<leader>fn', ':find **/*',     { desc = 'Find native (:find)' })
map('n', '<leader>fl', function() pcall(vim.cmd, 'cnewer') end, { desc = 'Newer qf list' })
map('n', '<leader>fh', function() pcall(vim.cmd, 'colder') end, { desc = 'Older qf list' })

-- Grep namespace (ga/sk/\gg/\/ also set by fff.nvim — these serve as fallbacks)
map('n', '<leader>gg', live_grep,        { desc = 'Live grep (project)' })
map('n', 'ga',         live_grep,        { desc = 'Live grep (go all)' })
map('n', 'sk',         live_grep,        { desc = 'sk: live grep (s-seek)' })
map('n', '<leader>/',  live_grep,        { desc = 'Live grep' })
map('n', '<leader>ga', live_args_grep,   { desc = 'Grep arglist' })
map('n', '<leader>gG', live_grep_regex,  { desc = 'Live grep (regex)' })
map('n', '<leader>gb', live_buffer_grep, { desc = 'Grep buffer lines' })
map('n', '<leader>gq', refine_quickfix,  { desc = 'Refine quickfix' })
map('n', '<leader>gn',
  ":grep <C-r>=expand('<cword>')<CR> **/*<Left><Left><Left><Left><Left>",
  { desc = 'Grep word (native)' })

-- Buffer namespace
map('n', '<leader>bb', find_buffer,      { desc = 'Buffer picker (fzf)' })