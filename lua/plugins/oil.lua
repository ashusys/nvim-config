-- ═════════════════════════════════════════════════════════════════════
--  Oil.nvim — file explorer that lets you edit your filesystem like a buffer
--  Native vim.pack — auto-install, lockfile, updates
--  Replaces netrw entirely — faster, more intuitive, buffer-native UX
-- ═════════════════════════════════════════════════════════════════════

vim.pack.add({ 'https://github.com/stevearc/oil.nvim.git' })

local M = {}

local SIDEBAR_WIDTH = require('config').sidebar_width
local sidebar_state = {}
local ignore_exact = {}
local ignore_patterns = {}
local ignore_loaded = false
local oil_mod = nil
local setup_done = false
local launch_dir = nil

if vim.fn.argc() == 1 then
  local arg = vim.fn.argv(0)
  if vim.fn.isdirectory(arg) == 1 then
    launch_dir = vim.fn.fnamemodify(arg, ':p')
  end
end

local function get_oil()
  if oil_mod then return oil_mod end
  local ok, mod = pcall(require, 'oil')
  if not ok then return nil, mod end
  oil_mod = mod
  return oil_mod
end

local function get_state(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local state = sidebar_state[tab]
  if not state then
    state = { sidebar_win = nil, main_win = nil }
    sidebar_state[tab] = state
  end
  return state
end

local function is_sidebar_window(win)
  local tab = vim.api.nvim_win_get_tabpage(win)
  local state = sidebar_state[tab]
  return state and state.sidebar_win == win
end

local function glob_to_pattern(glob)
  return '^'
    .. glob:gsub('([%^%$%(%)%%%.%[%]%+%-])', '%%%1')
      :gsub('%*', '.*')
      :gsub('%?', '.')
    .. '$'
end

local function load_ignore_rules()
  if ignore_loaded then return end
  ignore_loaded = true

  local ignore_path = vim.fn.stdpath('config') .. '/.editorignore'
  local file = io.open(ignore_path, 'r')
  if not file then return end

  for line in file:lines() do
    line = vim.trim(line)
    if line ~= '' and line:sub(1, 1) ~= '#' then
      if line:sub(-1) == '/' then
        line = line:sub(1, -2)
      end
      if line:find('[*?]') then
        ignore_patterns[#ignore_patterns + 1] = glob_to_pattern(line)
      else
        ignore_exact[line] = true
      end
    end
  end

  file:close()
end

local function select_in_main_win()
  local oil = get_oil()
  if not oil then return end

  local entry = oil.get_cursor_entry()
  if not entry then return end
  local dir = oil.get_current_dir()
  if not dir then return end

  local path = dir .. entry.name
  local oil_win = vim.api.nvim_get_current_win()
  local state = get_state()
  local sidebar = is_sidebar_window(oil_win)

  if entry.type == 'directory' then
    oil.open(path)
    return
  end

  if not sidebar then
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    return
  end

  local target_win = state.main_win
  if not (target_win and vim.api.nvim_win_is_valid(target_win)
      and vim.api.nvim_win_get_tabpage(target_win) == vim.api.nvim_get_current_tabpage()) then
    target_win = nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if win ~= oil_win and vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'oil' then
        target_win = win
        break
      end
    end
  end

  if target_win and vim.api.nvim_win_is_valid(target_win) then
    vim.api.nvim_set_current_win(target_win)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
  else
    vim.cmd('leftabove vsplit ' .. vim.fn.fnameescape(path))
    state.main_win = vim.api.nvim_get_current_win()
  end
end

function M.toggle_sidebar()
  if not setup_done and not M.setup() then return end

  local oil = get_oil()
  if not oil then return end

  local state = get_state()
  if state.sidebar_win and vim.api.nvim_win_is_valid(state.sidebar_win) then
    vim.api.nvim_win_close(state.sidebar_win, true)
    state.sidebar_win = nil
    return
  end

  state.main_win = vim.api.nvim_get_current_win()
  local dir = vim.fn.expand('%:p:h')
  if dir == '' or dir == '.' then dir = vim.fn.getcwd() end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('botright vsplit')
  vim.api.nvim_win_set_buf(0, buf)
  vim.cmd('vertical resize ' .. SIDEBAR_WIDTH)
  oil.open(dir)
  state.sidebar_win = vim.api.nvim_get_current_win()
  vim.wo[state.sidebar_win].winfixwidth = true
end

function M.setup()
  if setup_done then return true end

  local oil, err = get_oil()
  if not oil then
    vim.notify('Failed to load oil.nvim: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  load_ignore_rules()

  oil.setup({
    default_file_explorer = true,
    columns = {},
    buf_options = {
      buflisted = false,
      bufhidden = 'hide',
    },
    win_options = {
      wrap = false,
      signcolumn = 'no',
      cursorcolumn = false,
      foldcolumn = '0',
      spell = false,
      list = false,
      conceallevel = 3,
      concealcursor = 'nvic',
    },
    delete_to_trash = false,
    skip_confirm_for_simple_edits = true,
    prompt_save_on_select_new_entry = true,
    cleanup_delay_ms = 2000,
    lsp_file_methods = {
      enabled = true,
      timeout_ms = 1000,
      autosave_changes = false,
    },
    constrain_cursor = 'editable',
    watch_for_changes = not (vim.fn.has('wsl') == 1 or os.getenv('WSL_DISTRO_NAME') ~= nil),
    keymaps = {
      ['g?'] = 'actions.show_help',
      ['<CR>'] = { callback = select_in_main_win, desc = 'Open in main window' },
      ['l'] = { callback = select_in_main_win, desc = 'Enter dir / open in main window' },
      ['h'] = 'actions.parent',
      ['<BS>'] = 'actions.parent',
      ['<C-v>'] = { 'actions.select', opts = { vertical = true, close = true }, desc = 'Open vsplit' },
      ['<C-x>'] = { 'actions.select', opts = { horizontal = true, close = true }, desc = 'Open hsplit' },
      ['<C-t>'] = { 'actions.select', opts = { tab = true, close = true }, desc = 'Open tab' },
      ['<C-p>'] = 'actions.preview',
      ['<C-c>'] = 'actions.close',
      ['<C-l>'] = 'actions.refresh',
      ['-'] = 'actions.parent',
      ['_'] = 'actions.open_cwd',
      ['`'] = 'actions.cd',
      ['~'] = { 'actions.cd', opts = { scope = 'tab' }, desc = 'cd tab scope' },
      ['gs'] = 'actions.change_sort',
      ['gx'] = 'actions.open_external',
      ['g.'] = 'actions.toggle_hidden',
      ['g\\'] = 'actions.toggle_trash',
      ['q'] = 'actions.close',
    },
    use_default_keymaps = false,
    view_options = {
      show_hidden = true,
      is_hidden_file = function(name)
        return vim.startswith(name, '.')
      end,
      is_always_hidden = function(name)
        if name == '..' or name == '.git' then return true end
        if ignore_exact[name] then return true end
        for _, pattern in ipairs(ignore_patterns) do
          if name:match(pattern) then return true end
        end
        return false
      end,
      natural_order = true,
      case_insensitive = true,
      sort = {
        { 'type', 'asc' },
        { 'name', 'asc' },
      },
    },
    float = {
      padding = 2,
      max_width = 80,
      max_height = 30,
      border = 'single',
      win_options = {
        winblend = 0,
      },
    },
    preview_win = {
      update_on_cursor_moved = true,
    },
  })

  vim.api.nvim_create_autocmd({ 'WinClosed', 'TabClosed' }, {
    group = vim.api.nvim_create_augroup('OilSidebarState', { clear = true }),
    callback = function()
      vim.schedule(function()
        for tab, state in pairs(sidebar_state) do
          if not vim.api.nvim_tabpage_is_valid(tab) then
            sidebar_state[tab] = nil
          else
            if state.sidebar_win and not vim.api.nvim_win_is_valid(state.sidebar_win) then
              state.sidebar_win = nil
            elseif state.sidebar_win then
              vim.api.nvim_win_set_width(state.sidebar_win, SIDEBAR_WIDTH)
            end
            if state.main_win and not vim.api.nvim_win_is_valid(state.main_win) then
              state.main_win = nil
            end
          end
        end
      end)
    end,
  })

  setup_done = true

  if launch_dir then
    local dir_to_open = launch_dir
    launch_dir = nil
    local dir_buf = vim.api.nvim_get_current_buf()
    vim.cmd('enew')
    pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
    vim.cmd('cd ' .. vim.fn.fnameescape(dir_to_open))
    M.toggle_sidebar()
    local state = get_state()
    if state.main_win and vim.api.nvim_win_is_valid(state.main_win) then
      vim.api.nvim_set_current_win(state.main_win)
    else
      vim.cmd('wincmd h')
    end
  end

  return true
end

vim.keymap.set('n', '-', function()
  if M.setup() then vim.cmd('Oil') end
end, { desc = 'Open parent directory (oil)' })

vim.keymap.set('n', '<leader>e', M.toggle_sidebar, { desc = 'Toggle file explorer sidebar (oil)' })

return M
