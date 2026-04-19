return {
  cmd        = { 'vscode-json-language-server', '--stdio' },
  filetypes  = { 'json', 'jsonc' },
  root_markers = { '.git' },
  init_options = {
    provideFormatter = false,  -- use prettierd for JSON formatting
  },
  settings = {
    json = {
      validate = { enable = true },
      format   = { enable = false },
    },
  },
}
