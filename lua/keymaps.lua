local map = vim.keymap.set

vim.g.mapleader      = ' '
vim.g.maplocalleader = ' '

-- ═══════════════════════════════════════════════════════════════════
--  KEYMAP ARCHITECTURE v4 — leader = <Space>
--
--  Vim grammar is sacred. No built-in single-key command is overridden
--  with a multi-key combo (no `yx`, `dx`, `mx` style maps). Custom
--  maps only use characters that are ALREADY prefix keys in Vim:
--    g  [  ]  <leader>(\)  <C-*>  <S-*>  <A-*>
--
--  Two rules eliminate ALL timeout sluggishness:
--
--    1. If <leader>X has ANY <leader>XY, then <leader>X alone does
--       nothing — no standalone + extension conflict.
--
--    2. If <leader>X is instant (no sub-keys), verify no <leader>XY
--       exists ANYWHERE across all config files.
--
--  ┌──────────────────────────────────────────────────────────────┐
--  │ Namespaces (always have extensions, never standalone):       │
--  │   \f*  Find     files / git / native / qf lists              │
--  │   \g*  Grep     project / buffer / arglist / refine          │
--  │   \s*  Search   highlight / replace / quickfix ops           │
--  │   \b*  Buffer   fzf list / delete                            │
--  │   \c*  Code     action / rename / format / cd                │
--  │   \G*  Git      status / stage / commit / push / log         │
--  │   \h*  Hunk     stage / reset / preview / diff               │
--  │   \t*  Toggle   options / features                           │
--  │   \l*  LSP      refresh / stop                               │
--  │   \S*  Session  save / load / delete                         │
--  │                                                              │
--  │ Instant (single key after \, guaranteed no extensions):      │
--  │   \w \q \Q \j \J \1 \v \H \u \D \e \<leader>               │
--  │                                                              │
--  │ Fast access (g-prefix — Vim native, zero extra latency):     │
--  │   go = find files (fff)   ga = live grep (fff)               │
--  │   gz = revert buffer                                         │
--  │                                                              │
--  │ s-prefix (right-hand — plugins set these after load):        │
--  │   sd se sf sg = diffview   sh = diff HEAD   si = explorer    │
--  │   sk sl = fff grep/files   so = terminal    sq = quit win    │
--  │   sr ss = session          su sz = revert   sw = wrap 80     │
--  │   sx = diffview close      s1 = cycle wins                   │
--  │                                                              │
--  │ Vim-native conventions:                                      │
--  │   g*     go-to / LSP           []    sequential prev/next    │
--  │   <C-*>  system / muscle-mem    <S-*> shift combos           │
--  │   <A-d>  diff vs HEAD          -     oil parent dir          │
--  │   <A-o>  select parent node    <A-i> select child node       │
--  │   <A-=>  peek inlay hints                                    │
--  └──────────────────────────────────────────────────────────────┘
-- ═══════════════════════════════════════════════════════════════════

map({ 'n', 'v' }, '<Space>', '<Nop>', { desc = 'Space is leader only' })

-- ── Essentials ──────────────────────────────────────────────────────
map('n', 'x',     '"_x',        { desc = 'Delete char (void)' })
map('n', 'X',     '"_X',        { desc = 'Delete char back (void)' })
map('n', 'q',     '<Nop>',      { desc = 'Nop (qq = smart quit, Q = record macro)' })
map('n', 'Q',     'q',          { desc = 'Record macro' })
map('n', '<Esc>', '<Cmd>nohlsearch<CR>')

-- ── Clipboard (explicit — no unnamedplus overhead) ──────────────────
map({ 'n', 'v' }, '<leader>y', '"+y',  { desc = 'Yank to clipboard' })
map('n',          '<leader>Y', '"+Y',  { desc = 'Yank line to clipboard' })
map({ 'n', 'v' }, '<leader>p', '"+p',  { desc = 'Paste from clipboard' })
map({ 'n', 'v' }, '<leader>P', '"+P',  { desc = 'Paste before from clipboard' })

-- ── Incremental selection — see bottom of file ──────────────────────

-- Smart j/k — respect wrapped lines without breaking count jumps
map({ 'n', 'x' }, 'j', function()
  return vim.v.count > 0 and 'j' or 'gj'
end, { expr = true })
map({ 'n', 'x' }, 'k', function()
  return vim.v.count > 0 and 'k' or 'gk'
end, { expr = true })

-- ── Save / Quit (instant — no extensions) ───────────────────────────
map({ 'n', 'i' }, '<C-s>', '<Cmd>w<CR>',    { desc = 'Save' })
map('n', '<leader>w',  '<Cmd>w<CR>',        { desc = 'Save' })
map('n', '<leader>q', '<Cmd>q<CR>',         { desc = 'Quit window' })
map('n', 'qq', function()
  local win = vim.api.nvim_get_current_win()
  local bt = vim.bo.buftype
  local ft = vim.bo.filetype

  -- Oil sidebar: delegate to toggle_sidebar for clean state cleanup
  if ft == 'oil' then
    pcall(function()
      require('plugins.oil').toggle_sidebar()
    end)
    return
  end

  -- Floating windows (popups, terminals): just close them
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= '' then
    pcall(vim.api.nvim_win_close, win, true)
    return
  end

  -- Terminals, help, quickfix, special buffers: close window only
  if bt ~= '' or ft == 'help' or ft == 'qf' then
    vim.cmd('q!')
    return
  end

  -- Regular buffer: quit nvim (confirm if unsaved changes)
  vim.cmd('confirm qa')
end, { desc = 'Smart quit (close special, exit on editor)' })
map('n', '<leader>Q',  '<Cmd>qa!<CR>',      { desc = 'Force quit all' })

-- ── File explorer (oil.nvim — see plugins/oil.lua) ──────────────────
-- `-` opens oil in current dir, `\e` toggles sidebar

-- ── Revert buffer to last saved state on disk ───────────────────────
map('n', 'gz', '<Cmd>edit!<CR>', { desc = 'Revert buffer to disk (go zero)' })

-- ── Finder placeholders (before deferred load completes) ────────────
-- These are overwritten when finder.lua loads. If pressed early,
-- they lazy-load finder on demand so the user never gets raw keys.
local _finder_loading = false
local _finder_loaded = false
-- Only include keys that finder.lua actually overrides on load.
-- sb is set below to buffer_mru_picker (not finder). <leader>fb is native :ls.
for _, lhs in ipairs({
  'go', 'sl', '<leader>ff', '<leader>fd', '<leader>fw', '<leader>fa', '<leader>fn', '<leader>fl', '<leader>fh',
  'ga', 'sk', '<leader>/', '<leader>gg', '<leader>ga', '<leader>gb', '<leader>gq', '<leader>gn',
  '<leader>bb',
}) do
  map('n', lhs, function()
    if _finder_loaded then return end  -- finder loaded but didn't override this key
    if _finder_loading then
      vim.notify('Finder failed to load', vim.log.levels.ERROR)
      return
    end
    _finder_loading = true
    local ok, err = pcall(require, 'finder')
    _finder_loading = false
    if not ok then
      vim.notify('Finder error: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    _finder_loaded = true
    -- Re-trigger the keymap now that finder has overwritten it
    local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
  end, { desc = 'Loading finder...' })
end

-- ── s-prefix navigation — all second keys are right hand ────────────
map('n', 's', '<Nop>', { desc = 's prefix — find/grep/diff/session/term/explore/revert' })
map('n', 'sh', function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<A-d>', true, false, true), 'n', false)
end, { desc = 'sh: diff vs HEAD' })
map('n', 'si', function()
  local ok, oil = pcall(require, 'plugins.oil')
  if ok and oil.toggle_sidebar then oil.toggle_sidebar() end
end, { desc = 'si: explorer sidebar' })
map('n', 'so', function()
  local ok, term = pcall(require, 'terminal')
  if ok and term.toggle then term.toggle() end
end, { desc = 'so: open terminal' })
map('n', 'sq', '<Cmd>q<CR>',     { desc = 'sq: quit window' })
map('n', 'su', '<Cmd>edit!<CR>', { desc = 'su: revert to saved' })
map('n', 'sz', function()
  local file = vim.fn.expand('%:p')
  if file == '' then return vim.notify('No file', vim.log.levels.WARN) end
  local dir = vim.fn.fnamemodify(file, ':h')
  vim.system({ 'git', 'checkout', 'HEAD', '--', file }, { cwd = dir }, function(r)
    if r.code == 0 then
      vim.schedule(function()
        vim.cmd.edit({ bang = true })
        vim.notify('Reverted to HEAD')
      end)
    else
      vim.schedule(function() vim.notify('git checkout failed: ' .. (r.stderr or ''), vim.log.levels.ERROR) end)
    end
  end)
end, { desc = 'sz: revert file to last commit' })
-- sl, sk, and sb set by finder.lua after load

-- ── Windows (instant — no extensions) ───────────────────────────────
map('n', '<C-h>',     '<C-w>h')
map('n', '<C-j>',     '<C-w>j')
map('n', '<C-k>',     '<C-w>k')
map('n', '<C-l>',     '<C-w>l')
map('n', '<leader>1', '<C-w>w',             { desc = 'Cycle windows' })
map('n', 's1',        '<C-w>w',             { desc = 's1: cycle windows' })
map('n', '<leader>v', vim.cmd.vsplit,        { desc = 'Vertical split' })
map('n', '<leader>H', vim.cmd.split,         { desc = 'Horizontal split' })

-- Resize (arrows)
map('n', '<C-Up>',    '<Cmd>resize +2<CR>')
map('n', '<C-Down>',  '<Cmd>resize -2<CR>')
map('n', '<C-Right>', '<Cmd>vertical resize +2<CR>')
map('n', '<C-Left>',  '<Cmd>vertical resize -2<CR>')

-- ── Buffers ─────────────────────────────────────────────────────────
map('n', '<C-n>',     '<Cmd>bnext<CR>',      { desc = 'Next buffer' })
map('n', '<C-p>',     '<Cmd>bprevious<CR>',  { desc = 'Prev buffer' })
map('n', '<S-l>',     '<Cmd>bnext<CR>',      { desc = 'Next buffer' })
map('n', '<S-h>',     '<Cmd>bprevious<CR>',  { desc = 'Prev buffer' })

-- MRU buffer tracking (most-recently-used order, like Alt+Tab)
local mru_list = {}
local mru_set = {}  -- O(1) presence check
local mru_index = 0
-- Prevent BufEnter (fired when ]b/[b switches buffers) from reordering
-- the list mid-navigation, which would cause infinite oscillation.
local _mru_navigating = false

vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('MRUTracker', { clear = true }),
  callback = function(ev)
    local buf = ev.buf
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.bo[buf].buftype ~= '' then return end
    if vim.api.nvim_buf_get_name(buf) == '' then return end
    -- Skip reorder during ]b/[b navigation — preserve mru_index
    if _mru_navigating then return end
    -- Remove if already in list (O(1) check, O(n) remove only when present)
    if mru_set[buf] then
      for i = #mru_list, 1, -1 do
        if mru_list[i] == buf then table.remove(mru_list, i); break end
      end
    end
    table.insert(mru_list, 1, buf)
    mru_set[buf] = true
    mru_index = 0
    -- Cap at 50 entries, prune dead buffers
    if #mru_list > 60 then
      local pruned = {}
      mru_set = {}
      for _, b in ipairs(mru_list) do
        if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
          pruned[#pruned + 1] = b
          mru_set[b] = true
          if #pruned >= 50 then break end
        end
      end
      mru_list = pruned
    end
  end,
})

-- ]b / [b — cycle MRU (recency order, not buffer number)
local function mru_next()
  if #mru_list < 2 then return end
  for _ = 1, #mru_list - 1 do
    mru_index = (mru_index % #mru_list) + 1
    if mru_index == 1 then mru_index = 2 end
    local buf = mru_list[mru_index]
    if buf and vim.api.nvim_buf_is_valid(buf) and vim.fn.buflisted(buf) == 1 then
      _mru_navigating = true
      vim.api.nvim_set_current_buf(buf)
      _mru_navigating = false
      return
    end
  end
end

map('n', ']b',            mru_next, { desc = 'Next MRU buffer' })
map('n', '<leader><Tab>', mru_next, { desc = 'Next MRU buffer' })

map('n', '[b', function()
  if #mru_list < 2 then return end
  for _ = 1, #mru_list - 1 do
    mru_index = mru_index - 1
    if mru_index < 2 then mru_index = #mru_list end
    local buf = mru_list[mru_index]
    if buf and vim.api.nvim_buf_is_valid(buf) and vim.fn.buflisted(buf) == 1 then
      _mru_navigating = true
      vim.api.nvim_set_current_buf(buf)
      _mru_navigating = false
      return
    end
  end
end, { desc = 'Prev MRU buffer' })

local function buffer_mru_picker()
  local cur = vim.api.nvim_get_current_buf()
  local items = {}
  for _, b in ipairs(mru_list) do
    if b ~= cur and vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
      items[#items + 1] = b
    end
  end
  local in_list = {}
  for _, b in ipairs(items) do in_list[b] = true end
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= cur and not in_list[info.bufnr] and info.name ~= '' then
      items[#items + 1] = info.bufnr
    end
  end
  if #items == 0 then _G._toggle_msg('No other buffers'); return end
  local labels = {}
  for i, b in ipairs(items) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ':~:.')
    local mod = vim.bo[b].modified and ' [+]' or ''
    labels[i] = string.format('%d: %s%s', b, name, mod)
  end
  vim.ui.select(labels, { prompt = 'Switch buffer (MRU order):' }, function(_, idx)
    if idx then vim.api.nvim_set_current_buf(items[idx]) end
  end)
end

-- Window-safe buffer delete: never closes windows
local function buf_remove(buf, force)
  buf = buf or vim.api.nvim_get_current_buf()
  if not force and vim.bo[buf].modified then
    vim.notify('Buffer has unsaved changes (use force)', vim.log.levels.WARN)
    return
  end
  -- Find a replacement buffer (any other listed buffer, or create empty)
  local alt = nil
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.bufnr ~= buf then alt = b.bufnr; break end
  end
  -- Switch every window showing this buffer to the replacement
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      if alt then
        vim.api.nvim_win_set_buf(win, alt)
      else
        vim.api.nvim_win_call(win, function() vim.cmd('enew') end)
      end
    end
  end
  -- Now safe to wipe — no window references remain
  pcall(vim.api.nvim_buf_delete, buf, { force = force or false })
end

-- Buffer namespace — sb / <leader>bl = MRU picker; <leader>bb = fzf (finder)
map('n', '<leader>bl', buffer_mru_picker, { desc = 'Buffer list (MRU picker)' })
map('n', 'sb', buffer_mru_picker, { desc = 'sb: buffer list (MRU picker)' })

map('n', '<leader>bd', function() buf_remove() end, { desc = 'Delete buffer (window-safe)' })

map('n', '<leader>bD', function()
  local cur = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.bufnr ~= cur then buf_remove(b.bufnr, true) end
  end
end, { desc = 'Delete other buffers' })

-- ── Scrolling (centered) ───────────────────────────────────────────
map('n', '<C-d>',  '<C-d>zz')
map('n', '<C-u>',  '<C-u>zz')
map('n', 'n',      'nzzzv')
map('n', 'N',      'Nzzzv')
map('n', 'J', function()
  -- Join lines while keeping cursor column stable.
  -- Save/restore with nvim API instead of mark z to avoid clobbering user marks.
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal! J')
  vim.api.nvim_win_set_cursor(0, pos)
end, { desc = 'Join lines (cursor stays)' })

-- ── Go-to (g-prefix) ──────────────────────────────────────────────
map('n', 'gb', '<C-o>',  { desc = 'Go back (jumplist)' })

-- ── Code namespace (c) ─────────────────────────────────────────────
-- LSP actions live in lsp.lua: <leader>c{a,r,f,o,O}
map('n', '<leader>cd', function()
  local dir = vim.fn.expand('%:p:h')
  vim.cmd.lcd(dir)
  vim.notify('lcd → ' .. dir, vim.log.levels.INFO)
end, { desc = 'lcd to file dir' })

-- ── Search namespace (s) — highlight / replace / quickfix ops ──────
map('n', '<leader>sa', function()
  vim.fn.setreg('/', vim.fn.expand('<cword>'))
  vim.o.hlsearch = true
end, { desc = 'Highlight word under cursor' })

map('n', '<leader>sd', '<Cmd>call setqflist([], " ")<CR>',
  { desc = 'Clear quickfix' })

map('n', '<leader>sf', function()
  vim.fn.setqflist({
    { filename = vim.fn.expand('%'), lnum = vim.fn.line('.'),
      col = vim.fn.col('.'), text = vim.fn.getline('.') },
  }, 'a')
  vim.notify('Added to quickfix', vim.log.levels.INFO)
end, { desc = 'Feed line → quickfix' })

map('n', '<leader>sp',
  ':cdo s///gc<Left><Left><Left><Left>',
  { desc = 'Replace in quickfix' })

map('n', '<leader>sr',
  ':cfdo %s///gc | update<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>',
  { desc = 'Replace in qf files' })

map('n', '<leader>sq', function()
  vim.diagnostic.setqflist()
end, { desc = 'Diagnostics → quickfix' })

-- ── Quickfix / Loclist (instant + brackets) ─────────────────────────
map('n', '<leader>j', vim.cmd.copen,   { desc = 'Open quickfix' })
map('n', '<leader>J', vim.cmd.cclose,  { desc = 'Close quickfix' })

map('n', ']q', function()
  if not pcall(vim.cmd, 'cnext') then pcall(vim.cmd, 'cfirst') end
end, { desc = 'Next quickfix' })
map('n', '[q', function()
  if not pcall(vim.cmd, 'cprev') then pcall(vim.cmd, 'clast') end
end, { desc = 'Prev quickfix' })
map('n', ']Q', function() pcall(vim.cmd, 'cnewer') end,  { desc = 'Newer qf list' })
map('n', '[Q', function() pcall(vim.cmd, 'colder') end,  { desc = 'Older qf list' })
map('n', ']l', function()
  if not pcall(vim.cmd, 'lnext') then pcall(vim.cmd, 'lfirst') end
  pcall(vim.cmd, 'normal! zz')
end, { desc = 'Next loclist' })
map('n', '[l', function()
  if not pcall(vim.cmd, 'lprev') then pcall(vim.cmd, 'llast') end
  pcall(vim.cmd, 'normal! zz')
end, { desc = 'Prev loclist' })
map('n', ']a', function()
  if not pcall(vim.cmd, 'next') then pcall(vim.cmd, 'first') end
end, { desc = 'Next arg' })
map('n', '[a', function()
  if not pcall(vim.cmd, 'prev') then pcall(vim.cmd, 'last') end
end, { desc = 'Prev arg' })

-- ── Diagnostics (g-prefix) ──────────────────────────────────────────
-- ]d / [d are 0.12 built-in defaults (vim.diagnostic.jump)
map('n', 'gl', function() vim.diagnostic.open_float() end,  { desc = 'Diagnostic float' })
map('n', 'gK', function()
  local vl = vim.diagnostic.config().virtual_lines
  local will_enable = not vl
  vim.diagnostic.config({ virtual_lines = will_enable and { current_line = true } or false })
  _G._toggle_msg('diagnostic lines: ' .. (will_enable and 'ON' or 'OFF'))
end, { desc = 'Toggle diagnostic lines' })
map('n', 'gh', function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local diags = vim.diagnostic.get(0, { lnum = line - 1 })
  local msgs = {}
  for _, d in ipairs(diags) do msgs[#msgs + 1] = d.message end
  if #msgs > 0 then
    vim.fn.setreg('+', table.concat(msgs, '\n'))
    vim.notify('Diagnostic copied', vim.log.levels.INFO)
  else
    _G._toggle_msg('No diagnostics on line ' .. line)
  end
end, { desc = 'Copy diagnostic to clipboard' })

-- ── Toggles (<leader>t — toggle namespace) ──────────────────────────
map('n', '<leader>tf', '<Cmd>FormatToggle<CR>',  { desc = 'Toggle format on save' })
map('n', '<leader>ts', function()
  vim.o.laststatus = vim.o.laststatus == 0 and 3 or 0
  _G._toggle_msg('statusline: ' .. (vim.o.laststatus == 3 and 'ON' or 'OFF'))
end, { desc = 'Toggle statusline' })
map('n', '<leader>th', function()
  vim.o.hlsearch = not vim.o.hlsearch
  _G._toggle_msg('hlsearch: ' .. (vim.o.hlsearch and 'ON' or 'OFF'))
end, { desc = 'Toggle hlsearch' })
map('n', '<leader>tw', '<Cmd>WrapToggle<CR>', { desc = 'Toggle dynamic wrap' })
map('n', 'sw', function()
  local win = vim.api.nvim_get_current_win()
  local on = vim.bo.textwidth == 80 and vim.bo.formatoptions:find('t')
  if on then
    vim.bo.textwidth = 0
    vim.bo.formatoptions = vim.bo.formatoptions:gsub('t', '')
    vim.wo[win].wrap = false
    vim.wo[win].colorcolumn = ''
    _G._toggle_msg('hard wrap 80: OFF')
  else
    vim.bo.textwidth = 80
    if not vim.bo.formatoptions:find('t') then
      vim.bo.formatoptions = vim.bo.formatoptions .. 't'
    end
    vim.wo[win].wrap = true
    vim.wo[win].colorcolumn = '80'
    _G._toggle_msg('hard wrap 80: ON  (gq to reflow selection)')
  end
end, { desc = 'Toggle hard wrap 80' })
map('n', '<leader>tn', function()
  vim.o.number = not vim.o.number
  _G._toggle_msg('line numbers: ' .. (vim.o.number and 'ON' or 'OFF'))
end, { desc = 'Toggle line numbers' })
map('n', '<leader>tr', function()
  vim.o.relativenumber = not vim.o.relativenumber
  _G._toggle_msg('relative numbers: ' .. (vim.o.relativenumber and 'ON' or 'OFF'))
end, { desc = 'Toggle relative numbers' })
map('n', '<leader>ti', function()
  if vim.lsp.inlay_hint then
    local enabled = not vim.lsp.inlay_hint.is_enabled()
    vim.lsp.inlay_hint.enable(enabled)
    _G._toggle_msg('inlay hints: ' .. (enabled and 'ON' or 'OFF'))
  end
end, { desc = 'Toggle inlay hints' })

-- Inlay hints "offUnlessPressed" — peek hints until cursor moves (matches VS Code behavior)
map('n', '<A-=>', function()
  if not vim.lsp.inlay_hint then return end
  vim.lsp.inlay_hint.enable(true)
  local group = vim.api.nvim_create_augroup('InlayHintPeek', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter', 'BufLeave' }, {
    group = group,
    once = true,
    callback = function()
      vim.lsp.inlay_hint.enable(false)
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end, { desc = 'Peek inlay hints (off on cursor move)' })
map('n', '<leader>td', function()
  local vt = vim.diagnostic.config().virtual_text
  local new = not vt
  vim.diagnostic.config({ virtual_text = new })
  _G._toggle_msg('diagnostic text: ' .. (new and 'ON' or 'OFF'))
end, { desc = 'Toggle diagnostic text' })

-- ── Builtin plugins (Neovim 0.12 — lazy packadd, zero startup cost) ──
map('n', '<leader>u', function()
  vim.cmd.packadd('nvim.undotree')
  require('undotree').open()
end, { desc = 'Undotree' })

map('n', '<leader>dd', function()
  vim.cmd.packadd('nvim.difftool')
  local path = vim.fn.input('Diff against: ', '', 'file')
  if path ~= '' then vim.cmd('DiffTool ' .. vim.fn.fnameescape(path)) end
end, { desc = 'DiffTool (built-in)' })

map('n', '<leader>sc', function()
  vim.cmd.packadd('cfilter')
  local pat = vim.fn.input('Filter quickfix: ')
  if pat ~= '' then vim.cmd('Cfilter /' .. vim.fn.escape(pat, [[\/]]) .. '/') end
end, { desc = 'Filter quickfix (cfilter)' })

-- ── Visual mode ─────────────────────────────────────────────────────
map('v', 'J', ":m '>+1<CR>gv=gv",  { desc = 'Move down' })
map('v', 'K', ":m '<-2<CR>gv=gv",  { desc = 'Move up' })
map('v', 'H', '<gv',               { desc = 'Dedent' })
map('v', 'L', '>gv',               { desc = 'Indent' })
map('v', '<', '<gv')
map('v', '>', '>gv')
map('v', 'p', '"_dP',              { desc = 'Paste (keep register)' })
map('v', '<leader>d', '"_d',       { desc = 'Delete to void' })
map('v', '<leader>i', ':s/\\(\\s*\\)/\\1',  { desc = 'Multi-cursor at line start' })
map('v', '<leader>a', ':s/$/',            { desc = 'Multi-cursor at line end' })

-- Surround (S prefix in visual — avoids overriding " register selection)
for open, pair in pairs({
  ['"'] = '""', ['['] = '[]', ['('] = '()',
  ['{'] = '{}', ["'"] = "''", ['`'] = '``',
}) do
  map('v', 'S' .. open, 'c' .. pair .. '<Esc>P', { desc = 'Surround ' .. pair })
end

-- ── Insert mode ─────────────────────────────────────────────────────
map('i', '<C-s>',     '<Cmd>w<CR>',                                     { desc = 'Save' })
map('i', '<C-v>',     '<C-r><C-p>+', { desc = 'Paste' })
map('i', '<C-Space>', function()
  vim.lsp.completion.get()
end, { desc = 'Trigger LSP completion' })

-- Tab: snippet jump → completion menu cycle → indent
map('i', '<Tab>', function()
  if vim.snippet.active({ direction = 1 }) then
    return '<Cmd>lua vim.snippet.jump(1)<CR>'
  elseif vim.fn.pumvisible() == 1 then
    return '<C-n>'
  else
    return '<Tab>'
  end
end, { expr = true, desc = 'Tab (snippet/complete/indent)' })

map('i', '<S-Tab>', function()
  if vim.snippet.active({ direction = -1 }) then
    return '<Cmd>lua vim.snippet.jump(-1)<CR>'
  elseif vim.fn.pumvisible() == 1 then
    return '<C-p>'
  else
    return '<S-Tab>'
  end
end, { expr = true, desc = 'S-Tab (snippet/complete back)' })

-- CR: confirm completion (with selected item) or normal newline
map('i', '<CR>', function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ 'selected' }).selected >= 0 then
    return '<C-y>'
  end
  return '<CR>'
end, { expr = true, desc = 'Confirm completion or newline' })

-- Escape: dismiss completion menu or normal escape
map('i', '<Esc>', function()
  if vim.fn.pumvisible() == 1 then
    return '<C-e>'
  end
  return '<Esc>'
end, { expr = true, desc = 'Dismiss completion or escape' })

-- Snippet stop (exit snippet mode)
map('s', '<Esc>', function() vim.snippet.stop() end, { desc = 'Exit snippet' })

-- ── Auto-pairs loaded from lua/autopairs.lua ────────────────────────

-- ── Terminal mode ───────────────────────────────────────────────────
-- Single <Esc> left for TUI apps (fzf, htop); use qq or <Esc><Esc> to exit
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
map('t', 'qq',   '<C-\\><C-n>')
map('t', '<C-h>', '<C-\\><C-n><C-w>h')
map('t', '<C-j>', '<C-\\><C-n><C-w>j')
map('t', '<C-k>', '<C-\\><C-n><C-w>k')
map('t', '<C-l>', '<C-\\><C-n><C-w>l')

-- ── Incremental selection: <A-o> expand / <A-i> shrink ──────────────
-- Strategy: LSP textDocument/selectionRange first (vtsls, pyright,
-- vscode-json-language-server all support it). Pure treesitter node-walk
-- as fallback for filetypes with no LSP (bash, configs, etc.).
-- Checking support upfront avoids the "not supported" notification spam.
do
  local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

  local function lsp_supports(buf)
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      if c:supports_method('textDocument/selectionRange') then return true end
    end
    return false
  end

  -- Apply 0-indexed treesitter range (ec exclusive) as charwise visual.
  local function ts_apply(sr, sc, er, ec)
    local line = vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or ''
    local ec_vis = math.max(sc, math.min(ec - 1, math.max(0, #line - 1)))
    if vim.api.nvim_get_mode().mode:match('[vV\22]') then
      vim.api.nvim_feedkeys(ESC, 'nx', false)
    end
    vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
    vim.api.nvim_feedkeys('v', 'nx', false)
    vim.api.nvim_win_set_cursor(0, { er + 1, ec_vis })
  end

  local _ts_stacks = {}  -- [bufnr] = list of saved ranges / cursor positions

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = vim.api.nvim_create_augroup('TsSelStackCleanup', { clear = true }),
    callback = function(ev)
      _ts_stacks[ev.buf] = nil
    end,
  })

  map({ 'n', 'x' }, '<A-o>', function()
    local buf = vim.api.nvim_get_current_buf()

    -- ── LSP path ──────────────────────────────────────────────────
    if lsp_supports(buf) then
      vim.lsp.buf.selection_range(math.max(1, vim.v.count1))
      return
    end

    -- ── Treesitter fallback ───────────────────────────────────────
    if not vim.treesitter.get_parser(buf, nil, { error = false }) then return end

    _ts_stacks[buf] = _ts_stacks[buf] or {}
    local m = vim.api.nvim_get_mode().mode
    local node

    if m:match('[vV\22]') then
      -- Visual: find node that fully covers selection, then go to parent
      local v1, v2 = vim.fn.getpos('v'), vim.fn.getpos('.')
      if v1[2] > v2[2] or (v1[2] == v2[2] and v1[3] > v2[3]) then v1, v2 = v2, v1 end
      local sr, sc = v1[2] - 1, v1[3] - 1
      local er, ec = v2[2] - 1, v2[3]
      table.insert(_ts_stacks[buf], { 'v', sr, sc, er, ec })
      node = vim.treesitter.get_node({ pos = { sr, sc }, bufnr = buf })
      while node do
        local ns, nsc, ne, nec = node:range()
        if (ns < sr or (ns == sr and nsc <= sc)) and
           (ne > er or (ne == er and nec >= ec)) then break end
        node = node:parent()
      end
      node = node and (node:parent() or node) or nil
    else
      -- Normal: select node at cursor; reset stack
      _ts_stacks[buf] = {}
      node = vim.treesitter.get_node({ bufnr = buf })
      if node then
        local cur = vim.api.nvim_win_get_cursor(0)
        table.insert(_ts_stacks[buf], { 'n', cur[1], cur[2] })
      end
    end

    if node then ts_apply(node:range()) end
  end, { desc = 'Expand selection (LSP selectionRange / treesitter)' })

  map({ 'n', 'x' }, '<A-i>', function()
    local buf = vim.api.nvim_get_current_buf()

    if lsp_supports(buf) then
      vim.lsp.buf.selection_range(-math.max(1, vim.v.count1))
      return
    end

    local stack = _ts_stacks[buf]
    if not stack or #stack == 0 then return end
    local prev = table.remove(stack)
    if prev[1] == 'n' then
      -- Restore cursor, exit visual
      vim.api.nvim_feedkeys(ESC, 'nx', false)
      vim.api.nvim_win_set_cursor(0, { prev[2], prev[3] })
    else
      ts_apply(prev[2], prev[3], prev[4], prev[5])
    end
  end, { desc = 'Shrink selection (LSP selectionRange / treesitter)' })
end
