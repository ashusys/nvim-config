local s = {
  named_table       = { '${1:name} = {', '\t$0', '}' },
  protected_require = { 'local ${1:success}, ${2:variable} = pcall(require, "${3:module}")', 'if not ${1} then', '\tvim.notify("failed to load a module: $3")', '\treturn', 'end' },
}
for k, v in pairs(s) do s[k] = table.concat(v, '\n') end
return s
