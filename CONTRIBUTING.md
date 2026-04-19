# Contributing

Thanks for your interest. This is a personal daily-driver config, so
contributions are scoped accordingly — but well-considered fixes and
genuinely useful additions are welcome.

---

## Ground Rules

1. **Nothing that breaks the philosophy.**
   Read [README.md § Philosophy](README.md#philosophy) first. Changes that add
   color, add a plugin manager, override single-key built-ins, or introduce
   startup cost will not be merged.

2. **No plugin for something Neovim already does natively.**
   Neovim 0.12 has built-in LSP, completion, snippets, treesitter, diff, and
   sessions. Wrapping those with plugins is out of scope.

3. **Works 100% or not at all.**
   If a feature is conditional on a non-standard tool, it must degrade
   gracefully when that tool is absent. No silent errors, no partial states.

4. **Vim grammar is sacred.**
   Do not remap single-key built-ins. All custom maps must use a valid prefix
   (`<leader>`, `g`, `[`, `]`, `<C-*>`, `<A-*>`, `s-`).

---

## What Is Welcome

- **Bug fixes** — especially correctness bugs, race conditions, or API misuse.
- **New LSP server configs** in `lsp/` that follow the existing pattern
  (executable check, silent skip, no hard errors).
- **Performance improvements** that are measurable and do not add complexity.
- **Documentation improvements** — BRAIN.md, KEYBINDINGS.md, PERFORMANCE.md,
  or inline comments.
- **`after/ftplugin/` additions** for languages not yet covered, using only
  Vim-native or already-loaded tooling.

---

## What Is Not Welcome

- New plugins unless they have no native Neovim equivalent and provide a
  compelling, irreplaceable feature.
- Changes to the `void` colorscheme toward anything with color.
- Anything that increases startup time for the common case.
- Changes to `lua/config/local.lua` (this file is machine-local and gitignored).

---

## How to Submit a Fix

1. Fork the repo and create a branch from `main`.
2. Make the smallest change that fixes the problem.
3. Verify with `:checkhealth` and a headless smoke-test:
   ```sh
   nvim --headless -u init.lua -c 'lua print("OK")' -c 'qa'
   ```
4. Open a PR with a clear description of **what broke, why, and how you fixed it**.

---

## Code Style

- Lua files use 2-space indent throughout.
- Local functions before the public interface they serve.
- No global state except the deliberate `_G._toggle_msg` / `_G._blame_timer`
  exceptions documented in BRAIN.md.
- Module files return `M` (or nothing for side-effect-only files). No inline
  `require` calls at module scope unless the module is guaranteed loaded.
- Comments explain **why**, not **what**. Code should be self-evident.

---

## Architecture Reference

[BRAIN.md](BRAIN.md) is the canonical reference for design decisions, module
map, load phases, and all known fixes. Read it before touching anything
non-trivial.
