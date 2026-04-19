return {
  filetypes = { 'lua' },
  cmd = { 'lua-language-server' },
  root_markers = { '.git', '.luarc.json', '.luarc.jsonc', 'stylua.toml' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      diagnostics = { globals = { 'vim' } },
      workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
      telemetry = { enable = false },
      format = { enable = true, defaultConfig = { indent_style = 'space', indent_size = '2' } },
    },
  },
}
