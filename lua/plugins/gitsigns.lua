-- ═════════════════════════════════════════════════════════════════════
--  Gitsigns — sign column markers + hunk operations
--  Native vim.pack — auto-install, lockfile, updates
--  Complements git.lua (blame + diff + workflow)
-- ═════════════════════════════════════════════════════════════════════

vim.pack.add({ 'https://github.com/lewis6991/gitsigns.nvim.git' })

local ok, gitsigns = pcall(require, 'gitsigns')
if not ok then return end

gitsigns.setup({
  signs = {
    add          = { text = '▎' },
    change       = { text = '▎' },
    delete       = { text = '▁' },
    topdelete    = { text = '▔' },
    changedelete = { text = '▎' },
    untracked    = { text = '▎' },
  },

  signs_staged = {
    add          = { text = '▎' },
    change       = { text = '▎' },
    delete       = { text = '▁' },
    topdelete    = { text = '▔' },
    changedelete = { text = '▎' },
    untracked    = { text = '▎' },
  },

  signcolumn         = true,
  numhl              = false,
  linehl             = false,
  word_diff          = false,
  attach_to_untracked = true,
  current_line_blame = false,
  update_debounce    = require('config').gitsigns_debounce_ms,
  max_file_length    = 10000,

  watch_gitdir = { follow_files = true },

  preview_config = {
    border   = 'single',
    style    = 'minimal',
    relative = 'cursor',
    row      = 0,
    col      = 1,
  },

  on_attach = function(bufnr)
    -- Skip big files
    if vim.b[bufnr].bigfile then return false end

    local gs = require('gitsigns')

    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- Hunk navigation (expr for diff mode fallback)
    vim.keymap.set('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gs.next_hunk() end)
      return '<Ignore>'
    end, { buffer = bufnr, expr = true, desc = 'Next hunk' })
    vim.keymap.set('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.prev_hunk() end)
      return '<Ignore>'
    end, { buffer = bufnr, expr = true, desc = 'Prev hunk' })

    -- Hunk actions (<leader>h namespace)
    bmap('n', '<leader>hs', gs.stage_hunk,        'Stage hunk')
    bmap('n', '<leader>hr', gs.reset_hunk,        'Reset hunk')
    bmap('v', '<leader>hs', function()
      gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
    end, 'Stage hunk (visual)')
    bmap('v', '<leader>hr', function()
      gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
    end, 'Reset hunk (visual)')
    bmap('n', '<leader>hS', gs.stage_buffer,      'Stage buffer')
    bmap('n', '<leader>hu', gs.undo_stage_hunk,   'Undo stage hunk')
    bmap('n', '<leader>hR', gs.reset_buffer,      'Reset buffer')
    bmap('n', '<leader>hp', gs.preview_hunk,      'Preview hunk')
    bmap('n', '<leader>hd', gs.diffthis,          'Diff this')
    bmap('n', '<leader>hD', function()
      gs.diffthis('~')
    end, 'Diff this ~')

    -- Hunk text object
    vim.keymap.set({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>',
      { buffer = bufnr, desc = 'Select hunk' })
  end,
})
