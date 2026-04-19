-- ═════════════════════════════════════════════════════════════════════
--  Built-in LSP · Completion · Diagnostics · Snippets
--  Neovim 0.12 native — zero plugins
--  Server configs live in lsp/ directory (auto-loaded by nvim 0.12)
-- ═════════════════════════════════════════════════════════════════════

vim.lsp.log.set_level('ERROR')

-- ── LSP debounce ─────────────────────────────────────────────────────────
vim.lsp.config('*', {
  flags = { debounce_text_changes = require('config').lsp_debounce_ms },
})

-- ── Diagnostic display ──────────────────────────────────────────────
vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  virtual_lines = { current_line = true },
  severity_sort = true,
  update_in_insert = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN]  = '',
      [vim.diagnostic.severity.HINT]  = '',
      [vim.diagnostic.severity.INFO]  = '',
    },
    linehl = {
      [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
      [vim.diagnostic.severity.WARN]  = 'None',
      [vim.diagnostic.severity.HINT]  = 'None',
      [vim.diagnostic.severity.INFO]  = 'None',
    },
    numhl = {
      [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
      [vim.diagnostic.severity.WARN]  = 'WarningMsg',
      [vim.diagnostic.severity.HINT]  = 'DiagnosticHint',
      [vim.diagnostic.severity.INFO]  = 'DiagnosticHint',
    },
  },
  float = {
    title = ' Diagnostic ',
    header = '',
    border = 'single',
    scope = 'line',
    source = true,
  },
})

-- ── Enable servers whose binaries exist (configs live in lsp/) ──────
local lsp_servers = {
  { cmd = 'vtsls',                         name = 'vtsls' },
  { cmd = 'pyright-langserver',            name = 'pyright' },
  { cmd = 'ruff',                          name = 'ruff' },
  { cmd = 'vscode-eslint-language-server', name = 'vscode-eslint-language-server' },
  { cmd = 'bash-language-server',          name = 'bash-language-server' },
  { cmd = 'lua-language-server',           name = 'lua-language-server' },
  { cmd = 'marksman',                      name = 'marksman' },
  { cmd = 'yaml-language-server',          name = 'yaml-language-server' },
  { cmd = 'vscode-json-language-server',   name = 'vscode-json-language-server' },
  { cmd = 'bicep-langserver',              name = 'bicep-langserver' },
}

local function has_server_config(name)
  local path = vim.fn.stdpath('config') .. '/lsp/' .. name .. '.lua'
  return vim.fn.filereadable(path) == 1
end

-- Only enable servers that have both a binary in PATH and a live config file.
-- This keeps the lsp/ directory as the single source of truth for enable/disable.
for _, server in ipairs(lsp_servers) do
  if has_server_config(server.name) and vim.fn.executable(server.cmd) == 1 then
    vim.lsp.enable(server.name)
  end
end

-- ── LspAttach: keymaps + completion + disable semantic tokens ───────
-- Track what's been set up per-buffer to avoid duplicate autocmds
-- when multiple LSP clients attach (e.g. vtsls + eslint, pyright + ruff)
local buf_lsp_setup = {}
-- Single shared augroup for all buffer-scoped doc-highlight autocmds
local _lsp_hl_group = vim.api.nvim_create_augroup('LspDocHighlight', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('LspKeymaps', { clear = true }),
  callback = function(ev)
    local buf = ev.buf
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end

    -- Per-client: disable semantic tokens (always, every client)
    if client.server_capabilities then
      client.server_capabilities.semanticTokensProvider = nil
    end

    -- Per-client: completion (each client registers its own source)
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })
    end

    -- ── Everything below: ONCE per buffer (first client wins) ────
    if buf_lsp_setup[buf] then return end
    buf_lsp_setup[buf] = true

    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end

    -- 0.12 built-in LSP keymaps (zero overrides needed):
    --   grr references    gri implementations    gra code action
    --   grn rename        grt type definition     grx run codelens
    --   gO  doc symbols   K   hover               C-S signature help

    -- Smart gd: vtsls → goToSourceDefinition (skips imports + .d.ts), fallback normal
    bmap('n', 'gd', function()
      local clients = vim.lsp.get_clients({ bufnr = buf, name = 'vtsls' })
      if #clients > 0 then
        local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
        clients[1]:request('_typescript.goToSourceDefinition', params, function(err, result)
          if result and #result > 0 then
            vim.lsp.util.show_document(result[1], clients[1].offset_encoding, { focus = true })
          else
            vim.lsp.buf.definition()
          end
        end, buf)
      else
        vim.lsp.buf.definition()
      end
    end, 'Go to source definition')

    bmap('n', '<leader>ca', vim.lsp.buf.code_action,     'Code action')
    bmap('v', '<leader>ca', vim.lsp.buf.code_action,     'Code action (selection)')
    bmap('n', '<leader>cr', vim.lsp.buf.rename,           'Rename symbol')
    bmap('n', '<leader>cf', function()
      -- Prettierd first (matches VS Code default formatter), then LSP.
      -- 'formatted'  → changed the buffer; notify.
      -- 'unchanged'  → prettier applies to this ft but nothing changed; bail.
      -- false        → prettier not applicable (wrong ft / missing binary); use LSP.
      local fmt = require('format')
      local result = fmt.prettierd_format(buf)
      if result == 'formatted' then
        vim.notify('Formatted with prettier', vim.log.levels.INFO)
        return
      elseif result then  -- 'unchanged' or any truthy non-'formatted'
        return
      end
      vim.lsp.buf.format({ async = true })
    end, 'Format buffer (prettier/LSP)')
    bmap('n', '<leader>co', vim.lsp.buf.document_symbol,  'Document symbols')
    bmap('n', '<leader>cO', vim.lsp.buf.workspace_symbol, 'Workspace symbols')
    bmap('n', '<leader>ci', vim.lsp.buf.incoming_calls,   'Incoming calls')
    bmap('n', '<leader>cI', vim.lsp.buf.outgoing_calls,   'Outgoing calls')
    -- typehierarchy: API name differs across 0.12 builds
    local _typehier = vim.lsp.buf.typehierarchy or vim.lsp.buf.type_hierarchy
    if _typehier then bmap('n', '<leader>ch', _typehier, 'Type hierarchy') end

    -- Document highlight (only when client supports it — avoids wasted LSP requests)
    if client:supports_method('textDocument/documentHighlight') then
      local _last_hl_word = ''
      vim.api.nvim_create_autocmd('CursorHold', {
        group = _lsp_hl_group,
        buffer = buf,
        callback = function()
          local word = vim.fn.expand('<cword>')
          if word == '' then
            if _last_hl_word ~= '' then
              _last_hl_word = ''
              vim.lsp.buf.clear_references()
            end
            return
          end
          if word == _last_hl_word then return end
          _last_hl_word = word
          vim.lsp.buf.clear_references()
          vim.lsp.buf.document_highlight()
        end,
      })
      vim.api.nvim_create_autocmd('InsertEnter', {
        group = _lsp_hl_group,
        buffer = buf,
        callback = function()
          _last_hl_word = ''
          vim.lsp.buf.clear_references()
        end,
      })
      vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
        group = _lsp_hl_group,
        buffer = buf,
        once = true,
        callback = function()
          pcall(vim.api.nvim_clear_autocmds, { group = _lsp_hl_group, buffer = buf })
        end,
      })
    end

    -- Folding — LSP folds when available (use attaching client directly)
    if client:supports_method('textDocument/foldingRange') then
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_is_valid(win) then
          vim.wo[win].foldmethod = 'expr'
          vim.wo[win].foldexpr = 'v:lua.vim.lsp.foldexpr()'
        end
      end
    end
  end,
})

-- Clean up buf_lsp_setup when buffer is wiped OR when all LSP clients detach.
-- LspDetach fires per-client; only clear when no clients remain so a
-- second client on the same buffer still gets its own setup pass.
vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
  group = vim.api.nvim_create_augroup('LspSetupCleanup', { clear = true }),
  callback = function(ev) buf_lsp_setup[ev.buf] = nil end,
})
vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('LspSetupDetach', { clear = true }),
  callback = function(ev)
    if #vim.lsp.get_clients({ bufnr = ev.buf }) == 0 then
      buf_lsp_setup[ev.buf] = nil
    end
  end,
})

-- ── LSP indexing progress indicator ────────────────────────────────
-- Shows "LSP: indexing..." in the cmdline area while servers are busy.
local _lsp_progress = {}
vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('LspProgressStatus', { clear = true }),
  callback = function(ev)
    local p = ev.data and ev.data.params and ev.data.params.value
    if not p then return end
    local key = ev.data.client_id .. ':' .. (p.token or '')
    if p.kind == 'end' or (p.percentage and p.percentage >= 100) then
      _lsp_progress[key] = nil
    else
      local msg = p.title or p.message or ''
      if msg ~= '' then _lsp_progress[key] = msg end
    end
    local items = vim.tbl_values(_lsp_progress)
    if #items > 0 then
      vim.api.nvim_echo({ { 'LSP: ' .. items[1], 'Comment' } }, false, {})
    else
      vim.api.nvim_echo({ { '', 'Normal' } }, false, {})  -- clear stale message
    end
  end,
})

-- ── LSP refresh / stop ──────────────────────────────────────────────
vim.keymap.set('n', '<leader>lR', function()
  -- Collect only buffers that currently have LSP clients attached
  local lsp_bufs = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
      lsp_bufs[bufnr] = true
    end
  end

  vim.lsp.stop_client(vim.lsp.get_clients(), true)

  vim.defer_fn(function()
    -- Reload LSP buffers. Do NOT silently save — the user controls when to write.
    for bufnr in pairs(lsp_bufs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_call, bufnr, function() vim.cmd('edit') end)
      end
    end
  end, 100)
end, { desc = 'Refresh LSP' })

vim.keymap.set('n', '<leader>lS', function()
  vim.lsp.stop_client(vim.lsp.get_clients())
end, { desc = 'Stop all LSP' })

-- Toggle inlay hints — handled in keymaps.lua as <leader>ti
-- Snippet navigation: handled in keymaps.lua (Tab/S-Tab with full
-- snippet → completion → indent chain). No duplicates here.
