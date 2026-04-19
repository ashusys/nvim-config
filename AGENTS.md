# AGENTS.md — AI Agent Instructions

This file tells AI coding agents (GitHub Copilot, Claude, Cursor, etc.) how
to work effectively with this codebase. Read it before making any changes.

---

## Project Summary

A performance-first Neovim 0.12 configuration. No plugin manager. Pure Lua.
Built-in LSP, completion, snippets, and treesitter. Pure black/white theme.
Engineered for zero startup cost and 100% reliability on large monorepos.

**Non-negotiables the agent must never violate:**
- Do not add a plugin manager (no lazy.nvim, packer, mini.deps).
- Do not remap single-key built-in Vim commands.
- Do not add color to the void colorscheme.
- Do not add unconditional startup cost — anything that isn't needed on the
  first frame must be deferred via `VimEnter + defer_fn` or lazy FileType/
  keypress loading.
- Do not replace built-in Neovim APIs with plugin equivalents.

---

## Codebase Navigation

```
init.lua                   boot sequence — start here
lua/config/init.lua        ALL tunable values with defaults
lua/config/local.lua       machine-specific overrides (gitignored, local only)
lua/config/local.lua.example  the publishable template for overrides
BRAIN.md                   full architecture, decisions, and fix history
KEYBINDINGS.md             user-facing keymap reference
PERFORMANCE.md             startup budget, tuning table, profiling recipes
```

The canonical module map is in [BRAIN.md § 3.3](BRAIN.md#33-module-map).
The full fix history is in [BRAIN.md § 10](BRAIN.md#10-all-fixes-applied-chronological).

---

## Before Making Changes

1. **Read `BRAIN.md`** for the affected module. Design decisions are
   documented there; many obvious-looking simplifications have already been
   tried and reverted for documented reasons.
2. **Read the file you are changing** in full before editing. Context matters.
3. **Check `lua/config/init.lua`** — if a value is hardcoded anywhere, it
   probably should be read from config instead.
4. **Check `:checkhealth`** output — the health module (`lua/health.lua`)
   is the source of truth for what tools are required vs optional.

---

## Key Architectural Invariants

### Load Order
```
Immediate: options → keymaps → autopairs → autocmds → statusline → colorscheme
VimEnter+0ms:  lsp
VimEnter+10ms: finder, fff, terminal, git, oil, resession
VimEnter+50ms: gitsigns, diffview
FileType http: rest.lua (lazy, once)
First keypress: opencode.nvim (lazy)
```
Do not move a module to an earlier phase without measuring the impact.
Do not call `require()` at module scope for modules in a later phase.

### Config System
All runtime values flow through `require('config')`. The return value is a
plain Lua table. Hardcoding paths, thread counts, or timing values directly
in modules (except as fallback) is a bug.

### Global State
Only two deliberate globals exist:
- `_G._toggle_msg(text)` — defined in `init.lua`, used by keymaps/autocmds
- `_G._blame_timer` — the `uv_timer_t` for inline git blame (prevents leaks
  on config reload)

Do not add new globals. Module-level upvalues are preferred.

### Error Handling
All `require()` calls for deferred modules use `pcall`. Missing or broken
modules must not crash the editor. Use `vim.notify(..., vim.log.levels.ERROR)`
for user-visible failures, `vim.notify(..., vim.log.levels.WARN)` for
degraded-but-still-useful states.

### Keymaps
- Use `vim.keymap.set` (not `vim.api.nvim_set_keymap`).
- Buffer-local maps go in the relevant `after/ftplugin/` file or inside an
  `LspAttach` / `FileType` autocmd callback.
- Follow the namespace conventions in [KEYBINDINGS.md](KEYBINDINGS.md).
- `noremap = true` (the default for `vim.keymap.set`) — never use `remap = true`
  unless there is a documented reason.

---

## How to Validate Changes

**Syntax / diagnostics:**
Open the file in Neovim with lua-language-server active, or run
`:lua dofile('path/to/file.lua')` in headless mode.

**Headless smoke test:**
```sh
nvim --headless -u init.lua -c 'lua print("OK")' -c 'qa' 2>&1
```

**Module load test (check a specific module):**
```sh
nvim --headless -u init.lua \
  -c 'lua local ok, m = pcall(require, "MODULE"); print(ok, type(m))' \
  -c 'qa' 2>&1
```

**Config values test:**
```sh
nvim --headless -u init.lua \
  -c 'lua local c=require("config"); print(c.home, c.max_threads, c.colorscheme)' \
  -c 'qa' 2>&1
```

**Full health check (interactive):**
```
:checkhealth
```

---

## Intentional Behaviors — Do Not "Fix" These

| Behavior | Location | Reason |
|----------|----------|--------|
| `\lR` restarts LSP globally | `lua/keymaps.lua` | Intentional global scope |
| `lua/config/local.lua` is gitignored | `.gitignore` | Machine-specific overrides must stay local |
| `o.autocomplete = false` | `lua/options.lua` | Prevents race with `LspAttach` autotrigger |
| Semantic tokens disabled | `lua/lsp.lua` | Conflicts with void theme treesitter highlighting |
| `clipboard` option not set | `lua/options.lua` | Explicit-only system clipboard via `\y`/`\p` |
| ESLint LSP config is `.disabled` | `lsp/` | Locally disabled; rename to enable |
| `format_on_save = false` default | `lua/autocmds.lua` | Off by default; toggle with `\tf` |

---

## Style Rules (Lua)

- 2-space indent, no tabs.
- `local function name()` before the public table that references it.
- `M.method = function()` style for exported functions.
- `vim.api.*` for all Neovim API calls — do not use deprecated `vim.fn`
  equivalents when a Lua API exists.
- String concatenation for short strings; `string.format` for anything with
  more than two parts.
- No trailing whitespace. No blank lines at end of file.
