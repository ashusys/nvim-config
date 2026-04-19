local s = {
  func      = { '(${1:}) => {$0}' },
  tag       = { '<${1:tag}$2>$0</$1>' },
  component = { '<${1:Component}/>' },
}
for k, v in pairs(s) do s[k] = table.concat(v, '\n') end
return s
