-- Auto-pairs — insert mode bracket/quote pairing with skip-over

local map = vim.keymap.set

local function autopair(open, close)
  map('i', open, function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local after = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
    if after:match('%w') then return open end
    return open .. close .. '<Left>'
  end, { expr = true })
end

local function autoskip(close)
  map('i', close, function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if vim.api.nvim_get_current_line():sub(col + 1, col + 1) == close then
      return '<Right>'
    end
    return close
  end, { expr = true })
end

-- Filetypes where specific quote chars should not auto-pair (e.g. Rust lifetimes)
local no_autoquote = { rust = { ["'"] = true } }

local function autoquote(char)
  map('i', char, function()
    local ft_skip = no_autoquote[vim.bo.filetype]
    if ft_skip and ft_skip[char] then return char end
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line()
    local after = line:sub(col + 1, col + 1)
    if after == char then return '<Right>' end
    if line:sub(col, col):match('%w') then return char end
    return char .. char .. '<Left>'
  end, { expr = true })
end

autopair('(', ')')
autopair('[', ']')
autopair('{', '}')
autoskip(')')
autoskip(']')
autoskip('}')
autoquote("'")
autoquote('"')
autoquote('`')

-- Backspace deletes pair
map('i', '<BS>', function()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  local before, after = line:sub(col, col), line:sub(col + 1, col + 1)
  local pairs = { ['('] = ')', ['['] = ']', ['{'] = '}', ['"'] = '"', ["'"] = "'", ['`'] = '`' }
  if pairs[before] == after then return '<BS><Del>' end
  return '<BS>'
end, { expr = true })
