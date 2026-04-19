return {
  filetypes = { 'yaml', 'yaml.docker-compose' },
  cmd = { 'yaml-language-server', '--stdio' },
  root_markers = { '.git' },
  settings = {
    yaml = {
      schemas = {
        kubernetes = '/*.yaml',
        ['http://json.schemastore.org/github-workflow'] = '.github/workflows/*',
        ['http://json.schemastore.org/github-action'] = '.github/action.{yml,yaml}',
        ['http://json.schemastore.org/prettierrc'] = '.prettierrc.{yml,yaml}',
        ['http://json.schemastore.org/kustomization'] = 'kustomization.{yml,yaml}',
        ['http://json.schemastore.org/chart'] = 'Chart.{yml,yaml}',
        ['https://json.schemastore.org/dependabot-v2'] = '.github/dependabot.{yml,yaml}',
      },
      format = { enable = true },
      validate = true,
      completion = true,
    },
  },
}
