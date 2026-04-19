# Installation

Step-by-step setup from zero to a working Neovim environment.

---

## 1. Install Neovim ≥ 0.12

Neovim 0.12 is required — this config uses `vim.pack` (native plugin
management), native completion/snippets, and several 0.12-only APIs.

**Recommended: [bob](https://github.com/MordechaiHadad/bob) (version manager)**

```sh
# Install bob
cargo install bob-nvim          # or: brew install bob, or grab the release binary

# Install and activate Neovim 0.12
bob install 0.12.1
bob use 0.12.1
```

**Alternative: build from source or grab an AppImage**

```sh
# AppImage (Linux)
curl -LO https://github.com/neovim/neovim/releases/download/v0.12.1/nvim-linux-x86_64.tar.gz
tar -xzf nvim-linux-x86_64.tar.gz
sudo mv nvim-linux-x86_64 /opt/nvim
echo 'export PATH="/opt/nvim/bin:$PATH"' >> ~/.bashrc
```

Verify:
```sh
nvim --version   # must say NVIM v0.12 or newer
```

---

## 2. Install Required Tools

These four tools must be present — the config fails silently (or noisily) without them.

| Tool | Install |
|------|---------|
| `git` | System package: `apt install git` / `brew install git` |
| `rg` (ripgrep) | `apt install ripgrep` / `brew install ripgrep` / `cargo install ripgrep` |
| `fd` | `apt install fd-find` / `brew install fd` / `cargo install fd-find` |
| `fzf` | `apt install fzf` / `brew install fzf` / `git clone https://github.com/junegunn/fzf ~/.fzf && ~/.fzf/install` |

> **Note for `fd` on Debian/Ubuntu:** the binary is named `fdfind`. Create a
> symlink: `ln -s $(which fdfind) ~/.local/bin/fd`

---

## 3. Clone the Config

```sh
# Option A: clone directly as your Neovim config
git clone https://github.com/ashusys/nvim-config.git ~/.config/nvim

# Option B: clone into a dotfiles repo and symlink
git clone https://github.com/ashusys/nvim-config.git ~/dotfiles/nvim-config
ln -s ~/dotfiles/nvim-config ~/.config/nvim

# Option C: download the latest release zip instead of cloning
# https://github.com/ashusys/nvim-config/releases/latest
```

---

## 4. Create Your Local Override

All machine-specific settings live in `lua/config/local.lua` (gitignored).
Copy the example and edit it:

```sh
cp ~/.config/nvim/lua/config/local.lua.example \
   ~/.config/nvim/lua/config/local.lua
```

Minimum recommended changes:

```lua
return {
  project_root = '~/myprojects',   -- root of your git repos (sessions + cache)
  max_threads  = 8,                -- set to your CPU count if different from auto-detect
}
```

See [`lua/config/local.lua.example`](lua/config/local.lua.example) for all
available keys and their defaults.

---

## 5. First Launch — Plugin Install

On first launch `vim.pack` downloads and installs all plugins automatically.
Open Neovim:

```sh
nvim
```

You will see install output. Wait for it to finish, then restart:

```sh
:qa
nvim
```

---

## 6. Install Optional Tools

Features degrade gracefully when optional tools are missing, but for the full
experience install the ones you need:

### Formatter

```sh
# prettierd (fast prettier daemon — used by \cf and format-on-save)
npm install -g @fsouza/prettierd
```

### LSP Servers

Each server has a config in `lsp/`. The server must be executable on `$PATH`
for its config to activate. Servers not installed are silently skipped.

**TypeScript / JavaScript**
```sh
npm install -g @vtsls/language-server
```

**Python**
```sh
pip install pyright
pip install ruff
```

**JSON / HTML / CSS / ESLint**
```sh
npm install -g vscode-langservers-extracted
```

**Bash**
```sh
npm install -g bash-language-server
```

**Lua**
```sh
# Arch: sudo pacman -S lua-language-server
# Homebrew: brew install lua-language-server
# Manual: https://github.com/LuaLS/lua-language-server/releases
```

**Markdown**
```sh
# Homebrew: brew install marksman
# Cargo: cargo install marksman
# Or download the release binary from https://github.com/artempyanykh/marksman
```

**YAML**
```sh
npm install -g yaml-language-server
```

**Bicep**
```sh
# Requires .NET; see https://github.com/azure/bicep for install instructions
```

**ESLint LSP** is shipped as `.disabled` by default (rename
`lsp/vscode-eslint-language-server.lua.disabled` →
`lsp/vscode-eslint-language-server.lua` to enable it).

---

## 7. Verify Installation

```
:checkhealth
```

This reports:
- Required tools (must all be OK)
- Optional tools (each shows WARN if missing, OK if found)
- Bytecode cache status
- Neovim version

---

## 8. WSL2 Notes

This config is developed on WSL2. A few things to be aware of:

**Clipboard:** The `\y` / `\p` system clipboard maps use `win32yank.exe` on
WSL2 automatically (set via Neovim's clipboard provider detection). No extra
configuration needed if `win32yank.exe` is on `$PATH`.

**`fd` performance:** On WSL2, `fd` is significantly faster on Linux
filesystem paths (`/home/…`) than on Windows mounts (`/mnt/c/…`). Keep repos
on the Linux filesystem for the best cache rebuild times.

**Socket latency:** Set `timeoutlen = 250` in your `local.lua` for WSL2 to
keep the leader key timeout comfortable even under load.

**tmux clipboard sync:** If you use tmux inside WSL2 for clipboard sync on
yank, install tmux (`sudo apt install tmux`) and `set -g set-clipboard on` in
your `tmux.conf`.

---

## 9. Updating

Plugins are managed by `vim.pack`. To update:

```
:packupdate
```

To update this config:

```sh
cd ~/.config/nvim   # or ~/dotfiles/nvim-config-config
git pull
```

Your `lua/config/local.lua` is gitignored and will not be touched by `git pull`.
