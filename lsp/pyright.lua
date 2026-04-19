return {
  filetypes = { 'python' },
  cmd = { 'pyright-langserver', '--stdio' },
  root_markers = { '.git', 'pyproject.toml' },
  settings = {
    pyright = { disableOrganizeImports = true },
    python = {
      analysis = {
        autoImportCompletions = false,
        autoSearchPaths = false,
        diagnosticMode = 'openFilesOnly',
        typeCheckingMode = 'standard',
        diagnosticSeverityOverrides = { reportPrivateImportUsage = 'none' },
      },
    },
  },
}
