-- ─────────────────────────────────────────────────────────────────────────────
-- lua/format.lua — shared formatter helpers
--
-- Centralises prettierd_format so it can be required from both autocmds.lua
-- (BufWritePre) and lsp.lua (\cf keymap) without a _G global.
-- ─────────────────────────────────────────────────────────────────────────────

local M = {}

-- Filetypes that prettierd handles (matches esbenp.prettier-vscode defaults).
local prettier_ft = {
  javascript = true, javascriptreact = true, typescript = true, typescriptreact = true,
  json = true, jsonc = true, html = true, css = true, scss = true, less = true,
  graphql = true, markdown = true, yaml = true, vue = true, svelte = true,
  handlebars = true,
}

-- Circuit breaker: disable prettierd for this session after 3 consecutive failures.
local _fail_count = 0
local _FAIL_MAX = 3

--- Run prettierd on a buffer (sync).
--- Returns:
---   'formatted'  — ran and changed the buffer
---   'unchanged'  — ran but content already matched (no buffer mutation)
---   false        — not applicable (wrong ft, no executable, error, …)
function M.prettierd_format(bufnr)
  if vim.fn.executable('prettierd') ~= 1 then return false end
  if _fail_count >= _FAIL_MAX then return false end
  if not prettier_ft[vim.bo[bufnr].filetype] then return false end
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == '' then return false end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local result = vim.system(
    { 'prettierd', fname },
    { stdin = table.concat(lines, '\n') .. '\n', timeout = require('config').prettierd_timeout }
  ):wait()
  if result.code ~= 0 then
    _fail_count = _fail_count + 1
    local msg = (result.stderr and result.stderr ~= '') and vim.trim(result.stderr) or 'non-zero exit'
    if _fail_count >= _FAIL_MAX then
      vim.notify('prettierd failed ' .. _FAIL_MAX .. 'x (' .. msg .. '), disabling for this session', vim.log.levels.WARN)
    else
      vim.notify('prettierd: ' .. msg, vim.log.levels.WARN)
    end
    return false
  end
  _fail_count = 0
  local new_lines = vim.split(result.stdout, '\n', { plain = true })
  -- prettierd always appends a trailing newline; trim the empty last element
  if new_lines[#new_lines] == '' then new_lines[#new_lines] = nil end
  -- Skip buffer mutation when nothing changed (avoids marking buffer modified)
  if #new_lines == #lines then
    local same = true
    for i, l in ipairs(lines) do
      if l ~= new_lines[i] then same = false; break end
    end
    if same then return 'unchanged' end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  return 'formatted'
end

return M
