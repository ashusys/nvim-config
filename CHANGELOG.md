# Changelog

All notable changes are documented here in reverse-chronological order.
Entries are grouped by theme, not by commit.

---

## [Unreleased]

### Added
- `lua/config/` — centralized config layer with `init.lua` (defaults) and
  `local.lua.example` (per-machine template). All tunable values consolidated
  in one place; machine-specific overrides in `local.lua` (gitignored).
- `lua/utils/git_root.lua` — shared LRU-bounded git-root cache (max 200
  entries) shared by `git.lua`, `diffview.lua`, and `resession.lua`. Eliminates
  redundant `git rev-parse` calls across modules.
- `M.attach(buf)` exported from `plugins/rest.lua` — ensures the first `http`
  buffer gets REST keymaps attached immediately on lazy load (previously only
  subsequent buffers were attached).
- `confirm_write_if_modified()` helper in `git.lua` — prompts before writing
  a modified buffer to disk when staging or opening difftool. Previously both
  operations called `vim.cmd('silent write')` unconditionally.
- `get_dimensions()` helper in `terminal.lua` — floating terminal resize now
  reads `config.float_ratio` instead of hardcoding 0.8.
- `home` key in `lua/config/init.lua` defaults — resolves `$HOME` at config
  load time; all path consumers (`options.lua`, `finder.lua`, `resession.lua`)
  now read `cfg.home` instead of `os.getenv('HOME') or '/home/dev'` fallbacks.
- `README.md`, `LICENSE.txt`, `CONTRIBUTING.md`, `PERFORMANCE.md`, `INSTALL.md`,
  `CHANGELOG.md` — publishable documentation added.

### Changed
- `<C-Space>` in insert mode now calls `vim.lsp.completion.get()` (native
  0.12 API) instead of `<C-x><C-o>` (omnifunc). Removes the vimscript
  dispatch boundary and uses the same completion path as autotrigger.
- `plugins/rest.lua` env parser rewritten: supports `export KEY=VALUE` syntax,
  blank lines, `#` comments, and properly strips surrounding quotes. URL is now
  `vim.trim()`-ed after HTTP version stripping to avoid trailing whitespace in
  `curl` commands.
- REST result buffer now explicitly sets `modifiable = true` before
  `nvim_buf_set_lines` and back to `false` after — fixes crash when reusing
  an existing result buffer.
- `autocmds.lua` SessionAutosave handler: dead `vim.g._nvim_session_from_argv`
  branch removed. Session path now resolves in one expression:
  `ts ~= '' and fnamemodify(ts) or from_env`.
- `terminal.lua` replaced `vim.cmd.terminal()` (which re-sets `s.buf`) with
  `vim.fn.termopen(vim.o.shell)` to keep the buffer reference stable.
- `BRAIN.md` and `KEYBINDINGS.md` updated: module map, session notes, LSP
  header, and environment section reflect current implementation.
- `PerfReport` command: replaced `vim.fn.getbufinfo()` vimscript call with a
  pure Lua `nvim_list_bufs()` + `vim.bo[buf].buflisted` loop.
- Python docstring generator in `after/ftplugin/python.lua`: parameter names
  now strip leading `*`/`**` and annotations/defaults — only the bare
  identifier is emitted.

### Fixed
- `plugins/resession.lua`: stale `local HOME = os.getenv('HOME') or '/home/dev'`
  line removed.
- `options.lua` and `finder.lua`: `/home/dev` hardcoded fallbacks removed.

---

## Pre-publication History

The following sessions represent significant architectural work that happened
before the config was structured for public release. Full details in
[BRAIN.md § 10](BRAIN.md#10-all-fixes-applied-chronological).

### Session 4 — Deep Scan #2
14 fixes: format timeout halved, prettierd unchanged fall-through fixed,
LSP progress echo cleared on completion, `printf '%s'` quoting fix in finder,
`LastPosition` skips commit/rebase buffers, `ionice` executable guard added,
terminal buffer leak on tab close fixed, `\lR` no longer silently saves
buffers, `formatoptions` set globally, `J` cursor save/restore uses API
instead of mark `z`, `gh` no-diagnostic feedback added, statusline inner loop
uses `vim.bo[b].buflisted`, shada register limit raised from 5 KB to 10 KB.

### Session 3 — Deep Scan #1
21 fixes: MRU oscillation bug, LSP buf setup stale on restart, bigfile
`LspAttach` missing `once=true`, `typehierarchy` nil guard, dead LSP fold
check removed, `cmdheight=0` wrapped in pcall, stale finder keymaps removed,
prettierd 3-state return, statusline buffer count event-driven, WinResized
only processes changed windows, resession async git-root lookup, shared git
root cache created, prettierd moved to `lua/format.lua`, BufView keyed by
win+buf, `CacheRebuild` force param, `o.autocomplete = false`, health.lua
entries added, LSP progress indicator added, session show command added.

### Session 2 — Treesitter Selection Rewrite
`<A-o>` / `<A-i>` incremental selection rewritten: LSP `selectionRange`
first, pure treesitter node walk fallback. Per-buffer `_ts_stacks` for
correct shrink history. JSON LSP (`vscode-json-language-server`) added.

### Session 1 — Format on Save Refactor
Whole-file prettierd on `BufWritePre` replaced with hunk-based LSP
`rangeFormatting`. Format is off by default (`vim.g.disable_autoformat`).
`:FormatToggle` / `\tf` for global toggle. `\cf` for manual full format.
