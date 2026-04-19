# Security Policy

## Scope

This repository is a personal Neovim configuration. It contains no server
components, no network services, and no credential handling in its own code.
Security concerns here are limited to:

1. **Plugin supply chain** — plugins are fetched by `vim.pack` from GitHub
   over HTTPS. Commit hashes are locked in `nvim-pack-lock.json`.
2. **LSP server execution** — LSP binaries are resolved from `$PATH` at
   startup. A malicious binary on `$PATH` would run with your privileges.
3. **REST client** (`plugins/rest.lua`) — reads local `.env` files and passes
   their values as curl arguments. A malicious `.env` file in a project could
   inject curl flags.
4. **`lua/config/local.lua`** — executed as Lua on startup. This file is
   intentionally gitignored; do not commit sensitive values here and do not
   accept a `local.lua` from an untrusted source.
5. **External tool execution** — `git`, `fd`, `rg`, `fzf`, `prettierd`,
   `ionice`, and LSP servers are spawned via `vim.system`. Only tools
   resolved from `$PATH` by name are invoked.

---

## Reporting a Vulnerability

If you find a security issue (e.g. a vector for remote code execution through
the REST client, a plugin loading issue, or an unsafe default that could
affect other users), please:

1. **Do not open a public issue.**
2. Open a [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
   on this repository (Settings → Security → Advisories → New draft advisory).
3. Include:
   - A description of the issue and the affected component
   - Steps to reproduce
   - Potential impact
   - A suggested fix if you have one

I will respond as quickly as practical. There are no SLA commitments for a
personal config.

---

## Supported Versions

Only the current `master` branch is supported. There are no versioned releases
with ongoing security maintenance.

---

## Dependency Management

Plugins are pinned by commit hash in `nvim-pack-lock.json`. Before running
`:packupdate` on a machine you care about, review the diff to `nvim-pack-lock.json`
and inspect any changed plugin source if it handles untrusted data.

To audit current plugin URLs and locked commits:

```sh
cat nvim-pack-lock.json
```

To check for known vulnerabilities in npm-installed LSP servers (if you use
`npm install -g` for servers like `vtsls` or `bash-language-server`):

```sh
npm audit
```

---

## Known Non-Issues

- **`eval` / `loadstring` in plugins**: not used in this config's own Lua code.
- **Clipboard access**: system clipboard is only accessed on explicit user
  action (`\y`, `\p`). The `clipboard` option is intentionally unset.
- **Network requests**: only made by `vim.pack` (plugin install/update, over
  HTTPS) and the REST client (`plugins/rest.lua`, on explicit user invocation).
  No telemetry, no automatic outbound connections.
