-- ═════════════════════════════════════════════════════════════════════
--  diffview.nvim — Sublime Merge-style consolidated VCS view
--  Keymaps auto-detect the active buffer's git repo via -C flag
--  Stage/unstage with - or s, stage all S, unstage all U
-- ═════════════════════════════════════════════════════════════════════

vim.pack.add({ 'https://github.com/sindrets/diffview.nvim.git' })

local ok, diffview = pcall(require, 'diffview')
if not ok then return end

-- ── Helpers ─────────────────────────────────────────────────────────

--- Get the git root for the current buffer's file (via shared utils.git_root cache).
local _git_root_mod = require('utils.git_root')
local function get_git_root()
  local file = vim.api.nvim_buf_get_name(0)
  local dir = file ~= '' and vim.fn.fnamemodify(file, ':h') or vim.fn.getcwd()
  return _git_root_mod.get(dir)
end

-- ── Setup ───────────────────────────────────────────────────────────

diffview.setup({
  diff_binaries = false,
  enhanced_diff_hl = false,
  use_icons = false,
  show_help_hints = true,
  watch_index = true,
  icons = {
    folder_closed = '>',
    folder_open = 'v',
  },
  signs = {
    fold_closed = '>',
    fold_open = 'v',
    done = '+',
  },
  view = {
    default = {
      layout = 'diff2_horizontal',
      disable_diagnostics = false,
      winbar_info = false,
    },
    merge_tool = {
      layout = 'diff3_horizontal',
      disable_diagnostics = true,
      winbar_info = true,
    },
    file_history = {
      layout = 'diff2_horizontal',
      disable_diagnostics = false,
      winbar_info = false,
    },
  },
  file_panel = {
    listing_style = 'tree',
    tree_options = {
      flatten_dirs = true,
      folder_statuses = 'only_folded',
    },
    win_config = {
      position = 'left',
      width = 35,
      win_opts = {},
    },
  },
  file_history_panel = {
    log_options = {
      git = {
        single_file = { diff_merges = 'combined' },
        multi_file = { diff_merges = 'first-parent' },
      },
    },
    win_config = {
      position = 'bottom',
      height = 16,
      win_opts = {},
    },
  },
  hooks = {
    diff_buf_read = function()
      vim.opt_local.wrap = false
      vim.opt_local.list = false
      vim.opt_local.colorcolumn = ''
    end,
  },
})

-- ── Keymap helpers ───────────────────────────────────────────────────

local function open_diffview_index()
  local root = get_git_root()
  if not root then return vim.notify('Not in a git repo', vim.log.levels.WARN) end
  vim.cmd('DiffviewOpen -C' .. vim.fn.fnameescape(root))
end
local function open_diffview_head()
  local root = get_git_root()
  if not root then return vim.notify('Not in a git repo', vim.log.levels.WARN) end
  vim.cmd('DiffviewOpen -C' .. vim.fn.fnameescape(root) .. ' HEAD')
end
local function open_file_history()
  local root = get_git_root()
  if not root then return vim.notify('Not in a git repo', vim.log.levels.WARN) end
  vim.cmd('DiffviewFileHistory -C' .. vim.fn.fnameescape(root) .. ' %')
end
local function open_branch_history()
  local root = get_git_root()
  if not root then return vim.notify('Not in a git repo', vim.log.levels.WARN) end
  vim.cmd('DiffviewFileHistory -C' .. vim.fn.fnameescape(root))
end

-- ── Keymaps (extend \G* git namespace) ──────────────────────────────

vim.keymap.set('n', '<leader>Gd', open_diffview_index, { desc = 'Diffview: repo changes (index)' })
vim.keymap.set('n', '<leader>Ge', open_diffview_head,  { desc = 'Diffview: repo changes (vs HEAD)' })
vim.keymap.set('n', '<leader>Gh', open_file_history,   { desc = 'Diffview: file history' })
vim.keymap.set('n', '<leader>Gf', open_branch_history, { desc = 'Diffview: branch history' })
vim.keymap.set('n', '<leader>Gx', '<Cmd>DiffviewClose<CR>', { desc = 'Diffview: close' })

-- ── s-prefix aliases ────────────────────────────────────────────────

vim.keymap.set('n', 'sd', open_diffview_index,  { desc = 'sd: diffview repo changes' })
vim.keymap.set('n', 'se', open_diffview_head,   { desc = 'se: diffview vs HEAD' })
vim.keymap.set('n', 'sf', open_file_history,    { desc = 'sf: file history' })
vim.keymap.set('n', 'sg', open_branch_history,  { desc = 'sg: branch git history' })
vim.keymap.set('n', 'sx', '<Cmd>DiffviewClose<CR>', { desc = 'sx: close diffview' })
