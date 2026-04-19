local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ═════════════════════════════════════════════════════════════════════
--  Big file guard (>256KB) — strip every expensive feature
-- ═════════════════════════════════════════════════════════════════════
autocmd('BufReadPre', {
  group = augroup('Bigfile', { clear = true }),
  callback = function(ev)
    local stat = vim.uv.fs_stat(ev.match)
    if not stat or stat.size <= require('config').bigfile_threshold then return end

    vim.b[ev.buf].bigfile = true
    local lo = vim.opt_local
    lo.syntax         = ''
    lo.filetype       = ''
    lo.undofile       = false
    lo.swapfile       = false
    lo.foldmethod     = 'manual'
    lo.spell          = false
    lo.list           = false
    lo.number         = false
    lo.relativenumber = false
    lo.signcolumn     = 'no'
    lo.cursorline     = false
    lo.colorcolumn    = ''
    lo.statuscolumn   = ''

    -- Detach LSP from big files — once=true since LSP attaches at most once
    autocmd('LspAttach', {
      buffer = ev.buf,
      once = true,
      callback = function(args)
        local c = vim.lsp.get_client_by_id(args.data.client_id)
        if c then pcall(c.buf_detach, c, args.buf) end
      end,
    })

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then return end
      vim.bo[ev.buf].syntax = ''
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
        pcall(client.buf_detach, client, ev.buf)
      end
      pcall(vim.treesitter.stop, ev.buf)
    end)
    vim.notify('Large file: features disabled', vim.log.levels.WARN)
  end,
})

-- ═════════════════════════════════════════════════════════════════════
--  Treesitter — auto-start, upgrade folding to expr when available
-- ═════════════════════════════════════════════════════════════════════
autocmd('FileType', {
  group = augroup('TreesitterStart', { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].bigfile then return end
    if vim.bo[ev.buf].buftype ~= '' then return end
    local ok = pcall(vim.treesitter.start, ev.buf)
    if ok then
      -- LSP foldexpr is set by LspAttach (which fires after FileType).
      -- Set treesitter folds now; LspAttach will override when it attaches.
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        if vim.api.nvim_win_is_valid(win) then
          vim.wo[win].foldmethod = 'expr'
          vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        end
      end
    end
  end,
})

-- ═════════════════════════════════════════════════════════════════════
--  Quality of life
-- ═════════════════════════════════════════════════════════════════════

-- Force formatoptions after ftplugins (builtin ftplugins override global setting)
autocmd('FileType', {
  group = augroup('FormatOptions', { clear = true }),
  callback = function()
    vim.opt_local.formatoptions = 'jcroqlnt'
  end,
})

-- Adaptive wrap: always wrap prose, wrap narrow code windows at 80 cols.
local WRAP_COLUMN = require('config').wrap_column
local prose_ft = { markdown = true, text = true, gitcommit = true, help = true }
local skip_wrap_ft = { oil = true, qf = true }
local skip_wrap_bt = { prompt = true, quickfix = true, terminal = true }

local function apply_dynamic_wrap(win, buf)
  if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.api.nvim_win_get_config(win).relative ~= '' then return end -- skip floating windows

  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype
  local prose = prose_ft[ft]
  local skip = vim.b[buf].bigfile or skip_wrap_ft[ft] or skip_wrap_bt[bt]
  local narrow = vim.api.nvim_win_get_width(win) <= WRAP_COLUMN
  local should_wrap = not vim.g.disable_dynamic_wrap and not skip and (prose or bt == '' and narrow)

  vim.wo[win].wrap = should_wrap

  if prose then
    vim.wo[win].colorcolumn = tostring(WRAP_COLUMN)
    if vim.bo[buf].modifiable then vim.bo[buf].textwidth = WRAP_COLUMN end
  else
    vim.wo[win].colorcolumn = ''
    if bt == '' and vim.bo[buf].modifiable then vim.bo[buf].textwidth = 0 end
  end
end

local function refresh_dynamic_wrap(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      apply_dynamic_wrap(win, buf)
    end
    return
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    apply_dynamic_wrap(win, vim.api.nvim_win_get_buf(win))
  end
end

autocmd({ 'BufWinEnter', 'FileType' }, {
  group = augroup('DynamicWrapBuffer', { clear = true }),
  callback = function(ev)
    refresh_dynamic_wrap(ev.buf)
  end,
})

autocmd({ 'VimEnter', 'TabEnter' }, {
  group = augroup('DynamicWrapWindow', { clear = true }),
  callback = function()
    refresh_dynamic_wrap()
  end,
})
autocmd('WinResized', {
  group = augroup('DynamicWrapResized', { clear = true }),
  callback = function()
    -- vim.v.event.windows = list of only the resized window IDs (nvim 0.10+)
    local wins = vim.v.event and vim.v.event.windows
    if wins and #wins > 0 then
      for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) then
          apply_dynamic_wrap(win, vim.api.nvim_win_get_buf(win))
        end
      end
    else
      refresh_dynamic_wrap()  -- fallback
    end
  end,
})

vim.api.nvim_create_user_command('WrapToggle', function()
  vim.g.disable_dynamic_wrap = not vim.g.disable_dynamic_wrap
  refresh_dynamic_wrap()
  _G._toggle_msg('dynamic wrap: ' .. (vim.g.disable_dynamic_wrap and 'OFF' or 'ON'))
end, { desc = 'Toggle dynamic wrap' })

-- Flash yanked region + sync to tmux clipboard (belt-and-suspenders for WSL2)
local _has_tmux = vim.fn.executable('tmux') == 1
autocmd('TextYankPost', {
  group = augroup('YankHighlight', { clear = true }),
  callback = function()
    pcall(vim.hl.on_yank, { higroup = 'IncSearch', timeout = 200 })
    if vim.v.event.operator == 'y' and vim.v.event.regname == '+' and _has_tmux then
      vim.system({ 'tmux', 'load-buffer', '-w', '-' }, { stdin = vim.fn.getreg('+') })
    end
  end,
})

-- Jump to last edit position (skip commit messages — always start at line 1)
local _no_restore_ft = { gitcommit = true, gitrebase = true, svn = true, hgcommit = true }
autocmd('BufReadPost', {
  group = augroup('LastPosition', { clear = true }),
  callback = function(ev)
    if _no_restore_ft[vim.bo[ev.buf].filetype] then return end
    if vim.bo[ev.buf].buftype ~= '' then return end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Equalize splits on resize
autocmd('VimResized', {
  group = augroup('AutoResize', { clear = true }),
  command = 'noautocmd tabdo wincmd =',
})

-- Close with 'q' for special windows
autocmd('FileType', {
  group = augroup('CloseWithQ', { clear = true }),
  pattern = { 'help', 'qf', 'lspinfo', 'checkhealth', 'notify', 'query', 'startuptime' },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = ev.buf, silent = true })
  end,
})

-- Auto-create directories on save
autocmd('BufWritePre', {
  group = augroup('AutoMkdir', { clear = true }),
  callback = function(ev)
    if ev.match:match('^%w%w+://') then return end
    vim.fn.mkdir(vim.fn.fnamemodify(ev.match, ':p:h'), 'p')
  end,
})

-- Detect external changes on focus
autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = augroup('Checktime', { clear = true }),
  callback = function()
    if vim.bo.buftype ~= 'nofile' then pcall(vim.cmd, 'checktime') end
  end,
})

-- Quickfix window settings
autocmd('FileType', {
  group = augroup('QuickfixSettings', { clear = true }),
  pattern = 'qf',
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end,
})

-- Trim trailing whitespace (skip big files, binary-ish, and whitespace-significant types)
local trim_skip_ft = { markdown = true, diff = true, patch = true, make = true, tsv = true }
autocmd('BufWritePre', {
  group = augroup('TrimWhitespace', { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].bigfile then return end
    if vim.bo[ev.buf].buftype ~= '' or not vim.bo[ev.buf].modifiable then return end
    if trim_skip_ft[vim.bo[ev.buf].filetype] then return end
    -- Quick check: bail if no trailing whitespace exists (avoids full-buffer regex)
    local has_trailing = vim.fn.search([[\s\+$]], 'nw') > 0
    if not has_trailing then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Terminal: no line numbers, auto-insert
autocmd('TermOpen', {
  group = augroup('TermSettings', { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    vim.cmd('startinsert')
  end,
})
-- BufView: per-window scroll position (keyed by win*2^20+buf to handle
-- same buffer open in multiple splits without clobbering each other).
local buf_views = {}
local buf_views_count = 0
local BUF_VIEWS_MAX = 200

local function view_key(win, buf) return win * 1048576 + buf end

autocmd('BufLeave', {
  group = augroup('BufViewSave', { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].buftype == '' then
      local win = vim.api.nvim_get_current_win()
      local k = view_key(win, ev.buf)
      if not buf_views[k] then buf_views_count = buf_views_count + 1 end
      buf_views[k] = vim.fn.winsaveview()
      if buf_views_count > BUF_VIEWS_MAX then
        local pruned = {}
        local n = 0
        for key, v in pairs(buf_views) do
          local b = key % 1048576
          if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
            pruned[key] = v
            n = n + 1
          end
        end
        buf_views = pruned
        buf_views_count = n
      end
    end
  end,
})

autocmd('BufEnter', {
  group = augroup('BufViewRestore', { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= '' then return end
    local win = vim.api.nvim_get_current_win()
    local view = buf_views[view_key(win, ev.buf)]
    if not view then return end
    -- Restore synchronously — NO vim.schedule.
    -- When jumping via :cc/:cnext/grr/gd, this runs DURING BufEnter,
    -- then the jump command sets the final cursor position AFTER.
    -- So quickfix/tag/LSP jumps always win. No flags needed.
    pcall(vim.fn.winrestview, view)
  end,
})
autocmd({ 'BufWipeout', 'BufDelete' }, {
  group = augroup('BufViewCleanup', { clear = true }),
  callback = function(ev)
    -- Remove all window entries for this buffer
    local to_remove = {}
    for k in pairs(buf_views) do
      if k % 1048576 == ev.buf then to_remove[#to_remove + 1] = k end
    end
    for _, k in ipairs(to_remove) do
      buf_views[k] = nil
      buf_views_count = buf_views_count - 1
    end
  end,
})

-- ═════════════════════════════════════════════════════════════════════
--  Format on save (toggle with :FormatToggle / <leader>tf)
--  Single global autocmd — no per-buffer state, survives ConfigReload
-- ═════════════════════════════════════════════════════════════════════
-- prettierd is in lua/format.lua; require it lazily so format.lua
-- can also be loaded independently from lsp.lua (\cf keymap).
local function prettierd_format(bufnr)
  return require('format').prettierd_format(bufnr)
end

--- Format only the lines changed since the last git commit.
--- Uses gitsigns hunks so the on-save diff never touches unrelated code.
--- Applies LSP rangeFormatting bottom→top to avoid line-number drift.
--- prettierd is intentionally skipped here (always whole-file); use \cf for that.
local FORMAT_BUDGET_MS = require('config').format_budget_ms

local function format_changed_lines(bufnr)
  local ok, gs = pcall(require, 'gitsigns')
  if not ok then return false end
  local hunks = type(gs.get_hunks) == 'function' and gs.get_hunks(bufnr) or nil
  if not hunks or #hunks == 0 then return false end

  -- Build LSP ranges for each added/changed hunk (0-indexed)
  local ranges = {}
  for _, h in ipairs(hunks) do
    if h.added.count > 0 then
      table.insert(ranges, {
        start  = { line = h.added.start - 1, character = 0 },
        ['end'] = { line = h.added.start + h.added.count - 2, character = 2147483647 },
      })
    end
  end
  if #ranges == 0 then return true end  -- only deletions, nothing to format

  -- Sort bottom→top so earlier edits don't shift later line numbers
  table.sort(ranges, function(a, b) return a.start.line > b.start.line end)
  local deadline = vim.uv.now() + FORMAT_BUDGET_MS

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method('textDocument/rangeFormatting') then
      for _, range in ipairs(ranges) do
        local remaining = deadline - vim.uv.now()
        if remaining <= 0 then return true end
        pcall(vim.lsp.buf.format, {
          bufnr      = bufnr,
          async      = false,
          timeout_ms = math.max(1, remaining),
          name       = client.name,
          range      = range,
        })
      end
      return true
    end
  end
  return false
end

autocmd('BufWritePre', {
  group = augroup('LspFormatting', { clear = true }),
  callback = function(ev)
    if vim.g.disable_autoformat or vim.b[ev.buf].disable_autoformat then return end
    if not vim.bo[ev.buf].modified then return end
    format_changed_lines(ev.buf)
  end,
})

vim.api.nvim_create_user_command('FormatToggle', function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  _G._toggle_msg('Auto-formatting: ' .. (vim.g.disable_autoformat and 'OFF' or 'ON'))
end, { desc = 'Toggle auto-formatting on save' })

vim.api.nvim_create_user_command('FormatToggleBuffer', function()
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].disable_autoformat = not vim.b[buf].disable_autoformat
  _G._toggle_msg('Buffer auto-formatting: ' .. (vim.b[buf].disable_autoformat and 'OFF' or 'ON'))
end, { desc = 'Toggle auto-formatting for current buffer' })

-- ═════════════════════════════════════════════════════════════════════
--  Auto-open quickfix after grep
-- ═════════════════════════════════════════════════════════════════════
autocmd('QuickFixCmdPost', {
  group = augroup('QuickfixOpen', { clear = true }),
  pattern = '[^l]*',
  callback = function()
    vim.cmd('cwindow')
    vim.cmd('wincmd p')
  end,
})

-- ═════════════════════════════════════════════════════════════════════
--  Resave session on exit when NVIM_SESSION_AUTOSAVE is set.
--  Uses :this_session when available, otherwise writes to the env path.
-- ═════════════════════════════════════════════════════════════════════
autocmd('VimLeavePre', {
  group = augroup('SessionAutosave', { clear = true }),
  callback = function()
    local env_raw = vim.env.NVIM_SESSION_AUTOSAVE
    local from_env = (env_raw and env_raw ~= '') and vim.fn.fnamemodify(env_raw, ':p') or nil
    if not from_env then return end
    local ts = vim.api.nvim_get_vvar('this_session') or ''
    local path = ts ~= '' and vim.fn.fnamemodify(ts, ':p') or from_env
    pcall(vim.cmd, 'mksession! ' .. vim.fn.fnameescape(path))
  end,
})
