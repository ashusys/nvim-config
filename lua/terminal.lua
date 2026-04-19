-- Floating toggle terminal — per-tab persistent state

local state = {} -- keyed by tabpage

local function get_dimensions()
  local ratio = require('config').float_ratio
  return math.floor(vim.o.columns * ratio), math.floor(vim.o.lines * ratio)
end

local function toggle()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab] or { buf = -1, win = -1 }
  state[tab] = s

  if vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_hide(s.win)
    return
  end
  local buf = vim.api.nvim_buf_is_valid(s.buf) and s.buf or vim.api.nvim_create_buf(false, true)
  local w, h = get_dimensions()

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = w, height = h,
    col = math.floor((vim.o.columns - w) / 2),
    row = math.floor((vim.o.lines - h) / 2),
    style = 'minimal',
    border = 'single',
  })

  s.buf = buf
  s.win = win

  if vim.bo[buf].buftype ~= 'terminal' then
    vim.fn.termopen(vim.o.shell)
  end

  vim.cmd.startinsert()
end

vim.keymap.set('n', '<leader>tt', toggle, { desc = 'Toggle floating terminal' })
vim.keymap.set('t', '<leader>q', toggle, { desc = 'Toggle floating terminal' })

local term_augroup = vim.api.nvim_create_augroup('ToggleTerminal', { clear = true })

vim.api.nvim_create_autocmd('TabClosed', {
  group = term_augroup,
  callback = function()
    local valid = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do valid[tab] = true end
    for tab, s in pairs(state) do
      if not valid[tab] then
        -- Delete the terminal buffer so it doesn't accumulate in :ls
        if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
          pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
        end
        state[tab] = nil
      end
    end
  end,
})

vim.api.nvim_create_autocmd('VimResized', {
  group = term_augroup,
  callback = function()
    for _, s in pairs(state) do
      if s.win and vim.api.nvim_win_is_valid(s.win) then
        local w, h = get_dimensions()
        vim.api.nvim_win_set_config(s.win, {
          relative = 'editor',
          width = w, height = h,
          col = math.floor((vim.o.columns - w) / 2),
          row = math.floor((vim.o.lines - h) / 2),
        })
      end
    end
  end,
})

return { toggle = toggle }
