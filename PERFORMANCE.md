# Performance

Everything in this config is designed to not exist until it is needed.
This document explains the strategy, the measurements, and how to tune it for
your hardware.

---

## Startup Budget

| Phase | When | What runs |
|-------|------|-----------|
| Immediate | Before first frame | options, keymaps, autopairs, autocmds, statusline, colorscheme |
| Phase 1 | VimEnter + 0 ms | LSP |
| Phase 2 | VimEnter + 10 ms | finder, fff, terminal, git, oil, resession |
| Phase 3 | VimEnter + 50 ms | gitsigns, diffview |
| Lazy FileType | On first `http` buffer | rest.lua + attach |
| Lazy keypress | On first `<C-.>` / `<leader>o*` | opencode.nvim |

**Target cold-start on a 28-core WSL2 machine:** < 30 ms (bytecode cache enabled).

Bytecode cache is activated as the first line of `init.lua`:
```lua
vim.loader.enable()
```
This compiles all `require()`d Lua files to bytecode on first load and reads
from cache on subsequent starts. The speedup on a warm filesystem is 3–5×.

---

## Measuring Startup

```sh
# Smoke time — wall clock from launch to ready
nvim --startuptime /tmp/nvim-startup.log +qa && \
  tail -1 /tmp/nvim-startup.log

# Module loading breakdown
nvim --headless -c 'PerfReport' -c 'qa' 2>&1
```

Inside Neovim at runtime:

```
:PerfReport
```

Reports: module count, listed buffer count, Lua heap (after GC), bytecode
cache stats.

---

## Tuning Knobs

All values live in `lua/config/init.lua` (defaults) and
`lua/config/local.lua` (per-machine overrides). The table below shows the
defaults shipped in this repo and the values used on the reference 28-core
machine.

| Key | Default | Reference (28 cores) | Effect |
|-----|---------|----------------------|--------|
| `max_threads` | auto-detected cpus | 28 | fff.nvim thread pool |
| `fd_threads` | cpus + 4 | 32 | `fd` parallelism |
| `rg_threads` | cpus + 4 | 32 | ripgrep parallelism; also sets `grepprg` |
| `updatetime` | 250 ms | 250 ms | CursorHold → blame + diagnostics |
| `timeoutlen` | 300 ms | 250 ms | Leader key window (lower on fast keyboards) |
| `lsp_debounce_ms` | 80 ms | 80 ms | `textDocument/didChange` debounce |
| `blame_debounce_ms` | 140 ms | 140 ms | Inline git blame ghost-text delay |
| `gitsigns_debounce_ms` | 250 ms | 250 ms | Gitsigns sign update throttle |
| `format_budget_ms` | 500 ms | 500 ms | Max ms for LSP range-format on save |
| `prettierd_timeout` | 3000 ms | 3000 ms | Kill prettierd request after this |
| `cache_ttl` | 172800 s | 172800 s | File index (48 h) |
| `bigfile_threshold` | 262144 B | 262144 B | LSP/TS/undo disabled above this |

To override for your machine:

```lua
-- lua/config/local.lua
return {
  max_threads = 8,
  timeoutlen  = 350,
}
```

Thread counts are auto-detected from `vim.uv.available_parallelism()` if
`max_threads` is not set, so on most machines no manual tuning is needed.

---

## Big File Guard

Files above `bigfile_threshold` (default 256 KB) have the following disabled
on `BufReadPre`:

- Syntax highlighting (`syntax off`)
- Filetype detection (stripped)
- LSP attach
- Treesitter
- Undo history (`undolevels = 0`)
- Swap file
- Sign column

This prevents Neovim from freezing on minified JS, generated proto files, or
large data dumps.

---

## Key Performance-Critical Decisions

### No Plugin Manager
`vim.pack.add()` is the only package API used. There is no lazy.nvim,
packer, or mini.deps overhead at startup. Each plugin file is loaded by the
deferred phase that needs it.

### Statusline: Event-Driven, Never Redrawn Speculatively
The statusline is a pure Lua module with per-component caches invalidated only
by the relevant autocommands (`DiagnosticChanged`, `BufEnter`, `DirChanged`,
`RecordingEnter/Leave`, etc.). It is never recomputed on every `statusline`
request — only when something actually changed.

### Git Root Cache
`lua/utils/git_root.lua` maintains a single LRU-bounded cache (max 200 entries)
shared by `git.lua`, `diffview.lua`, and `resession.lua`. No module runs
`git rev-parse` for a directory it already resolved.

### Blame Timer
Inline blame uses a `uv.new_timer()` debounced at 140 ms with a last-seen
cursor comparison. If the cursor hasn't moved since the timer fired, the blame
extmark is not re-queried or re-rendered.

### File Cache
`finder.lua` pre-builds a file index at `~/.cache/nvim/codebase_files.txt`
using `fd` with configurable thread count. Cache is rebuilt only when:
- TTL expires (48 h default)
- `:CacheRebuild` is called
- An oil mutation completes (`OilMutationComplete` event)

Rebuilds run with `ionice -c 3` (best-effort IO class) when `ionice` is
available, so they never compete with foreground work.

### Completions
`vim.lsp.completion.enable()` with `autotrigger = true` per client in
`LspAttach`. The global `o.autocomplete = false` prevents a startup race —
completion is driven entirely by the LspAttach-registered handlers.
Semantic tokens disabled globally to avoid redundant work alongside
Treesitter highlighting.

### Clipboard
`clipboard` option is not set. System clipboard operations (`\y`, `\p`) call
`vim.fn.setreg('+', …)` explicitly. This avoids a `pbcopy`/`xclip`/`wl-copy`
subprocess on every yank and delete.

---

## Profiling Recipes

**Full startup trace:**
```sh
nvim --startuptime /tmp/s.log +qa && sort -t= -k2 -rn /tmp/s.log | head -30
```

**Which modules loaded:**
```sh
nvim --headless -u init.lua \
  -c 'lua for k in pairs(package.loaded) do print(k) end' \
  -c 'qa' 2>&1 | sort
```

**Memory after GC:**
```sh
nvim --headless -u init.lua \
  -c 'lua collectgarbage("collect"); print(string.format("%.1f KB", collectgarbage("count")))' \
  -c 'qa' 2>&1
```

**Loader cache stats:**
```sh
nvim --headless -u init.lua \
  -c 'lua local s=vim.loader.stats(); if s then print(vim.inspect(s)) end' \
  -c 'qa' 2>&1
```
