-- ═════════════════════════════════════════════════════════════════════
--  resession.nvim — session management per git repo
--  Auto-saves/loads sessions for first-level repos under project_root
--  Session names = repo basenames
-- ═════════════════════════════════════════════════════════════════════

vim.pack.add({ 'https://github.com/stevearc/resession.nvim.git' })

local ok, resession = pcall(require, 'resession')
if not ok then return end

local cfg = require('config')
local PROJECT_ROOT = cfg.project_root and vim.fn.expand(cfg.project_root) or nil

-- ── Helpers ─────────────────────────────────────────────────────────

--- Check if a path is a first-level child of the project root
local function is_project_repo(root)
  if not root or not PROJECT_ROOT then return false end
  local parent = vim.fn.fnamemodify(root, ':h')
  return parent == PROJECT_ROOT
end

--- Get session name from cwd's git repo root (basename only).
--- Returns nil if not in a first-level project repo.
--- Sync version — only call this at shutdown (VimLeavePre), not on startup.
local function get_repo_session_name()
  local dir = vim.fn.getcwd()
  local root = require('utils.git_root').get(dir)
  if not root then return nil end
  if not is_project_repo(root) then return nil end
  return vim.fn.fnamemodify(root, ':t')
end

--- Async variant — safe to call on VimEnter; fires callback on the main loop.
local function get_repo_session_name_async(callback)
  local dir = vim.fn.getcwd()
  vim.system(
    { 'git', 'rev-parse', '--show-toplevel' },
    { cwd = dir, text = true },
    vim.schedule_wrap(function(obj)
      if obj.code ~= 0 then callback(nil); return end
      local root = vim.trim(obj.stdout)
      -- Populate the shared cache so VimLeavePre's sync call is free
      require('utils.git_root').store(dir, root)
      if not is_project_repo(root) then callback(nil); return end
      callback(vim.fn.fnamemodify(root, ':t'))
    end)
  )
end

-- ── Setup ───────────────────────────────────────────────────────────

resession.setup({
  autosave = {
    enabled = true,
    interval = 120,
    notify = false,
  },
  load_order = 'modification_time',
  buf_filter = function(bufnr)
    local bt = vim.bo[bufnr].buftype
    if bt == 'terminal' or bt == 'prompt' or bt == 'quickfix' or bt == 'nofile' then
      return false
    end
    local ft = vim.bo[bufnr].filetype
    if ft == 'oil' or ft == 'DiffviewFiles' or ft == 'DiffviewFileHistory' then
      return false
    end
    return resession.default_buf_filter(bufnr)
  end,
  extensions = {
    quickfix = {},
  },
})

-- ── Auto-session: load on VimEnter, save on VimLeavePre ─────────────

local augroup = vim.api.nvim_create_augroup('ResessionAuto', { clear = true })
local _cached_session_name = nil

local function load_session_if_applicable()
  if vim.fn.argc(-1) ~= 0 or vim.g.using_stdin then return end
  -- Async git call — no blocking on VimEnter
  get_repo_session_name_async(function(name)
    if not name then return end
    _cached_session_name = name
    resession.load(name, { dir = 'dirsession', silence_errors = true })
  end)
end

-- Handle late loading: if VimEnter already fired (Phase 2 deferred), run directly
if vim.v.vim_did_enter == 1 then
  load_session_if_applicable()
else
  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup,
    nested = true,
    callback = load_session_if_applicable,
  })
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = function()
    local name = _cached_session_name or get_repo_session_name()
    if not name then return end
    resession.save(name, { dir = 'dirsession', notify = false })
  end,
})

vim.api.nvim_create_autocmd('StdinReadPre', {
  group = augroup,
  callback = function()
    vim.g.using_stdin = true
  end,
})

-- ── Keymaps (<leader>S namespace) ───────────────────────────────────

vim.keymap.set('n', '<leader>Ss', resession.save,   { desc = 'Session save' })
vim.keymap.set('n', '<leader>Sl', resession.load,   { desc = 'Session load' })
vim.keymap.set('n', '<leader>Sd', resession.delete, { desc = 'Session delete' })
vim.keymap.set('n', '<leader>Sc', function()
  local name = resession.get_current()
  vim.notify(name and ('Session: ' .. name) or 'No active session', vim.log.levels.INFO)
end, { desc = 'Session current' })

-- ── s-prefix aliases ────────────────────────────────────────────────
vim.keymap.set('n', 'ss', resession.save, { desc = 'ss: session save' })
vim.keymap.set('n', 'sr', resession.load, { desc = 'sr: session restore' })
