-- Treesitter text objects — structural editing via TS nodes
-- Zero startup cost: loaded on-demand by after/ftplugin/*

local M = {}

function M.get_node(node_type)
  local node = vim.treesitter.get_node()
  for _ = 1, 16 do
    if not node then return nil end
    if node:type() == node_type then return node end
    node = node:parent()
  end
end

function M.get_field(node, field_name)
  return node and node:field(field_name) or nil
end

function M.goto_node(node)
  if not node then return end
  local row, col = node:range()
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

function M.get_next_child(parent_node)
  if not parent_node or parent_node:named_child_count() == 0 then return nil end
  local count = parent_node:named_child_count()
  -- Simple round-robin via buffer-local index
  local idx = (vim.b._ts_child_idx or -1) + 1
  if idx >= count then idx = 0 end
  vim.b._ts_child_idx = idx
  return parent_node:named_child(idx)
end

function M.get_next_child_by_name(parent_node, child_names)
  if not parent_node then return nil end
  local children = {}
  for _, child in ipairs(parent_node:named_children()) do
    if child_names[child:type()] then
      children[#children + 1] = child
    end
  end
  if #children == 0 then return nil end
  local idx = ((vim.b._ts_named_child_idx or 0) % #children) + 1
  vim.b._ts_named_child_idx = idx
  return children[idx]
end

function M.yank_node(node)
  if not node then return end
  local start_row, _, end_row, _ = node:range()
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  vim.fn.setreg('+', table.concat(lines, '\n'), 'V')
end

function M.delete_node(node)
  if not node then return end
  local start_row, _, end_row, _ = node:range()
  vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, {})
  vim.api.nvim_win_set_cursor(0, { math.min(start_row + 1, vim.api.nvim_buf_line_count(0)), 0 })
end

function M.select_node(node)
  if not node then return end
  local sr, sc, er, ec = node:range()
  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { er + 1, math.max(ec - 1, 0) })
end

return M
