-- ═════════════════════════════════════════════════════════════════════
--  Neovim 0.12 · vim.pack · Built-in LSP / Treesitter / Completion
--  Performance-tuned for large codebases — see lua/config/ for settings
--  Pure black & white — engineered for focus
-- ═════════════════════════════════════════════════════════════════════

-- Bytecode cache (must be absolute first)
vim.loader.enable()

-- Hard minimum — bail early on anything below 0.12
if vim.fn.has('nvim-0.12') == 0 then
  vim.api.nvim_echo({ { 'This config requires Neovim 0.12+', 'ErrorMsg' } }, true, {})
  return
end

-- Providers off before anything loads
vim.g.loaded_node_provider    = 0
vim.g.loaded_perl_provider    = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider    = 0

-- Skip menus (never used in terminal)
vim.g.did_install_default_menus = 1
vim.g.did_install_syntax_menu   = 1

-- Kill runtime plugins we never use (including system fzf.vim)
for _, p in ipairs({
  'gzip', 'tar', 'tarPlugin', 'zip', 'zipPlugin',
  'getscript', 'getscriptPlugin', 'vimball', 'vimballPlugin',
  '2html_plugin', 'tohtml', 'logiPat', 'rrhelper',
  'matchit', 'spec',
  'tutor_mode_plugin', 'rplugin', 'spellfile_plugin',
  'remote_plugins', 'shada_plugin', 'fzf',
  'man', 'osc52',
  'netrw', 'netrwPlugin', 'netrwSettings', 'netrwFileHandlers',
}) do
  vim.g['loaded_' .. p] = 1
end

-- Feedback helper — defined before modules so keymaps/autocmds/statusline can use it
function _G._toggle_msg(text)
  vim.api.nvim_echo({ { tostring(text), 'ModeMsg' } }, false, {})
end

-- ── Immediate (blocks first frame — must be fast) ───────────────────

local cfg = require('config')
for _, mod in ipairs({ 'options', 'keymaps', 'autopairs', 'autocmds', 'statusline' }) do
  local ok, err = pcall(require, mod)
  if not ok then vim.notify('Failed to load ' .. mod .. ': ' .. tostring(err), vim.log.levels.ERROR) end
end
local ok_cs, err_cs = pcall(vim.cmd.colorscheme, cfg.colorscheme)
if not ok_cs then vim.notify('Colorscheme failed: ' .. tostring(err_cs), vim.log.levels.WARN) end

-- ── Post-render (truly deferred — runs AFTER first frame) ───────────
-- vim.schedule alone doesn't guarantee post-render; VimEnter + defer_fn(0)
-- fires after the UI draws its first frame, keeping startup time clean.
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    -- Phase 1: LSP (highest priority) + undodir ensure
    vim.defer_fn(function()
      vim.fn.mkdir(vim.o.undodir, 'p')
      require('lsp')
    end, 0)

    -- Phase 2: finder + git + oil + sessions + fff (needed soon, not for first frame)
    vim.defer_fn(function()
      require('finder')
      require('plugins.fff')
      require('terminal')
      require('git').setup()
      require('plugins.oil').setup()
      require('plugins.resession')
    end, 10)

    -- Phase 3: gitsigns + diffview (heaviest — spawns git processes per buffer)
    vim.defer_fn(function()
      require('plugins.gitsigns')
      require('plugins.diffview')
    end, 50)
  end,
})

-- ── Lazy FileType loaders (zero cost until first relevant buffer) ────
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'http',
  once = true,
  callback = function(ev)
    local ok, rest = pcall(require, 'plugins.rest')
    if ok and rest.attach then rest.attach(ev.buf) end
  end,
})

-- Opencode: lazy-load on first keypress (stub pattern)
local _opencode_loaded = false
local function _load_opencode(lhs)
  if _opencode_loaded then return end
  _opencode_loaded = true
  local ok, err = pcall(require, 'plugins.opencode')
  if not ok then
    vim.notify('Opencode error: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  if lhs then
    local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    vim.api.nvim_feedkeys(keys, 'm', false)
  end
end
for _, lhs in ipairs({ '<C-.>', '<leader>oa', '<leader>os', '<leader>oo', '<leader>oe', '<leader>or', '<leader>of', '<leader>ot', '<leader>od', '<leader>oi' }) do
  vim.keymap.set({ 'n', 'x' }, lhs, function() _load_opencode(lhs) end, { desc = 'Loading opencode...' })
end
vim.keymap.set('t', '<C-.>', function() _load_opencode('<C-.>') end, { desc = 'Loading opencode...' })

-- ── Startup profiling (zero-cost until invoked) ─────────────────────
vim.api.nvim_create_user_command('PerfReport', function()
  local modules = vim.tbl_count(package.loaded)
  local bufs = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then bufs = bufs + 1 end
  end
  collectgarbage('collect')
  local mem = collectgarbage('count')
  local stats = vim.loader.stats and vim.loader.stats() or nil
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  print('  NEOVIM PERFORMANCE REPORT')
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  print(string.format('  Loaded Modules: %d', modules))
  print(string.format('  Active Buffers: %d', bufs))
  print(string.format('  Memory (KB):    %.0f', mem))
  if stats then
    print(string.format('  Loader stats:   %s', vim.inspect(stats, { newline = ' ', indent = '' })))
  end
  print(string.format('  Loader enabled: %s', vim.loader.enabled and 'yes' or 'no'))
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
end, { desc = 'Startup performance report' })

-- ── Config edit / reload ────────────────────────────────────────────
vim.api.nvim_create_user_command('ConfigEdit', function()
  vim.cmd('edit ' .. vim.fn.stdpath('config') .. '/init.lua')
end, { desc = 'Edit init.lua' })

vim.api.nvim_create_user_command('ConfigReload', function()
  local reload_modules = {
    config = true,
    options = true, keymaps = true, autocmds = true, statusline = true,
    lsp = true, finder = true, terminal = true, git = true,
    plugins = true, text_objects = true, utils = true, format = true,
  }
  for name in pairs(package.loaded) do
    local prefix = name:match('^([^%.]+)')
    if prefix and reload_modules[prefix] then
      package.loaded[name] = nil
    end
  end
  dofile(vim.fn.stdpath('config') .. '/init.lua')
  pcall(function() require('git').setup() end)
  -- Re-init deferred plugins (VimEnter once=true won't re-fire)
  pcall(require, 'plugins.fff')
  pcall(require, 'plugins.gitsigns')
  pcall(require, 'plugins.diffview')
  pcall(require, 'plugins.resession')
  if package.loaded['plugins.rest'] then pcall(require, 'plugins.rest') end
  if package.loaded['plugins.opencode'] then pcall(require, 'plugins.opencode') end
  vim.notify('Config reloaded', vim.log.levels.INFO)
end, { desc = 'Reload config' })
