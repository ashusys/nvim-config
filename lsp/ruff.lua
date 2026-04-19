return {
  filetypes = { 'python' },
  cmd = { 'ruff', 'server' },
  root_markers = { '.git', 'pyproject.toml' },
  on_init = function(client)
    client.server_capabilities.hoverProvider = false
  end,
  init_options = {
    settings = {
      organizeImports = true,
      lint = {
        extendSelect = {
          'A', 'ARG', 'B', 'COM', 'C4', 'FBT', 'I', 'ICN',
          'N', 'PERF', 'PL', 'Q', 'RET', 'RUF', 'SIM', 'SLF', 'TID', 'W',
        },
      },
    },
  },
  settings = {},
}
