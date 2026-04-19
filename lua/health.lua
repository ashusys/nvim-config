local M = {}

local required = {
  { cmd = 'git',   purpose = 'Git integration (blame, diff, gitsigns)' },
  { cmd = 'rg',    purpose = 'Live grep (finder.lua, grepprg)' },
  { cmd = 'fd',    purpose = 'File finder (finder.lua)' },
  { cmd = 'fzf',   purpose = 'Fuzzy picker (finder.lua)' },
}

local optional = {
  { cmd = 'curl',                        purpose = 'REST client (rest.lua)' },
  { cmd = 'jq',                          purpose = 'JSON formatting in REST responses' },
  { cmd = 'prettierd',                   purpose = 'Fast prettier daemon — \\cf format and BufWritePre' },
  { cmd = 'tmux',                        purpose = 'Clipboard sync (TextYankPost)' },
  { cmd = 'vtsls',                       purpose = 'TypeScript/JavaScript LSP' },
  { cmd = 'pyright-langserver',          purpose = 'Python LSP (type checking)' },
  { cmd = 'ruff',                        purpose = 'Python LSP (linting/formatting)' },
  { cmd = 'vscode-eslint-language-server', purpose = 'ESLint LSP' },
  { cmd = 'vscode-json-language-server', purpose = 'JSON/JSONC LSP (hover, completion, validation)' },
  { cmd = 'bash-language-server',        purpose = 'Bash LSP' },
  { cmd = 'lua-language-server',         purpose = 'Lua LSP' },
  { cmd = 'marksman',                    purpose = 'Markdown LSP' },
  { cmd = 'yaml-language-server',        purpose = 'YAML LSP' },
  { cmd = 'bicep-langserver',            purpose = 'Bicep LSP' },
}

function M.check()
  vim.health.start('Neovim config')

  vim.health.info('Neovim ' .. tostring(vim.version()))
  vim.health.info('Config: ' .. vim.fn.stdpath('config'))

  if vim.loader.enabled then
    vim.health.ok('vim.loader enabled (bytecode cache)')
  else
    vim.health.warn('vim.loader not enabled')
  end

  vim.health.start('Required tools')
  for _, tool in ipairs(required) do
    if vim.fn.executable(tool.cmd) == 1 then
      vim.health.ok(tool.cmd .. ' — ' .. tool.purpose)
    else
      vim.health.error(tool.cmd .. ' not found — ' .. tool.purpose)
    end
  end

  vim.health.start('Optional tools')
  for _, tool in ipairs(optional) do
    if vim.fn.executable(tool.cmd) == 1 then
      vim.health.ok(tool.cmd .. ' — ' .. tool.purpose)
    else
      vim.health.info(tool.cmd .. ' not found — ' .. tool.purpose)
    end
  end

  vim.health.start('Config files')
  local editorignore = vim.fn.stdpath('config') .. '/.editorignore'
  if vim.fn.filereadable(editorignore) == 1 then
    vim.health.ok('.editorignore exists')
  else
    vim.health.warn('.editorignore not found — fd/rg ignore rules will be missing')
  end

  local undodir = vim.o.undodir
  if undodir and vim.fn.isdirectory(undodir) == 1 then
    vim.health.ok('undodir exists: ' .. undodir)
  else
    vim.health.info('undodir will be created on first save: ' .. (undodir or 'nil'))
  end
end

return M
