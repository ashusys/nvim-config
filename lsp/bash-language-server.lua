return {
  filetypes = { 'sh', 'bash' },
  cmd = { 'bash-language-server', 'start' },
  root_markers = { '.git' },
  settings = {
    bashIde = { globPattern = '*@(.sh|.inc|.bash|.command)' },
  },
}
