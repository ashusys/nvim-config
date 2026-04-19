-- Shared JS/TS ftplugin — text objects + snippets + errorformat
-- Used by after/ftplugin/{javascript,typescript,javascriptreact,typescriptreact}.lua

local M = {}

function M.setup()
  require('snippets').enable_snippets()

  vim.opt_local.errorformat = {
    '%f(%l\\,%c): error %m',
    '%f(%l\\,%c): warning %m',
  }

  local ok, t = pcall(require, 'text_objects')
  if not ok then return end

  local function bmap(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = true, desc = desc })
  end

  local function omap(lhs, rhs, desc)
    vim.keymap.set({ 'o', 'x' }, lhs, rhs, { buffer = true, desc = desc })
  end

  omap('ie', function()
    local n = t.get_node('jsx_element')
    if n then t.select_node(n) end
  end, 'Inner JSX element')

  bmap('die', function()
    local n = t.get_node('jsx_element')
    t.yank_node(n); t.delete_node(n)
  end, 'Delete JSX element')

  bmap('yie', function()
    t.yank_node(t.get_node('jsx_element'))
  end, 'Yank JSX element')

  bmap('gcn', function()
    local f = t.get_field(t.get_node('class_declaration'), 'name')
    if f and #f > 0 then t.goto_node(f[1]) end
  end, 'Jump to class name')

  bmap('gmn', function()
    local f = t.get_field(t.get_node('method_definition'), 'name')
    if f and #f > 0 then t.goto_node(f[1]) end
  end, 'Jump to method name')

  bmap('gvn', function()
    local f = t.get_field(t.get_node('variable_declarator'), 'name')
    if f and #f > 0 then t.goto_node(f[1]) end
  end, 'Jump to variable name')

  bmap('gto', function()
    local f = t.get_field(t.get_node('jsx_element'), 'open_tag')
    if f and #f > 0 then t.goto_node(f[1]) end
  end, 'Jump to JSX open tag')

  bmap('gtc', function()
    local f = t.get_field(t.get_node('jsx_element'), 'close_tag')
    if f and #f > 0 then t.goto_node(f[1]) end
  end, 'Jump to JSX close tag')
end

return M
