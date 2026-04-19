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

--- Run prettierd on a buffer (sync).
--- Returns:
---   'formatted'  — ran and changed the buffer
---   'unchanged'  — ran but content already matched (no buffer mutation)
---   false        — not applicable (wrong ft, no executable, error, …)
function M.prettierd_format(bufnr)
  if vim.fn.executable('prettierd') ~= 1 then return false end
  if not prettier_ft[vim.bo[bufnr].filetype] then return false end
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == '' then return false end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local result = vim.system(
    { 'prettierd', fname },
    { stdin = table.concat(lines, '\n') .. '\n', timeout = require('config').prettierd_timeout }
  ):wait()
  if result.code ~= 0 then return false end
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
