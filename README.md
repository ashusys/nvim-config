# nvim

[![CI](https://github.com/ashut0shk/nvim-config/actions/workflows/ci.yml/badge.svg)](https://github.com/ashut0shk/nvim-config/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ashut0shk/nvim-config?display_name=tag&sort=semver)](https://github.com/ashut0shk/nvim-config/releases)
[![Downloads](https://img.shields.io/github/downloads/ashut0shk/nvim-config/total)](https://github.com/ashut0shk/nvim-config/releases)
[![License](https://img.shields.io/github/license/ashut0shk/nvim-config)](https://github.com/ashut0shk/nvim-config/blob/main/LICENSE.txt)
[![Neovim](https://img.shields.io/badge/Neovim-0.12%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

> Neovim 0.12 · zero lazy.nvim · built-in LSP · pure black & white

A performance-first Neovim configuration engineered to replace VS Code as a
daily driver on large monorepos. No plugin manager. No color. No compromise.

---

## Philosophy

- **Zero startup overhead.** Everything that doesn't need to exist on the first
  frame doesn't run until after it — in ordered deferred phases.
- **Built-in first.** No plugin if Neovim already does it natively (LSP,
  completion, snippets, treesitter folding, diff, sessions).
- **Works 100% of the time.** Features are removed before they are tolerated
  as flaky.
- **Vim grammar is sacred.** No single-key built-in is remapped. All custom
  maps use prefix keys (`<leader>`, `g`, `[`, `]`, `<C-*>`, `<A-*>`, `s-`).
- **Pure black and white.** The `void` colorscheme uses only `#000000` and
  `#ffffff`. Focus, not furniture.

---

## Requirements

| Tool | Purpose | Required? |
|------|---------|-----------|
| Neovim ≥ 0.12 | config uses `vim.pack`, native completion/snippets | **required** |
| `git` | blame, diff, session names, gitsigns | **required** |
| `rg` (ripgrep) | live grep (`\gg`, `grepprg`) | **required** |
| `fd` | file finder, cache builder | **required** |
| `fzf` | picker UI (`\ff`, `\fw`, …) | **required** |
| `prettierd` | format on save / `\cf` | optional |
| `tmux` | clipboard sync on yank | optional |
| `ionice` | background cache priority | optional |

LSP servers are **all optional** — missing binaries are silently skipped.
See [INSTALL.md](INSTALL.md) for full setup instructions.

---

## Quick Start

```sh
git clone https://github.com/ashut0shk/nvim-config.git ~/.config/nvim
nvim   # vim.pack installs plugins on first launch
```

Copy the local override template and adjust for your machine:

```sh
cp ~/.config/nvim/lua/config/local.lua.example \
   ~/.config/nvim/lua/config/local.lua
```

## Releases

Tagged releases publish two ready-to-download assets on the GitHub Releases page:

- `nvim-config-<tag>.zip` — consumer-friendly archive for direct installation
- `nvim-config-<tag>.zip.sha256` — checksum for integrity verification

If you prefer not to clone the repo, download the latest release, unzip it,
and place the extracted `nvim-config/` contents into `~/.config/nvim`.

---

## Structure

```
init.lua                  boot: immediate + deferred phases
lua/
  config/
    init.lua              central defaults (all tunable values)
    local.lua.example     per-machine override template
  options.lua             all vim.o settings
  keymaps.lua             all keymaps + MRU tracker
  autocmds.lua            autocmds + format-on-save + BufView
  autopairs.lua           pure-Lua bracket/quote pairing
  statusline.lua          event-driven statusline (no plugin)
  lsp.lua                 LSP attach, diagnostics, completion
  git.lua                 inline blame, Alt+d diff, workflow
  finder.lua              fzf pickers (\f* \g* namespace)
  terminal.lua            floating per-tab terminal
  format.lua              prettierd shared module
  text_objects.lua        treesitter structural editing
  utils/git_root.lua      shared LRU git-root cache
  plugins/                deferred plugin wrappers
lsp/                      per-server config files
after/ftplugin/           per-filetype keymaps
colors/void.lua           pure black/white theme
queries/                  custom treesitter highlights
```

---

## Key Maps (overview)

Full reference: [KEYBINDINGS.md](KEYBINDINGS.md)

| Prefix | Domain |
|--------|--------|
| `<leader>f*` | Find files |
| `<leader>g*` | Grep |
| `<leader>b*` | Buffers |
| `<leader>c*` | Code / LSP |
| `<leader>G*` | Git workflow |
| `<leader>h*` | Hunks (gitsigns) |
| `<leader>t*` | Toggles |
| `<leader>l*` | LSP control |
| `<leader>S*` | Sessions |
| `s-*` | Plugin shortcuts (right-hand) |
| `g*` | Go-to (LSP-extended Vim-native) |

---

## Configuration

All tunable values live in `lua/config/init.lua` (defaults) and are
overridden per machine in `lua/config/local.lua` (gitignored).

```lua
-- lua/config/local.lua  (example)
return {
  project_root = '~/myprojects',   -- for sessions + file cache
  max_threads  = 8,                -- thread pool size
  colorscheme  = 'habamax',        -- override the void theme
  timeoutlen   = 300,
}
```

See [`lua/config/local.lua.example`](lua/config/local.lua.example) for all
available keys.

---

## Performance

Cold start on a 28-core WSL2 machine: **< 30 ms** with bytecode cache enabled.

See [PERFORMANCE.md](PERFORMANCE.md) for targets, measurements, and tuning
notes.

---

## Health Check

```
:checkhealth
```

Reports missing required tools, optional LSP server status, config validation,
and current tuning values.

---

## License

GPLv3 — see [LICENSE](LICENSE.txt).
