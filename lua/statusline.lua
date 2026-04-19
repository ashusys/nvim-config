-- ═════════════════════════════════════════════════════════════════════
--  Statusline — pure Lua, minimal for focus
--  mode │ file │ diag ═ search │ recording │ git │ pos
--  All expensive values are cached via events, not computed per-redraw
-- ═════════════════════════════════════════════════════════════════════

-- Git branch + diff: zero-cost reads from gitsigns' buffer variables
-- vim.b.gitsigns_head = branch, vim.b.gitsigns_status_dict = {added, changed, removed}
-- No shell processes, no caching needed — gitsigns maintains these automatically

-- Diagnostic counts (cached — only refreshed on DiagnosticChanged)
local _diag_cache = ''
local function refresh_diag()
  local counts = vim.diagnostic.count(0)
  if not counts then _diag_cache = ''; return end
  local e = counts[vim.diagnostic.severity.ERROR] or 0
  local w = counts[vim.diagnostic.severity.WARN] or 0
  local i = counts[vim.diagnostic.severity.INFO] or 0
  local h = counts[vim.diagnostic.severity.HINT] or 0
  local parts = {}
  if e > 0 then parts[#parts + 1] = 'E' .. e end
  if w > 0 then parts[#parts + 1] = 'W' .. w end
  if i > 0 then parts[#parts + 1] = 'I' .. i end
  if h > 0 then parts[#parts + 1] = 'H' .. h end
  _diag_cache = #parts > 0 and ('%#statusline_diagnostics# ' .. table.concat(parts, ' ') .. ' ') or ''
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  group = vim.api.nvim_create_augroup('StatusDiag', { clear = true }),
  callback = refresh_diag,
})

-- Buffer count + position (cached)
-- _buf_count is maintained by BufAdd/BufDelete events (never calls getbufinfo).
-- _buf_idx is recalculated on BufEnter using the lighter nvim_list_bufs() API.
local _buf_count = 0
local _buf_idx = 0

local function recount_listed()
  local n = 0
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then n = n + 1 end
  end
  _buf_count = n
end

local function refresh_buf_idx()
  local cur = vim.api.nvim_get_current_buf()
  local idx = 0
  local pos = 0
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then
      pos = pos + 1
      if b == cur then idx = pos; break end
    end
  end
  _buf_idx = idx
end

vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout' }, {
  group = vim.api.nvim_create_augroup('StatusBufCount', { clear = true }),
  -- Defer one tick so the buffer's listed state is settled before we count
  callback = function() vim.schedule(recount_listed) end,
})
vim.schedule(recount_listed)

-- File path (cached — pure Lua, no vimscript round-trip per redraw)
local _fname_cache = '[no name]'
local _fname_modified = false
local function refresh_fname()
  local buf = vim.api.nvim_get_current_buf()
  _fname_modified = vim.bo[buf].modified
  if vim.bo[buf].buftype == 'terminal' then
    _fname_cache = 'terminal'
    return
  end
  local abs = vim.api.nvim_buf_get_name(buf)
  if abs == '' then _fname_cache = '[no name]'; return end
  local dict = vim.b[buf].gitsigns_status_dict
  local root = dict and dict.root or ''
  if root ~= '' and abs:sub(1, #root + 1) == root .. '/' then
    _fname_cache = abs:sub(#root + 2)
  else
    _fname_cache = vim.fn.fnamemodify(abs, ':t')
  end
end

vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'DirChanged' }, {
  group = vim.api.nvim_create_augroup('StatusFname', { clear = true }),
  callback = function() vim.schedule(refresh_fname) end,
})
vim.schedule(refresh_fname)

-- Consolidated BufEnter: refresh all statusline caches in a single handler
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('StatusBufEnter', { clear = true }),
  callback = function()
    vim.schedule(function()
      refresh_diag()
      refresh_buf_idx()
      refresh_fname()
    end)
  end,
})

-- Search count (cached — deduplicated by pattern + cursor position)
local _search_cache = ''
local _last_search_pat = ''
local _last_search_pos = 0
local function refresh_search()
  if vim.v.hlsearch == 1 then
    local pat = vim.fn.getreg('/')
    local pos = vim.fn.line('.')
    if pat == _last_search_pat and pos == _last_search_pos and _search_cache ~= '' then return end
    _last_search_pat = pat
    _last_search_pos = pos
    local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 5 })
    if ok and sc.total and sc.total > 0 then
      _search_cache = '%#statusline_misc# [' .. sc.current .. '/' .. sc.total .. '] '
      return
    end
  end
  _search_cache = ''
  _last_search_pat = ''
  _last_search_pos = 0
end
vim.api.nvim_create_autocmd({ 'CmdlineLeave', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('StatusSearch', { clear = true }),
  callback = refresh_search,
})

-- Recording macro (cached — only changes on RecordingEnter/Leave)
local _recording_cache = ''
local _recording_group = vim.api.nvim_create_augroup('StatusRecording', { clear = true })
vim.api.nvim_create_autocmd('RecordingEnter', {
  group = _recording_group,
  callback = function()
    _recording_cache = '%#statusline_misc# recording @' .. vim.fn.reg_recording() .. ' '
  end,
})
vim.api.nvim_create_autocmd('RecordingLeave', {
  group = _recording_group,
  callback = function() _recording_cache = '' end,
})

local modes = {
  n = 'N', i = 'I', v = 'V', V = 'V', ['\22'] = 'V',
  c = 'C', R = 'R', t = 'T', s = 'S', S = 'S', ['!'] = '!',
}

-- Pre-allocated format string — zero table allocation per redraw
function _G._statusline()
  local m = vim.api.nvim_get_mode().mode:sub(1, 1)
  local mode = modes[m] or m:upper()

  local file_hl = _fname_modified and 'statusline_modifiedfile' or 'statusline_file'

  local bufs = ''
  if _buf_count > 1 and _buf_idx > 0 then
    bufs = '%#statusline_misc# [' .. _buf_idx .. '/' .. _buf_count .. '] '
  end

  local branch = vim.b.gitsigns_head or ''
  local git = ''
  if branch ~= '' then
    local dict = vim.b.gitsigns_status_dict
    local diff = ''
    if dict then
      local a, r, c = dict.added or 0, dict.removed or 0, dict.changed or 0
      if a > 0 or r > 0 or c > 0 then
        diff = ' '
          .. (a > 0 and ('+' .. a .. ' ') or '')
          .. (r > 0 and ('-' .. r .. ' ') or '')
          .. (c > 0 and ('~' .. c) or '')
      end
    end
    git = '%#statusline_branch# ' .. branch .. diff .. ' '
  end

  return '%#' .. file_hl .. '# ' .. _fname_cache .. ' '
    .. bufs
    .. _diag_cache
    .. '%#statusline_separator#%='
    .. _search_cache
    .. _recording_cache
    .. git
    .. '%#statusline_mode# ' .. mode .. ' %l:%c %p%% '
end

vim.o.statusline = '%!v:lua._statusline()'
