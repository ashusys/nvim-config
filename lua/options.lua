local o = vim.o
local cfg = require('config')
local HOME = cfg.home

-- ── Performance ─────────────────────────────────────────────────────────
o.synmaxcol    = 300
o.redrawtime   = 1000
o.updatetime   = cfg.updatetime
o.timeoutlen   = cfg.timeoutlen
o.ttimeoutlen  = 0            -- instant escape
o.shelltemp    = false         -- skip temp files for shell cmds
o.regexpengine = 0             -- auto-select fastest regex engine
o.history      = 1000          -- trim from default 10000
o.jumpoptions  = 'stack'       -- stack-based jumplist for predictable C-o/C-i

-- ── Shada — minimal for huge repos ─────────────────────────────────
o.shada = "'100,<50,s10,h,r/tmp,r/mnt"

-- ── Filesystem ──────────────────────────────────────────────────────
o.swapfile     = false
o.backup       = false
o.writebackup  = false
o.undofile     = true
o.undodir      = HOME .. '/.vim/undodir'
o.undolevels   = cfg.undolevels

-- ── Editor ──────────────────────────────────────────────────────────
o.number         = true
o.relativenumber = true
o.numberwidth    = 3
o.signcolumn     = 'yes'
o.cursorline     = true
o.scrolloff      = cfg.scrolloff
o.sidescrolloff  = 6
o.wrap           = false
o.linebreak      = true
o.breakindent    = true
o.tabstop        = 2
o.shiftwidth     = 2
o.softtabstop    = 2
o.expandtab      = true
o.smartindent    = true
o.shiftround     = true
o.ignorecase     = true
o.smartcase      = true
o.incsearch      = true
o.hlsearch       = false
o.inccommand     = 'split'
o.splitright     = true
o.splitbelow     = true
o.termguicolors  = true
o.showmode       = false
o.showtabline    = 0
o.cmdheight      = 1          -- safe default; set to 0 below if ui2 loads
o.mouse          = ''
o.guicursor      = 'i:ver25'
o.winborder      = 'single'
o.autocomplete   = false      -- LSP completion is managed by LspAttach; setting true here races with it
o.completeopt    = 'menu,menuone,noselect,fuzzy,nearest'
o.pumheight      = cfg.pumheight
o.pumwidth       = 20
o.pumborder      = 'single'
o.pummaxwidth    = 40
o.shortmess      = 'filnxtToOFWIcC'
o.virtualedit    = 'block'
o.list           = true
o.listchars      = 'tab:│ ,trail:·,extends:→,precedes:←,nbsp:␣'
o.path           = '.,,'
o.formatoptions  = 'jcroqlnt'  -- global default; FileType autocmd also sets this per-buffer

-- ── Wildmenu ────────────────────────────────────────────────────────
o.wildmenu       = true
o.wildmode       = 'longest:full,full'
o.wildignore     = '*.o,*.obj,*.pyc,*.so,*.dll,*.class,node_modules,dist,build,target,.git'
o.wildignorecase = true

-- ── Folding (treesitter upgrades per-buffer via autocmd) ────────────
o.foldmethod     = 'indent'
o.foldlevel      = 99
o.foldlevelstart = 99
o.foldtext       = ''
o.foldenable     = true
o.fillchars      = 'eob: ,fold:-,stl: ,diff:╱'

-- ── Session — exclude terminal buffers (they can't be meaningfully restored) ──
o.sessionoptions  = 'blank,buffers,curdir,folds,help,tabpages,winsize'

-- ── Grep (rg + editorignore) ────────────────────────────────────────
if vim.fn.executable('rg') == 1 then
  o.grepprg    = 'rg --vimgrep --smart-case --hidden --mmap --max-filesize=10M --threads=' .. cfg.rg_threads .. ' --ignore-file ' .. vim.fn.stdpath('config') .. '/.editorignore 2>/dev/null'
  o.grepformat = '%f:%l:%c:%m'
end

-- ── Global statusline ───────────────────────────────────────────────
o.laststatus = 3

-- ── Experimental UI2: floating cmdline and messages ─────────────────

pcall(function()
  require('vim._core.ui2').enable({ enable = true,
  msg = {
      targets = {
        [''] = 'msg', empty = 'cmd', bufwrite = 'msg', confirm = 'cmd',
        emsg = 'pager', echo = 'msg', echomsg = 'msg', echoerr = 'pager',
        completion = 'cmd', list_cmd = 'pager', lua_error = 'pager',
        lua_print = 'msg', progress = 'pager', quickfix = 'msg',
        rpc_error = 'pager', search_cmd = 'cmd', search_count = 'cmd',
        shell_cmd = 'pager', shell_err = 'pager', shell_out = 'pager',
        shell_ret = 'msg', undo = 'msg', verbose = 'pager', wildlist = 'cmd',
        wmsg = 'msg', typed_cmd = 'cmd',
      },
      cmd = { height = 0.5 },
      dialog = { height = 0.5 },
    },
 })
  -- Only collapse the cmdline when ui2 is active; otherwise keep the safe default of 1.
  vim.o.cmdheight = 0
end)

-- ── File type associations (ported from VS Code) ────────────────────
vim.filetype.add({
  extension = {
    ['in'] = 'cpp',
  },
  filename = {
    ['.prettierrc']   = 'json',
    ['.sequelizerc']  = 'javascript',
    ['.stylelintrc']  = 'json',
    ['ace']           = 'javascript',
  },
  pattern = {
    ['.env.*']        = 'sh',
  },
})

-- Format-on-save is OFF by default — toggle with :FormatToggle / \tf
vim.g.disable_autoformat = true

-- _G._toggle_msg is defined in init.lua (before module loading) for load-order safety
