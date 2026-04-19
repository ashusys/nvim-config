# Keybindings — Neovim 0.12

Leader: `<Space>` · Plugins: oil.nvim, gitsigns.nvim, diffview.nvim, resession.nvim, fff.nvim, opencode.nvim · LSP: vtsls, pyright, ruff, json-ls, lua-ls, yaml-ls, bash-ls, marksman, bicep

---

## Architecture

- Vim grammar is sacred — no built-in single-key commands overridden
- Custom maps only use prefix keys: `g` `[` `]` `<leader>` `<C-*>` `<S-*>` `<A-*>`
- Zero timeout conflicts: if `\X` has sub-keys `\XY`, then `\X` alone does nothing
- s-prefix: right-hand second keys for plugins (all set after deferred load)
- `<A-*>`: Alt combos for treesitter selection, diff, inlay hints

## Normal Mode — Core

| Key | Action |
|-----|--------|
| `x` / `X` | Delete char to void register |
| `q` | Disabled (use `Q` for macros, `qq` for smart quit) |
| `Q` | Record macro |
| `Esc` | Clear search highlight |
| `j` / `k` | Smart — `gj`/`gk` without count, normal with count |
| `J` | Join lines (cursor stays) |
| `n` / `N` | Next/prev search (centered + history) |
| `C-d` / `C-u` | Half-page scroll (centered) |
| `gb` | Go back (jumplist — like Alt+- in VSCode) |
| `gz` | Revert buffer to disk |

## Clipboard

No `clipboard=unnamedplus` — yanks stay in `"` register. System clipboard is explicit:

| Key | Action |
|-----|--------|
| `\y` | Yank to system clipboard |
| `\Y` | Yank line to system clipboard |
| `\p` | Paste from system clipboard |
| `\P` | Paste before from system clipboard |

## Save / Quit

| Key | Action |
|-----|--------|
| `C-s` | Save (normal + insert) |
| `\w` | Save |
| `\q` | Quit window |
| `qq` | Smart quit — closes special buffers, exits editor on normal buffers |
| `\Q` | Force quit all |

## File Explorer (oil.nvim)

| Key | Action |
|-----|--------|
| `-` | Open parent directory |
| `\e` | Toggle sidebar |
| `si` | Toggle sidebar (s-prefix alias) |

### Inside oil buffer

| Key | Action |
|-----|--------|
| `l` / `CR` | Enter dir / open file in main window |
| `h` / `-` / `BS` | Parent directory |
| `C-v` | Open in vsplit |
| `C-x` | Open in hsplit |
| `C-t` | Open in tab |
| `C-p` | Preview |
| `C-l` | Refresh |
| `C-c` / `q` | Close |
| `_` | Open cwd |
| `` ` `` | cd to dir |
| `~` | cd tab scope |
| `gs` | Change sort |
| `gx` | Open external |
| `g.` | Toggle hidden |
| `g\` | Toggle trash |
| `g?` | Help |

## s-prefix (right-hand second keys)

| Key | Action |
|-----|--------|
| `sb` | Buffer list (MRU picker) |
| `sd` | Diffview: repo changes (index) |
| `se` | Diffview: repo changes vs HEAD |
| `sf` | Diffview: file history |
| `sg` | Diffview: branch history |
| `sh` | Diff vs HEAD (in-memory, iwhite) |
| `si` | File explorer sidebar |
| `sk` | Live grep (fff) |
| `sl` | Find files (fff) |
| `so` | Floating terminal |
| `sq` | Quit window |
| `sr` | Session restore |
| `ss` | Session save |
| `su` | Revert to saved |
| `sw` | Toggle hard wrap 80 |
| `sx` | Close diffview |
| `sz` | Revert file to last commit (git checkout HEAD) |
| `s1` | Cycle windows |

## Find (`\f*`) — fff.nvim / fzf

| Key | Alias | Action |
|-----|-------|--------|
| `\ff` | `go`, `sl` | Find files (fff — frecency ranked, git-aware) |
| `\fd` | | Find git diff (compare against branch) |
| `\fw` | | Find git working (staged & unstaged) |
| `\fa` | | Filter arglist |
| `\fb` | | Find buffer (native `:ls`) |
| `\fn` | | Find native (`:find`) |
| `\fl` | | Newer quickfix list |
| `\fh` | | Older quickfix list |

## Grep (`\g*`) — fff.nvim / rg

| Key | Alias | Action |
|-----|-------|--------|
| `\gg` | `ga`, `sk`, `\/` | Live grep — plain/regex/fuzzy modes |
| `\gG` | | Live grep (regex mode forced) |
| `\gc` | | Grep word under cursor (fff) |
| `\ga` | | Grep arglist (fzf) |
| `\gb` | | Grep buffer lines (fzf) |
| `\gq` | | Refine quickfix (fzf filter) |
| `\gn` | | Grep word under cursor (native) |

## Buffers

| Key | Action |
|-----|--------|
| `C-n` / `S-l` | Next buffer |
| `C-p` / `S-h` | Previous buffer |
| `]b` / `\Tab` | Next MRU buffer |
| `[b` | Previous MRU buffer |
| `\bl` | Buffer list — MRU picker (native `vim.ui.select`) |
| `sb` | Buffer list — MRU picker (s-prefix alias) |
| `\bb` | Buffer picker (fzf) |
| `\bd` | Delete buffer (window-safe) |
| `\bD` | Delete all other buffers |

## Windows

| Key | Action |
|-----|--------|
| `C-h/j/k/l` | Navigate windows |
| `\1` / `s1` | Cycle windows |
| `\v` | Vertical split |
| `\H` | Horizontal split |
| `C-Up/Down` | Resize height ±2 |
| `C-Left/Right` | Resize width ±2 |

## Code (`\c*`) — LSP (buffer-local on attach)

| Key | Action |
|-----|--------|
| `\ca` | Code action (normal + visual) |
| `\cr` | Rename symbol |
| `\cf` | Format buffer — prettier first, LSP fallback |
| `\co` | Document symbols |
| `\cO` | Workspace symbols |
| `\ci` | Incoming calls |
| `\cI` | Outgoing calls |
| `\ch` | Type hierarchy |
| `\cd` | lcd to file directory |

### Nvim 0.12 built-in LSP (no config needed)

| Key | Action |
|-----|--------|
| `gd` | Smart definition (vtsls: source def, skips imports/.d.ts) |
| `grr` | References |
| `gri` | Implementations |
| `gra` | Code action |
| `grn` | Rename |
| `grt` | Type definition |
| `grx` | Run codelens |
| `gO` | Document symbols |
| `K` | Hover |
| `C-S` | Signature help (insert) |

## LSP Management (`\l*`)

| Key | Action |
|-----|--------|
| `\lR` | Restart all LSP clients |
| `\lS` | Stop all LSP clients |

## Diagnostics

Diagnostics show on current line by default (Error Lens style — `virtual_lines = current_line`).

| Key | Action |
|-----|--------|
| `]d` / `[d` | Next/prev diagnostic (built-in) |
| `gl` | Diagnostic float |
| `gK` | Toggle virtual lines (current line on/off) |
| `gh` | Copy diagnostic message to clipboard |

## Inlay Hints

| Key | Action |
|-----|--------|
| `\ti` | Toggle inlay hints (permanent on/off) |
| `A-=` | Peek inlay hints — show until cursor moves |

## Search / Replace (`\s*`)

| Key | Action |
|-----|--------|
| `\sa` | Highlight word under cursor |
| `\sd` | Clear quickfix list |
| `\sf` | Feed current line to quickfix |
| `\sp` | Replace in quickfix (`:cdo`) |
| `\sr` | Replace in quickfix files (`:cfdo`) |
| `\sq` | Diagnostics → quickfix |
| `\sc` | Filter quickfix (cfilter) |

## Quickfix / Location List

| Key | Action |
|-----|--------|
| `\j` | Open quickfix |
| `\J` | Close quickfix |
| `]q` / `[q` | Next/prev quickfix item (wraps) |
| `]Q` / `[Q` | Newer/older quickfix list |
| `]l` / `[l` | Next/prev location list |
| `]a` / `[a` | Next/prev arglist |

## Toggles (`\t*`)

| Key | Action |
|-----|--------|
| `\tb` | Toggle git blame (inline ghost text) |
| `\td` | Toggle diagnostic virtual text |
| `\tf` | Toggle format-on-save (**OFF by default**) — changed hunks only, LSP rangeFormatting |
| `\th` | Toggle hlsearch |
| `\ti` | Toggle inlay hints |
| `\tn` | Toggle line numbers |
| `\tr` | Toggle relative numbers |
| `\ts` | Toggle statusline |
| `\tw` | Toggle dynamic wrap |
| `sw` | Toggle hard wrap at 80 cols (s-prefix) |
| `A-=` | Peek inlay hints until cursor moves |

## Git (`\G*`)

| Key | Action |
|-----|--------|
| `\Gs` | Git status (float) |
| `\Ga` | Stage current file |
| `\GA` | Stage all (`git add -A`) |
| `\Gc` | Commit (prompt) |
| `\Gp` | Push |
| `\Gl` | Git log (current file) |
| `\Gd` | Diffview: repo changes (index) |
| `\Ge` | Diffview: repo changes vs HEAD |
| `\Gh` | Diffview: current file history |
| `\Gf` | Diffview: full branch history |
| `\Gx` | Diffview: close |
| `A-d` | Diff vs HEAD (in-memory, iwhite) |
| `\D` | Difftool vs HEAD (builtin 0.12) |

### Diffview (inside view)

| Key | Action |
|-----|--------|
| `-` / `s` | Stage / unstage file |
| `S` | Stage all |
| `U` | Unstage all |
| `X` | Restore file (discard changes) |
| `Tab` / `S-Tab` | Next / prev file |
| `L` | Open commit log |
| `i` | Toggle list / tree view |
| `g?` | Help panel |

## Sessions (`\S*`) — resession.nvim

| Key | Action |
|-----|--------|
| `\Ss` | Save session |
| `\Sl` | Load session |
| `\Sd` | Delete session |
| `\Sc` | Show current session name |
| `ss` | Session save (s-prefix) |
| `sr` | Session restore / load (s-prefix) |

Auto-sessions: saves/loads per git repo basename for first-level dirs under `config.project_root`.

## Hunks (`\h*`) — gitsigns

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next/prev hunk |
| `\hs` | Stage hunk (normal + visual) |
| `\hr` | Reset hunk (normal + visual) |
| `\hS` | Stage buffer |
| `\hu` | Undo stage hunk |
| `\hR` | Reset buffer |
| `\hp` | Preview hunk |
| `\hd` | Diff this |
| `\hD` | Diff this (`~`) |
| `ih` | Select hunk (operator-pending / visual) |

## Terminal

| Key | Action |
|-----|--------|
| `\tt` | Toggle floating terminal |
| `\q` (terminal mode) | Toggle floating terminal (close from inside) |
| `so` | Toggle floating terminal (s-prefix) |
| `Esc Esc` / `qq` | Exit terminal mode |
| `C-h/j/k/l` | Navigate to adjacent window (from terminal) |

## Opencode (`\o*`)

| Key | Mode | Action |
|-----|------|--------|
| `C-.` | n/t | Toggle opencode panel |
| `\oa` | n/x | Ask opencode about selection/cursor |
| `\os` | n/x | Opencode action picker |
| `\oo` | n/x | Opencode operator (send range) |
| `\oe` | n/x | Explain |
| `\or` | n/x | Review |
| `\of` | n/x | Fix |
| `\ot` | n/x | Generate tests |
| `\od` | n/x | Generate docs |
| `\oi` | n/x | Implement |
| `S-C-d` | n | Scroll opencode messages down |
| `S-C-u` | n | Scroll opencode messages up |

## REST Client (`\k*`) — buffer-local in `.http` files

| Key | Action |
|-----|--------|
| `\kr` | Run request under cursor |
| `\kl` | Re-run last request |
| `\ke` | Select environment (local/dev/uat/prod) |

## Builtin Plugins

| Key | Action |
|-----|--------|
| `\u` | Undotree |
| `\dd` | DiffTool (nvim 0.12 built-in) |

## Treesitter — Incremental Selection

| Key | Mode | Action |
|-----|------|--------|
| `A-o` | n/x/o | Expand selection to parent node (LSP fallback) |
| `A-i` | n/x/o | Shrink selection to child node (LSP fallback) |
| `an` | o/x | Around node (built-in text object) |
| `in` | o/x | Inner node |
| `]n` / `[n` | n | Next/prev sibling node |

## Visual Mode

| Key | Action |
|-----|--------|
| `J` / `K` | Move selection down/up |
| `H` / `L` | Dedent/indent (reselect) |
| `<` / `>` | Indent (reselect) |
| `p` | Paste (keep register) |
| `\d` | Delete to void register |
| `\i` | Multi-cursor at line starts |
| `\a` | Multi-cursor at line ends |
| `S"` `S'` `` S` `` `S(` `S[` `S{` | Surround selection with pair |

## Insert Mode

| Key | Action |
|-----|--------|
| `C-s` | Save |
| `C-v` | Paste from clipboard |
| `C-Space` | Trigger native LSP completion |
| `Tab` | Snippet jump → completion next → indent |
| `S-Tab` | Snippet back → completion prev |
| `CR` | Confirm completion or newline |
| `Esc` | Dismiss completion or escape |
| Auto-pairs | `()` `[]` `{}` `""` `''` `` `` `` — auto-close, skip-over, backspace-delete |

## Terminal Mode

| Key | Action |
|-----|--------|
| `\tt` | Toggle floating terminal (from normal mode) |
| `\q` | Close terminal (from inside terminal) |
| `Esc Esc` / `qq` | Exit terminal mode → normal mode |
| `C-h/j/k/l` | Navigate to window from terminal |

## JS/TS Text Objects (buffer-local)

| Key | Mode | Action |
|-----|------|--------|
| `ie` | o/x | Select JSX element |
| `die` | n | Delete JSX element |
| `yie` | n | Yank JSX element |
| `gcn` | n | Jump to class name |
| `gmn` | n | Jump to method name |
| `gvn` | n | Jump to variable name |
| `gto` | n | Jump to JSX open tag |
| `gtc` | n | Jump to JSX close tag |

## Python Text Objects (buffer-local)

| Key | Mode | Action |
|-----|------|--------|
| `if` / `af` | o/x | Inner/around function |
| `ic` / `ac` | o/x | Inner/around class |
| `gfn` | n | Jump to function name |
| `gcn` | n | Jump to class name |
| `gfp` | n | Cycle function parameters |
| `\gd` | n | Generate docstring (snippet) |

## Better Comments (treesitter highlights)

Comment prefixes that trigger colored highlight groups:

| Pattern | Highlight | Color (void theme) |
|---------|-----------|-------------------|
| `// TODO` / `# TODO` / `-- TODO` | `@comment.warning` | black on fg |
| `// WARN` / `# WARN` | `@comment.warning` | black on fg |
| `// FIXME` / `BUGS` | `@comment.error` | black on bright |
| `// !` / `# !` / `-- !` | `@comment.error` | black on bright |
| `// ?` / `# ?` / `-- ?` | `@comment.note` | bold italic fg |
| `// *` / `# *` / `-- *` | `@comment.todo` | bright on muted |
| `// NOTE` | `@comment.note` | bold italic fg |

## Commands

| Command | Action |
|---------|--------|
| `:FormatToggle` | Toggle format-on-save (global, **OFF by default**) — formats changed hunks only via LSP rangeFormatting |
| `:FormatToggleBuffer` | Toggle format-on-save (current buffer) |
| `:BlameToggle` | Toggle inline git blame ghost text |
| `:WrapToggle` | Toggle dynamic wrap |
| `:ConfigEdit` | Edit init.lua |
| `:ConfigReload` | Reload config |

## Folding (native)

| Key | Action |
|-----|--------|
| `za` | Toggle fold |
| `zo` / `zc` | Open / close fold |
| `zR` / `zM` | Open all / close all |
| `zr` / `zm` | Open/close one level |
