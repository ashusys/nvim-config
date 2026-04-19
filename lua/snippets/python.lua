local s = {
  class          = { 'class ${1:class_name}:', '\tdef __init__(self, *args, **kwargs):', '\t\tpass' },
  class_abstract = { 'class ${1:class_name}(${2:parent_name}):', '\t@abstractmethod', '\tdef __init__(self, *args, **kwargs):', '\t\tpass' },
  debug_entry    = { 'if not debugpy.is_client_connected():', '\tdebugpy.listen(("${1:0.0.0.0}", ${2:1234}))', '\tdebugpy.wait_for_client()', '\tdebugpy.breakpoint()' },
  break_point    = { 'debugpy.breakpoint()' },
}
for k, v in pairs(s) do s[k] = table.concat(v, '\n') end
return s
