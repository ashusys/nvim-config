-- ═════════════════════════════════════════════════════════════════════
--  Centralised config — smart defaults + optional user overrides
--
--  Users: copy lua/config/local.lua.example → lua/config/local.lua
--  and uncomment only the values you want to change.
--  That file is gitignored — your settings survive git pull.
-- ═════════════════════════════════════════════════════════════════════

local cpus = (vim.uv.available_parallelism and vim.uv.available_parallelism()) or 4
local home = vim.env.HOME or vim.fn.expand('~')

local defaults = {
  -- ── Paths ───────────────────────────────────────────────────────────
  home = home,

  -- Root directory containing first-level git repos for sessions/caching.
  -- Set to nil to disable repo-session auto-load and project-wide cache.
  project_root = nil,

  -- ── Hardware ────────────────────────────────────────────────────────
  max_threads   = cpus,            -- fff.nvim thread pool
  fd_threads    = cpus + 4,        -- fd benefits from oversubscription
  rg_threads    = cpus + 4,        -- ripgrep thread count

  -- ── Colorscheme ─────────────────────────────────────────────────────
  colorscheme = 'void',

  -- ── Timing (ms) ─────────────────────────────────────────────────────
  updatetime          = 250,       -- CursorHold delay
  timeoutlen          = 300,       -- leader key timeout (250 on WSL, 300 elsewhere)
  lsp_debounce_ms     = 80,        -- LSP textDocument/didChange debounce
  blame_debounce_ms   = 140,       -- inline git blame update delay
  gitsigns_debounce_ms = 250,      -- gitsigns sign update throttle
  format_budget_ms    = 500,       -- max ms for range-formatting on save
  prettierd_timeout   = 3000,      -- prettierd response timeout

  -- ── Limits ──────────────────────────────────────────────────────────
  bigfile_threshold = 256 * 1024,  -- bytes; features disabled above this
  cache_ttl         = 172800,      -- file index cache validity (seconds, 48h)
  undolevels        = 500,

  -- ── UI ──────────────────────────────────────────────────────────────
  sidebar_width        = 30,       -- oil.nvim sidebar columns
  float_ratio          = 0.8,      -- floating terminal size (fraction of screen)
  scrolloff            = 8,        -- lines kept above/below cursor
  pumheight            = 8,        -- completion menu max visible items
  wrap_column          = 80,       -- prose wrap / narrow-window threshold
  finder_layout_height = 0.85,     -- fff.nvim picker height
  finder_layout_width  = 0.85,     -- fff.nvim picker width
}

-- ── Merge user overrides (lua/config/local.lua) ─────────────────────
local ok, user = pcall(require, 'config.local')
if ok and type(user) == 'table' then
  defaults = vim.tbl_deep_extend('force', defaults, user)
  -- Recompute derived thread counts if user overrode max_threads but not fd/rg_threads
  if user.max_threads and not user.fd_threads then
    defaults.fd_threads = defaults.max_threads + 4
  end
  if user.max_threads and not user.rg_threads then
    defaults.rg_threads = defaults.max_threads + 4
  end
elseif not ok and user and not user:find('not found') then
  -- Syntax error in config/local.lua — warn the user
  vim.schedule(function()
    vim.notify('config/local.lua error: ' .. tostring(user), vim.log.levels.WARN)
  end)
end

return defaults
