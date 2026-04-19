-- ═════════════════════════════════════════════════════════════════════
--  fff.nvim — Rust-powered fuzzy file finder with frecency + git status
--  Replaces fzf sl/sk/go/ga with native typo-resistant, frecency-ranked picks
--  Binary auto-downloaded on install/update via PackChanged
-- ═════════════════════════════════════════════════════════════════════

vim.pack.add({ 'https://github.com/dmtrKovalenko/fff.nvim' })

vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('FffInstall', { clear = true }),
  callback = function(ev)
    local data = ev.data or {}
    local spec = data.spec or {}
    if spec.name == 'fff.nvim' and (data.kind == 'install' or data.kind == 'update') then
      if not data.active then vim.cmd.packadd('fff.nvim') end
      local ok, dl = pcall(require, 'fff.download')
      if ok then dl.download_or_build_binary() end
    end
  end,
})

local ok, fff = pcall(require, 'fff')
if not ok then return end

local cfg = require('config')

-- ── Setup ───────────────────────────────────────────────────────────

fff.setup({
  max_threads    = cfg.max_threads,
  -- Start indexing only when picker opens (avoids startup overhead on 100GB+ repo)
  lazy_sync      = true,
  -- Vim-mode in prompt: <Esc> enters normal nav, second <Esc> closes picker
  prompt_vim_mode = true,

  layout = {
    height   = cfg.finder_layout_height,
    width    = cfg.finder_layout_width,
    prompt_position  = 'bottom',
    preview_position = 'right',
    preview_size     = 0.45,
    -- Narrow terminals: stack preview above the list instead of beside it
    flex = { size = 130, wrap = 'top' },
    show_scrollbar = true,
    path_shorten_strategy = 'middle_number',
  },

  preview = {
    enabled      = true,
    line_numbers = true,
    wrap_lines   = false,
    filetypes = {
      markdown = { wrap_lines = true },
      text     = { wrap_lines = true },
    },
  },

  keymaps = {
    close             = '<Esc>',
    select            = '<CR>',
    select_split      = '<C-s>',
    select_vsplit     = '<C-v>',
    select_tab        = '<C-t>',
    move_up           = { '<Up>', '<C-p>' },
    move_down         = { '<Down>', '<C-n>' },
    preview_scroll_up   = '<C-u>',
    preview_scroll_down = '<C-d>',
    toggle_select     = '<Tab>',
    send_to_quickfix  = '<C-q>',
    cycle_grep_modes  = '<S-Tab>',
    cycle_previous_query = '<C-Up>',
    focus_list        = '<leader>l',
    focus_preview     = '<leader>p',
  },

  -- Frecency: rank files by how often + recently they're opened
  frecency = {
    enabled  = true,
    db_path  = vim.fn.stdpath('cache') .. '/fff_nvim',
  },

  -- History: boost score for files you repeatedly open with the same query
  history = {
    enabled                    = true,
    db_path                    = vim.fn.stdpath('data') .. '/fff_queries',
    min_combo_count            = 3,
    combo_boost_score_multiplier = 100,
  },

  -- Git status in sign column only (no text color — keeps void theme intact)
  git = { status_text_color = false },

  grep = {
    smart_case      = true,
    modes           = { 'plain', 'regex', 'fuzzy' },
    time_budget_ms  = 150,
    trim_whitespace = false,
  },

  debug   = { enabled = false, show_scores = false },
  logging = { enabled = true, log_level = 'warn' },
})

-- ── Keymaps — override finder's sl/sk/go/ga ─────────────────────────
-- These intentionally overwrite the fzf stubs set by finder.lua.
-- finder.lua retains all specialist pickers (\fd \fw \fa \gb \gq etc.).

local map = vim.keymap.set

map('n', 'sl',         function() fff.find_files() end,  { desc = 'sl: find files (fff)' })
map('n', 'sk',         function() fff.live_grep() end,   { desc = 'sk: live grep (fff)' })
map('n', 'go',         function() fff.find_files() end,  { desc = 'Find files (fff)' })
map('n', 'ga',         function() fff.live_grep() end,   { desc = 'Live grep (fff)' })
map('n', '<leader>ff', function() fff.find_files() end,  { desc = 'Find files (fff)' })
map('n', '<leader>gg', function() fff.live_grep() end,   { desc = 'Live grep (fff)' })
map('n', '<leader>/',  function() fff.live_grep() end,   { desc = 'Live grep (fff)' })
-- Grep word under cursor — useful when grepping a symbol from code
map('n', '<leader>gc', function()
  fff.live_grep({ query = vim.fn.expand('<cword>') })
end, { desc = 'Grep word under cursor (fff)' })
