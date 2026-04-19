-- Native snippet completefunc — loaded per-filetype by after/ftplugin
-- Trigger: <C-x><C-u> in insert mode

local M = {}
local cache = {}

_G.complete_snippets = function(findstart, base)
  local ft = vim.bo.filetype

  if not cache[ft] then
    local ok, snips = pcall(require, 'snippets.' .. ft)
    if not ok then return findstart == 1 and -1 or {} end
    cache[ft] = snips
  end

  if findstart == 1 then
    local line = vim.fn.getline('.')
    local col = vim.fn.col('.') - 1
    local start = col
    while start > 0 and line:sub(start, start):match('[%w_-]') do
      start = start - 1
    end
    return start
  else
    local items = {}
    for key, body in pairs(cache[ft]) do
      if key:match('^' .. vim.pesc(base)) then
        items[#items + 1] = { word = key, user_data = vim.fn.json_encode({ snippet = body }) }
      end
    end
    return items
  end
end

function M.enable_snippets()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf]._snippets_enabled then return end
  vim.b[buf]._snippets_enabled = true
  vim.bo[buf].completefunc = 'v:lua.complete_snippets'

  vim.api.nvim_create_autocmd('CompleteDone', {
    buffer = buf,
    callback = function()
      if vim.v.event.reason ~= 'accept' then return end
      local item = vim.v.completed_item
      if not item or not item.user_data then return end
      local ok, data = pcall(vim.fn.json_decode, item.user_data)
      if not ok or not data.snippet then return end
      vim.api.nvim_feedkeys(vim.keycode('<C-w>'), 'n', false)
      vim.schedule(function() vim.snippet.expand(data.snippet) end)
    end,
  })
end

return M
