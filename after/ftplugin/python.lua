-- Python ftplugin — text objects + snippets + docstring generator

require('snippets').enable_snippets()

local ok, t = pcall(require, 'text_objects')
if not ok then return end

local bmap = function(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { buffer = true, desc = desc })
end

-- Operator-pending text objects: work with any operator (d, y, c, v, etc.)
local function omap(lhs, rhs, desc)
  vim.keymap.set({ 'o', 'x' }, lhs, rhs, { buffer = true, desc = desc })
end

omap('if', function()
  local body = t.get_field(t.get_node('function_definition'), 'body')
  if body and #body > 0 then t.select_node(body[1]) end
end, 'Inner function body')

omap('af', function()
  local fn = t.get_node('function_definition')
  if fn then t.select_node(fn) end
end, 'Around function')

omap('ic', function()
  local body = t.get_field(t.get_node('class_definition'), 'body')
  if body and #body > 0 then t.select_node(body[1]) end
end, 'Inner class body')

omap('ac', function()
  local cls = t.get_node('class_definition')
  if cls then t.select_node(cls) end
end, 'Around class')

-- Navigation
bmap('gfn', function()
  local f = t.get_field(t.get_node('function_definition'), 'name')
  if f and #f > 0 then t.goto_node(f[1]) end
end, 'Jump to function name')

bmap('gcn', function()
  local f = t.get_field(t.get_node('class_definition'), 'name')
  if f and #f > 0 then t.goto_node(f[1]) end
end, 'Jump to class name')

bmap('gfp', function()
  local params = t.get_field(t.get_node('function_definition'), 'parameters')
  if params and #params > 0 then t.goto_node(t.get_next_child(params[1])) end
end, 'Cycle function parameters')

-- Auto-generate docstring from function signature
bmap('<leader>gd', function()
  local fn = t.get_node('function_definition')
  if not fn then return end
  local params = t.get_field(fn, 'parameters')
  if not params or #params < 1 then return end
  local body = t.get_field(fn, 'body')
  if not body or #body < 1 then return end
  local body_node = body[1]
  local row, col = body_node:range()
  local indent = string.rep(' ', col)

  -- Remove existing docstring if present
  local first = body_node:named_child(0)
  if first and first:type() == 'expression_statement' then
    local expr = first:named_child(0)
    if expr and expr:type() == 'string' then
      local sr, _, er, _ = expr:range()
      vim.api.nvim_buf_set_lines(0, sr, er + 1, false, {})
    end
  end

  local doc = { indent .. '"""${1:Description}', '' }
  local param_nodes = params[1]
  local n = param_nodes:named_child_count()
  local slot = 2

  if n > 0 then
    local has_params = false
    for i = 0, n - 1 do
      local name = vim.treesitter.get_node_text(param_nodes:named_child(i), 0)
      name = name:gsub('^%s*%*+', ''):match('^([%a_][%w_]*)')
      if name ~= 'self' then
        if not has_params then
          doc[#doc + 1] = indent .. 'Parameters'
          doc[#doc + 1] = indent .. '----------'
          has_params = true
        end
        doc[#doc + 1] = indent .. '`' .. name .. '`'
        doc[#doc + 1] = indent .. '${' .. slot .. ':description}'
        doc[#doc + 1] = ''
        slot = slot + 1
      end
    end
  end

  local ret = t.get_field(fn, 'return_type')
  if ret and #ret > 0 then
    local rtype = vim.treesitter.get_node_text(ret[1], 0)
    if rtype ~= 'None' then
      doc[#doc + 1] = indent .. 'Returns'
      doc[#doc + 1] = indent .. '-------'
      doc[#doc + 1] = indent .. '`' .. rtype .. '`'
      doc[#doc + 1] = indent .. '${' .. slot .. ':description}'
    else
      table.remove(doc)  -- remove trailing blank
    end
  end

  doc[#doc + 1] = indent .. '"""'

  vim.api.nvim_buf_set_lines(0, row, row, false, { '' })
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  vim.snippet.expand(table.concat(doc, '\n'))
end, 'Generate docstring')
