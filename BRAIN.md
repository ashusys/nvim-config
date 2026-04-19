# BRAIN.md — Neovim Config: Complete Project Context

> Use this file to resume any session. It contains the full design intent,
> architecture, all decisions made, every fix applied, and known remaining work.

---

## 1. The Mission

Build the **fastest, most reliable, zero-BS Neovim config** possible on:
- Neovim **0.12.x** (bleeding edge, `vim.pack` native, zero lazy.nvim)
- **WSL2** on a 28-core workstation
- Large monorepos with dozens of first-level git repos and very large working sets
- Daily driver replacing **VS Code** — must feel equally fast and correct

**Non-negotiables:**
- Zero startup time penalty (everything deferred after first frame)
- Every feature must work 100% of the time or be removed
- No plugin for something Neovim does natively
- Pure black/white color theme — zero distraction
- Vim grammar is sacred — no overrides of single-key built-ins

---

## 2. Config Location

```
~/.config/nvim  →  clone directly, or symlink from  ~/dotfiles/nvim-config/
```

All paths in this document are relative to the repository root unless noted otherwise.

---

## 3. Architecture

### 3.1 Plugin System — `vim.pack` (Neovim 0.12 native)

No lazy.nvim, no packer, no mini.deps. Pure `vim.pack.add({ 'url' })` in each
plugin file. Neovim 0.12 manages install/update/lockfile natively.

```
nvim-pack-lock.json   ← auto-managed by vim.pack (commit hashes)
```

### 3.2 Load Phases — `init.lua`

```
Immediate (blocks first frame — must be fast):
  options, keymaps, autopairs, autocmds, statusline, colorscheme

Post-render (VimEnter + defer_fn):
  Phase 1 (0ms):  lsp
  Phase 2 (10ms): finder, fff, terminal, git, oil, resession
  Phase 3 (50ms): gitsigns, diffview

Lazy FileType:
  http → load rest.lua and attach current buffer (only when http buffer opened)

Lazy keypress:
  <C-.> / <leader>o* → opencode.nvim (loads on first press)
```

### 3.3 Module Map

```
lua/
  init.lua            ← boot sequence, deferred phases
  options.lua         ← all vim.o settings
  keymaps.lua         ← all keymaps + MRU tracker + buffer ops
  autocmds.lua        ← all autocmds + format-on-save + BufView
  autopairs.lua       ← pure-Lua bracket/quote pairing (no plugin)
  statusline.lua      ← pure-Lua statusline, event-driven caching
  lsp.lua             ← LSP setup, LspAttach, diagnostics, completion
  git.lua             ← blame ghost text, Alt+d diff, git workflow
  finder.lua          ← fzf pickers (\fd \fw \fa \gb \gq \gn)
  terminal.lua        ← floating toggle terminal (per-tab persistent)
  health.lua          ← :checkhealth output
  format.lua          ← prettierd_format() — shared by autocmds+lsp
  text_objects.lua    ← TS structural editing (used by after/ftplugin)
  ftplugin_jsts.lua   ← JS/TS-specific keymaps loaded by after/ftplugin
  config/
    init.lua          ← central defaults + smart merge with local overrides
    local.lua         ← machine-specific overrides (kept local)
    local.lua.example ← publishable template for overrides
  utils/
    git_root.lua      ← shared, cached git-root lookup (LRU, 200 entries)
  plugins/
    gitsigns.lua      ← hunk signs + hunk ops (\h* namespace)
    diffview.lua      ← Sublime Merge-style consolidated diff view
    resession.lua     ← per-git-repo sessions under config.project_root
    oil.lua           ← file explorer (sidebar + buffer-style editing)
    fff.lua           ← fff.nvim — Rust frecency file/grep finder
    opencode.lua      ← AI coding agent (lazy-loaded)
    rest.lua          ← REST client (lazy-loaded on http ft)

lsp/                  ← Neovim 0.12 auto-loaded server configs
  vtsls.lua
  pyright.lua
  ruff.lua
  vscode-eslint-language-server.lua.disabled
  vscode-json-language-server.lua
  bash-language-server.lua
  lua-language-server.lua
  marksman.lua
  yaml-language-server.lua
  bicep-langserver.lua

colors/
  void.lua            ← pure black/white palette

after/ftplugin/       ← per-filetype keymaps (JS/TS/Lua/Python)
queries/              ← custom treesitter highlight queries
```

---

## 4. Key Design Decisions

### 4.1 Clipboard
No `clipboard=unnamedplus`. System clipboard is **explicit only** via `\y`/`\p`.
This avoids every yank/delete polluting the system clipboard.

### 4.2 Keymap Architecture — Zero Timeout Conflicts
Two strict rules:
1. If `\X` has any `\XY` sub-key, then `\X` alone does **nothing** (no standalone + extension conflict).
2. If `\X` is instant (no sub-keys), verify no `\XY` exists anywhere.

`s`-prefix: all plugin-provided keys use right-hand second key for speed.
`g`-prefix: Vim-native go-to convention (LSP extends it, zero extra latency).

### 4.3 Completion
`vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })` in LspAttach.
`o.autocomplete = false` (global option intentionally off — let LspAttach manage it to avoid a race).
Tab/S-Tab: snippet jump → completion cycle → indent (priority order).
CR: confirm selected item only (never triggers completion).

### 4.4 Semantic Tokens
Disabled for all clients:
```lua
client.server_capabilities.semanticTokensProvider = nil
```
Treesitter handles all syntax highlighting. Semantic tokens conflict with the void theme.

### 4.5 Format on Save
- **OFF by default** (`vim.g.disable_autoformat = true`)
- Toggle globally with `:FormatToggle` / `\tf`
- Toggle per-buffer with `:FormatToggleBuffer`
- When ON: hunk-based LSP `rangeFormatting` — only changed hunks, never whole file
- Manual full format: `\cf` (prettierd first, then LSP fallback)
- prettierd logic lives in `lua/format.lua` (shared module, not a global)

### 4.6 Folding
- Global default: `foldmethod=indent`, `foldlevel=99` (effectively open)
- Per-buffer upgrade: `FileType` autocmd tries `vim.treesitter.start` → sets `foldexpr` treesitter
- Further upgrade: `LspAttach` with `textDocument/foldingRange` → overrides with `vim.lsp.foldexpr()`

### 4.7 Big File Guard
Files > 256 KB: syntax/filetype stripped, LSP/treesitter/undo/swap disabled, signcolumn hidden.

### 4.8 Sessions (resession.nvim)
Auto-save/load per git repo **only for first-level repos under `config.project_root`**.
Users set `config.project_root` in `config/local.lua` for their own machine.
Session name = repo basename.
VimEnter: async git call (non-blocking).
VimLeavePre: sync git call (uses shared `utils/git_root` cache populated on startup).

### 4.9 Shared Git Root Cache
`lua/utils/git_root.lua` — one LRU-bounded cache (max 200 entries) shared across:
- `git.lua` (blame, diff, workflow)
- `diffview.lua` (git root for -C flag)
- `resession.lua` (session name from git root)

API: `M.get(dir)` → sync (blocks, uses cache), `M.store(dir, root)` → populate from async, `M.invalidate(dir)`, `M.clear()`.
`M.peek(dir)` → nonblocking cache lookup for async callers.

### 4.10 BufView (scroll position memory)
Keyed by `win * 2^20 + buf` (not just buf) so the same file in two vertical splits saves/restores independently.
Restored **synchronously** in `BufEnter` (no `vim.schedule`) so LSP/quickfix jumps always set final cursor position after the restore — no cursor fight.

---

## 5. LSP Servers

| Server | Language | Notes |
|--------|----------|-------|
| `vtsls` | TypeScript / JavaScript | Smart gd → `_typescript.goToSourceDefinition` |
| `pyright` | Python | Type checking |
| `ruff` | Python | Linting + formatting |
| `vscode-json-language-server` | JSON / JSONC | Installed via `npm i -g vscode-langservers-extracted` |
| `bash-language-server` | Bash | |
| `lua-language-server` | Lua | |
| `marksman` | Markdown | |
| `yaml-language-server` | YAML | |
| `bicep-langserver` | Bicep | |

All servers checked with `vim.fn.executable()` at startup — missing servers silently skip (no error).
Active servers must also have a live `lsp/<server>.lua` config file present; the config directory is the source of truth for enable/disable.

`vscode-eslint-language-server` is currently **disabled locally** by renaming its config to `.disabled` because the shared workspace ESLint package chain was unstable and kept breaking daily use.

Semantic tokens disabled globally. Format disabled on vscode-json (prettierd handles JSON).

### 5.1 Key LSP Keymaps (set in LspAttach)

```
gd          Smart go-to-source (vtsls) / definition fallback
grr         References (0.12 built-in)
gri         Implementations (0.12 built-in)
gra         Code action (0.12 built-in)
grn         Rename (0.12 built-in)
grt         Type definition (0.12 built-in)
K           Hover (0.12 built-in)
C-S         Signature help (0.12 built-in)
\ca         Code action
\cr         Rename
\cf         Format (prettierd → LSP)
\co         Document symbols
\cO         Workspace symbols
\ci         Incoming calls
\cI         Outgoing calls
\ch         Type hierarchy
\lR         Restart LSP (stop + reload buffers)
\lS         Stop all LSP
```

---

## 6. Finder Architecture

Two complementary pickers:

### 6.1 fff.nvim (sl / sk / go / ga)
- Rust binary, frecency-ranked, typo-resistant
- `go` = find files, `ga` = live grep (project-wide)
- `sl` = find files, `sk` = live grep (aliases)
- 28-thread config, lazy sync (indexes on first open)
- Frecency DB: `~/.cache/nvim/fff_nvim`

### 6.2 finder.lua (fzf-based, \f* and \g* namespace)
- Pre-cached file index: `~/.cache/nvim/codebase_files.txt`
- Cache TTL: 48 hours, rebuilt with `:CacheRebuild`
- Cache invalidated on oil mutations (`OilMutationComplete` event)
- `ionice`/`nice` for background cache builds (with `executable('ionice')` guard)
- Pickers: `\ff` (find file), `\fd` (git diff files), `\fw` (git working), `\fa` (arglist), `\fn` (native), `\fl` (last), `\fh` (qf history)
- Grep: `\gg` (project), `\ga` (arglist), `\gb` (buffer lines), `\gq` (quickfix refine), `\gn` (native)
- Float UI: 80×80% of screen, `fzf --algo=v2 --no-sort --multi`

---

## 7. Statusline

Pure Lua, zero plugins, event-driven cache (never computed per-redraw).

```
[N/I/V] filename [+]  [idx/total]  E2 W1  ═══  [1/99]  recording @q  branch +3 -1 ~2  N 42:8 95%
```

Caches updated by events:
- `DiagnosticChanged` → diagnostic counts
- `BufAdd`/`BufDelete`/`BufWipeout` → `recount_listed()` (buffer count)
- `BufEnter` → `refresh_buf_idx()` + `refresh_fname()` + `refresh_diag()`
- `BufModifiedSet`/`DirChanged` → filename
- `CmdlineLeave`/`CursorHold` → search count
- `RecordingEnter`/`RecordingLeave` → macro recording
- Git branch/diff: zero-cost read from `vim.b.gitsigns_head` / `vim.b.gitsigns_status_dict`

Uses pure `vim.bo[b].buflisted` (no `vim.fn.buflisted()` vimscript boundary in loops).

---

## 8. MRU Buffer System

`keymaps.lua` maintains a module-level MRU list:
- `mru_list[]` — ordered list of buffer IDs (most recent first)
- `mru_set{}` — O(1) presence check
- `_mru_navigating` flag — prevents BufEnter from reordering during `]b`/`[b` navigation (prevents oscillation bug)

```
]b / \<Tab>    Next MRU buffer
[b             Prev MRU buffer
sb / \bl       MRU buffer picker (vim.ui.select)
\bb            fzf buffer picker (via finder.lua)
\bd            Delete buffer (window-safe — switches all windows first)
\bD            Delete all other buffers
<C-n>/<C-p>   Next/prev by buffer number (kept for muscle memory)
```

---

## 9. Git Integration

### 9.1 git.lua (zero plugins)
1. **Inline blame** — ghost text (eol extmark) on current line, 140ms debounced timer. Toggle `\tb`. Shows: commit hash, author, age, summary.
2. **Alt+d diff** — in-memory diff vs HEAD in a vsplit (no temp files, `iwhite` whitespace ignore). Toggle to close. `sh` alias.
3. **Git workflow** — status, stage, commit, push, log commands. `\G*` namespace.

### 9.2 gitsigns.nvim
- Sign column markers (add/change/delete)
- Hunk ops: `\hs` stage, `\hr` reset, `\hS` stage buffer, `\hu` undo stage, `\hR` reset buffer, `\hp` preview, `\hd` diff
- Hunk navigation: `]c` / `[c` (diff-mode aware)
- Hunk text object: `ih` (visual + operator)
- Provides `vim.b.gitsigns_head` and `vim.b.gitsigns_status_dict` for statusline

### 9.3 diffview.nvim
- `sd` open diffview status, `se` file history, `sf` diff current, `sg` diff branch
- All commands use `-C <git_root>` flag (reads from `utils/git_root`)
- `sx` close diffview

---

## 10. All Fixes Applied (Chronological)

### Session 1 — Format on Save Refactor
- **Problem:** prettierd ran on entire file on every BufWritePre — polluted diffs
- **Fix:** Replaced whole-file prettierd with hunk-based LSP `rangeFormatting`
- Reads gitsigns hunks, applies `rangeFormatting` per hunk, bottom-to-top
- prettierd kept for manual `\cf` only
- `vim.g.disable_autoformat = true` — format-on-save OFF by default

### Session 2 — Alt+o / Alt+i Incremental Selection Broken
- **Root cause 1:** Config used `vim.treesitter._select` — a private API that never existed in Neovim 0.12
- **Root cause 2:** JSON had no LSP → no treesitter-node walk worked on JSON
- **Fix 1:** Rewrote `<A-o>`/`<A-i>` with LSP-first approach: `vim.lsp.buf.selection_range(±1)` when LSP supports `textDocument/selectionRange`, pure `vim.treesitter.get_node()` node-walk fallback otherwise
- **Fix 2:** Installed `vscode-langservers-extracted` via npm, created `lsp/vscode-json-language-server.lua`

### Session 3 — Deep Scan #1 (21 issues found, all fixed)

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | keymaps.lua | MRU ]b/[b oscillation — BufEnter reordered list mid-navigate | Added `_mru_navigating` flag |
| 2 | lsp.lua | `buf_lsp_setup` not cleared on `\lR` restart | Added `LspDetach` autocmd to clear when last client leaves |
| 3 | autocmds.lua | Bigfile `LspAttach` inner autocmd missing `once=true` | Added `once = true` |
| 4 | lsp.lua | `vim.lsp.buf.typehierarchy` nil on some 0.12 builds | Guard: `typehierarchy or type_hierarchy` |
| 5 | autocmds.lua | TreesitterStart had dead LSP fold check (always false before LspAttach) | Removed the check; set treesitter folds unconditionally |
| 6 | options.lua | `cmdheight=0` unconditional — hangs if ui2 fails to load | `cmdheight=1` default; set to 0 only inside pcall success |
| 7+17 | keymaps.lua | `sb` and `<leader>fb` in finder placeholder list (finder never sets these) | Removed both |
| 8 | lsp.lua | prettierd 'unchanged' returned truthy, caller showed "Formatted" notify anyway | Proper 3-state: `'formatted'`/`'unchanged'`/`false` |
| 9 | statusline.lua | `getbufinfo({ buflisted=1 })` called on every BufEnter | Replaced with event-driven counter + `nvim_list_bufs()` |
| 10 | autocmds.lua | WinResized iterated all windows (even unchanged ones) | Read `vim.v.event.windows` — only process resized windows |
| 11 | resession.lua | `vim.system():wait()` blocking on VimEnter | Added async `get_repo_session_name_async()` |
| 12 | git/diffview/resession | Three separate git root caches (race + wasted calls) | Created `lua/utils/git_root.lua` — single shared LRU cache |
| 13 | autocmds.lua | `_G._prettierd_format` global exposure | Moved to `lua/format.lua` module; `_G` no longer used |
| 14 | autocmds.lua | BufViewSave keyed by buf only — two splits on same file clobbered each other | Keyed by `win * 2^20 + buf` |
| 15 | finder.lua | `CacheRebuild` mutated `CACHE_TTL` upvalue (not thread-safe, surprising) | Added `force` bool param to `rebuild_cache(force)` |
| 16 | options.lua | `o.autocomplete=true` raced with LspAttach autotrigger | Changed to `false` |
| 18 | health.lua | Missing `prettierd` and `vscode-json-language-server` from optional tools | Added both |
| 19 | lsp.lua | No LSP progress indicator | Added `LspProgress` autocmd → echoes to cmdline |
| 20 | resession.lua | `<leader>Sc` show session not implemented | Added keymap |

### Session 4 — Deep Scan #2 (14 additional issues fixed)

| # | File | Issue | Fix |
|---|------|-------|-----|
| B1 | autocmds.lua | `format_changed_lines` blocked 2s × N_hunks per save | `timeout_ms` 2000 → 500 |
| B2 | lsp.lua | prettierd `'unchanged'` fell through to LSP (double-format) | Guard all truthy returns |
| B3 | lsp.lua | LSP progress echo never cleared when work finished | Added `else echo('')` when empty |
| B4 | finder.lua | `printf %s` corrupted paths with `%` chars | Changed to `printf '%s'` |
| B5 | autocmds.lua | `LastPosition` restored cursor in gitcommit/gitrebase (wrong) | Skip for commit/rebase filetypes |
| B6 | finder.lua | `ionice` used without existence check | Added `vim.fn.executable('ionice')` guard |
| B7 | terminal.lua | Terminal buffer leaked on tab close | Explicitly delete buffer in `TabClosed` |
| B8 | lsp.lua | `\lR` silently saved modified buffers to disk | Removed auto-save, reload only |
| I9 | options.lua | `formatoptions` only set per-FileType, not globally | Added `o.formatoptions = 'jcroqlnt'` |
| I10 | keymaps.lua | `J` used `mzJ\`z` — clobbered user mark z | Replaced with API cursor save/restore |
| I11 | keymaps.lua | `<S-l>`/`<S-h>` were duplicates of `<C-n>`/`<C-p>` | Revisited later; current runtime still keeps them as buffer aliases |
| I12 | keymaps.lua | `gh` gave no feedback when no diagnostic on line | Added `_G._toggle_msg('No diagnostics...')` |
| I13 | statusline.lua | `vim.fn.buflisted()` in loops (vimscript boundary per-buffer) | Replaced with `vim.bo[b].buflisted` |
| I14 | options.lua | `shada s5` (5 KB limit) — large yanks silently lost | Raised to `s10`, `<50` |

---

## 11. Autopairs (pure Lua, no plugin)

`lua/autopairs.lua` — loaded in immediate phase:
- `(` `[` `{` → pair + close + Left (skip if next char is `\w`)
- `)` `]` `}` → skip-over if already there
- `"` `'` `` ` `` → pair or skip-over (skip if prev char is `\w`)
- `<BS>` → delete pair if cursor is between matching pair
- Filetype exception: Rust `'` does not auto-pair (lifetimes)

---

## 12. Incremental Selection — `<A-o>` / `<A-i>`

Strategy (in priority order):
1. **LSP** — `vim.lsp.buf.selection_range(±1)` if any client supports `textDocument/selectionRange`
   Supported by: vtsls, pyright, vscode-json-language-server
2. **Treesitter** — `vim.treesitter.get_node()` + node-walk up/down
   Used for: bash, YAML, Lua, markdown, config files

Per-buffer `_ts_stacks[bufnr]` preserves history so `<A-i>` shrinks back correctly.

---

## 13. Text Objects (Treesitter-powered)

`lua/text_objects.lua` — a module, not auto-loaded.
Used by `after/ftplugin/` files for structural editing:
- `get_node(type)` — walk up to find node of given type
- `select_node(node)` — set visual selection to node range
- `yank_node(node)` — yank node lines to `+` register
- `delete_node(node)` — delete node lines
- `goto_node(node)` — cursor to node start

---

## 14. colorscheme — `void.lua`

Pure black/white, no colors at all:
- Background: black (`#000000`)
- Foreground: white (`#ffffff`)
- Comments: dark gray
- No semantic token colors (disabled globally)
- Treesitter queries customized in `queries/` for JS/TS/Lua/Python/Markdown

---

## 15. Keybinding Namespaces Summary

```
\f*    Find files      \ff fd fw fa fn fl fh
\g*    Grep            \gg ga gb gq gn
\b*    Buffers         \bb bl bd bD
\c*    Code / LSP      \ca cr cf co cO ci cI ch cd
\G*    Git workflow    \Gs Ga Gc Gp Gl
\h*    Hunks           \hs hr hS hu hR hp hd hD
\t*    Toggles         \tf tb th tn tr ti tw ts td tb
\l*    LSP             \lR lS
\S*    Sessions        \Ss Sl Sd Sc

g*     Go-to (LSP)     gd grr gri gra grn grt gK gl gh gb
[/]*   Navigate        ]b [b ]c [c ]q [q ]Q [Q ]l [l ]d [d ]a [a
s*     s-prefix        sh si so sq su sz sw s1 sb sk sl ss sr sd se sf sg sx
<A-*>  Alt combos      <A-o> <A-i> <A-d> <A-=>
<C-*>  System          <C-s> <C-h/j/k/l> <C-d/u> <C-n/p>
```

---

## 16. Tools Required

### Required (config fails without these)
- `git` — blame, diff, gitsigns, session names
- `rg` — live grep (finder + grepprg)
- `fd` — file finder (finder cache)
- `fzf` — picker UI (finder.lua)

### Optional (features degrade gracefully if missing)
- `prettierd` v0.27.0 — `\cf` format and hunk-based save format
- `tmux` — clipboard sync (TextYankPost)
- `ionice` — cache build priority (graceful fallback if absent)
- `vtsls` — TypeScript LSP
- `pyright-langserver` — Python LSP
- `ruff` — Python LSP
- `vscode-eslint-language-server` — ESLint LSP
- `vscode-json-language-server` — JSON LSP (`npm i -g vscode-langservers-extracted`)
- `bash-language-server` — Bash LSP
- `lua-language-server` — Lua LSP
- `marksman` — Markdown LSP
- `yaml-language-server` — YAML LSP
- `bicep-langserver` — Bicep LSP

### Check all with `:checkhealth`

---

## 17. Environment Details

```
OS:        Linux (WSL2, Ubuntu)
Shell:     fish
Host:      28-core workstation
RAM:       large (never a concern)
Neovim:    0.12.1
Config:    ~/.config/nvim  (or ~/dotfiles/nvim-config symlinked there)
Repos:     configure via `config.project_root`; intended for large multi-repo worktrees
prettierd: machine-specific path; resolve with `command -v prettierd`
vscode-json-ls: machine-specific path; resolve with `command -v vscode-json-language-server`
```

---

## 18. Performance Targets and Tuning

| Setting | Value | Reason |
|---------|-------|--------|
| `updatetime` | 250ms | CursorHold delay (100 was too aggressive on big repos) |
| `timeoutlen` | 250ms | Safe for WSL latency |
| `ttimeoutlen` | 0 | Instant escape |
| `synmaxcol` | 300 | Skip syntax past 300 chars |
| `redrawtime` | 1000ms | Allow TS parsing on big files |
| `history` | 1000 | Cut from default 10000 |
| `shada` | `'100,<50,s10,h,r/tmp,r/mnt` | Small shada, 10KB register limit |
| `shelltemp` | false | Skip temp files for shell cmds |
| `regexpengine` | 0 | Auto-select fastest engine |
| grepprg | `rg --threads=32 --mmap --max-filesize=10M` | 28 threads, mmap |
| fd threads | 32 | Saturate cores |
| fff max_threads | 28 | Match core count |
| blame debounce | 140ms | No flicker during fast navigation |
| gitsigns debounce | 250ms | Matches updatetime |

**Startup:** `vim.loader.enable()` is the absolute first call (bytecode cache).
All providers disabled (`node`, `perl`, `python3`, `ruby`).
All unused builtin plugins killed (gzip, tar, zip, netrw, fzf, man, etc).

---

## 19. Known Design Tradeoffs (Intentional)

1. **`<S-h>`/`<S-l>` kept** — they duplicate `<C-n>`/`<C-p>` but remain as buffer-navigation aliases for muscle memory.
2. **Semantic tokens disabled** — treesitter handles highlighting exclusively.
3. **No clipboard=unnamedplus** — explicit `\y`/`\p` only.
4. **`i<C-v>` = paste** (removes "insert literal char" binding) — paste in insert mode.
5. **`qq` = confirm qa** (quit all, not just one window) — intentional nuclear quit.
6. **`q` disabled** — use `Q` for macros, `qq` for quit.
7. **Format-on-save OFF** — must explicitly enable per session or globally.
8. **Single `<Esc>` not captured in terminal** — passes through to TUI apps (fzf, htop). Use `<Esc><Esc>` or `qq` to exit terminal mode.

---

## 20. Design Principles for Future Changes

1. **No new globals** — use modules (`require('format').fn`), not `_G.fn`
2. **Async first** — any `vim.system():wait()` in an autocmd path is a bug
3. **One cache** — if two modules need the same data, create a shared util
4. **`once=true` on inner autocmds** — any `autocmd` created inside another `autocmd`'s callback needs `once=true` or an explicit augroup to avoid accumulation
5. **`vim.fn.*` in tight loops** — replace with `vim.bo`, `vim.wo`, `vim.api.*` (no vimscript boundary)
6. **BufWritePre budget** — total time must be under 500ms; prefer 100ms per operation
7. **No pcall soup** — `pcall` on operations that genuinely can't fail is noise; use it only at module load boundaries
8. **Event-driven caches** — statusline/state that changes on specific events should be updated by those events, not recomputed on every redraw

---

## 21. Files Created in This Project

Files added that did not exist in the original config:
- `lua/format.lua` — prettierd shared module
- `lua/utils/git_root.lua` — shared git root cache
- `lsp/vscode-json-language-server.lua` — JSON LSP config
- `BRAIN.md` — this file
- `KEYBINDINGS.md` — full keybinding reference

---

## 22. Continuing From Here

When picking up a new session:
1. Read this file (`BRAIN.md`)
2. Run `:checkhealth` — verifies all tools present
3. Run `:PerfReport` — startup stats, Lua mem, loader hit rate
4. Known remaining consideration: `qq` behavior (currently `confirm qa` — quits all windows). Could be changed to `confirm q` for single-window quit with a fallback.
