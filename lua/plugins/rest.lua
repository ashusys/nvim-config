-- ═════════════════════════════════════════════════════════════════════
--  REST client — zero-dependency .http file runner
--  Parses request under cursor, runs via curl, shows result in split
--  Supports: env files, headers, JSON body, basic HTTP methods
--  Loaded on FileType http only
-- ═════════════════════════════════════════════════════════════════════

local M = {}

-- ── Env file loading ────────────────────────────────────────────────
local env_vars = {}
local env_file = nil
local env_source = nil

local function clear_env()
  env_vars = {}
  env_file = nil
  env_source = nil
end

local function load_env(file, source)
  if file == env_file and source == env_source then return end
  clear_env()
  if not file or vim.fn.filereadable(file) == 0 then return end
  env_file = file
  env_source = source or 'manual'
  for _, line in ipairs(vim.fn.readfile(file)) do
    line = vim.trim(line)
    if line ~= '' and line:sub(1, 1) ~= '#' then
      local key, val = line:match('^export%s+([%w_]+)%s*=%s*(.-)%s*$')
      if not key then
        key, val = line:match('^([%w_]+)%s*=%s*(.-)%s*$')
      end
      if key then
        val = vim.trim(val)
        local quote = val:sub(1, 1)
        if (quote == '"' or quote == "'") and val:sub(-1) == quote then
          val = val:sub(2, -2)
        end
        env_vars[key] = val
      end
    end
  end
  vim.notify('Env loaded: ' .. vim.fn.fnamemodify(file, ':t') .. ' (' .. vim.tbl_count(env_vars) .. ' vars)', vim.log.levels.INFO)
end

local function substitute_vars(str)
  return (str:gsub('{{(.-)}}', function(key)
    return env_vars[key] or os.getenv(key) or ('{{' .. key .. '}}')
  end))
end

-- ── Parse request block under cursor ────────────────────────────────
local function parse_request()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]

  local http_methods = { GET=1, POST=1, PUT=1, PATCH=1, DELETE=1, HEAD=1, OPTIONS=1 }

  -- Find request block: search backward for method line, forward for end (### or EOF)
  local req_start, req_end
  for i = cursor, 1, -1 do
    local method = lines[i]:match('^%s*(%u+)%s')
    if method and http_methods[method] then
      req_start = i
      break
    end
    if lines[i]:match('^###') and i < cursor then break end
  end

  if not req_start then
    vim.notify('No HTTP request found under cursor', vim.log.levels.WARN)
    return nil
  end

  for i = req_start + 1, #lines do
    if lines[i]:match('^###') or lines[i]:match('^%s*(GET |POST |PUT |PATCH |DELETE |HEAD |OPTIONS )') then
      req_end = i - 1
      break
    end
  end
  req_end = req_end or #lines

  -- Parse method + URL
  local method, url = lines[req_start]:match('^%s*(%u+)%s+(.+)%s*$')
  if not method or not url then
    vim.notify('Invalid request line: ' .. lines[req_start], vim.log.levels.ERROR)
    return nil
  end

  -- Strip HTTP version if present
  url = vim.trim(url:gsub('%s+HTTP/%d+%.?%d*%s*$', ''))
  url = substitute_vars(url)

  -- Parse headers and body
  local headers = {}
  local body_lines = {}
  local in_body = false
  for i = req_start + 1, req_end do
    local line = lines[i]
    if line:match('^%s*#') then
      -- skip comments
    elseif not in_body and line:match('^%s*$') then
      in_body = true
    elseif in_body then
      body_lines[#body_lines + 1] = line
    elseif line:match('^[%w%-]+:') then
      local key, val = line:match('^([%w%-]+):%s*(.+)%s*$')
      if key then headers[#headers + 1] = { key = key, val = substitute_vars(val) } end
    end
  end

  local body = #body_lines > 0 and substitute_vars(table.concat(body_lines, '\n')) or nil
  return { method = method, url = url, headers = headers, body = body }
end

-- ── Build curl command ──────────────────────────────────────────────
local function build_curl(req)
  local args = { 'curl', '-sS', '-w', '\\n---HTTP_STATUS:%{http_code}---\\nTime: %{time_total}s\\nSize: %{size_download} bytes' }
  args[#args + 1] = '-X'
  args[#args + 1] = req.method
  for _, h in ipairs(req.headers) do
    args[#args + 1] = '-H'
    args[#args + 1] = h.key .. ': ' .. h.val
  end
  if req.body then
    args[#args + 1] = '-d'
    args[#args + 1] = req.body
  end
  args[#args + 1] = req.url
  return args
end

-- ── Result display ──────────────────────────────────────────────────
local result_buf = nil

local function show_result(req, output)
  -- Parse status code from output
  local body_parts = {}
  local stats = {}
  local status_code = '???'
  for _, line in ipairs(output) do
    local code = line:match('---HTTP_STATUS:(%d+)---')
    if code then
      status_code = code
    elseif line:match('^Time:') or line:match('^Size:') then
      stats[#stats + 1] = line
    else
      body_parts[#body_parts + 1] = line
    end
  end

  local resp_body = table.concat(body_parts, '\n')

  -- Try to format JSON
  local formatted = resp_body
  if resp_body:match('^%s*[{%[]') then
    local ok, decoded = pcall(vim.json.decode, resp_body)
    if ok then
      formatted = vim.json.encode(decoded)
      -- Pretty print via jq if available
      if vim.fn.executable('jq') == 1 then
        local jq = vim.system({ 'jq', '.' }, { stdin = resp_body, text = true }):wait()
        if jq.code == 0 and jq.stdout then formatted = jq.stdout end
      end
    end
  end

  local display = {
    '# ' .. req.method .. ' ' .. req.url,
    '# Status: ' .. status_code,
    '# ' .. table.concat(stats, ' | '),
    '',
  }
  for line in formatted:gmatch('[^\n]+') do
    display[#display + 1] = line
  end

  -- Show in split
  if not result_buf or not vim.api.nvim_buf_is_valid(result_buf) then
    result_buf = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[result_buf].modifiable = true
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, display)

  -- Try to set JSON filetype for syntax highlighting
  pcall(function()
    vim.bo[result_buf].filetype = resp_body:match('^%s*[{%[]') and 'json' or 'text'
  end)
  vim.bo[result_buf].buftype = 'nofile'
  vim.bo[result_buf].bufhidden = 'hide'
  vim.bo[result_buf].swapfile = false
  vim.bo[result_buf].modifiable = false

  vim.cmd('vertical sbuffer ' .. result_buf)
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.45))
end

-- ── Run request ─────────────────────────────────────────────────────
local last_request = nil

function M.run()
  local req = parse_request()
  if not req then return end
  last_request = req

  vim.notify(req.method .. ' ' .. req.url, vim.log.levels.INFO)

  local output = {}
  vim.fn.jobstart(build_curl(req), {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then vim.list_extend(output, data) end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= '' then
        vim.list_extend(output, data)
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 and #output == 0 then
          vim.notify('curl failed (exit ' .. code .. ')', vim.log.levels.ERROR)
          return
        end
        show_result(req, output)
      end)
    end,
  })
end

function M.run_last()
  if not last_request then
    vim.notify('No previous request', vim.log.levels.WARN)
    return
  end
  vim.notify(last_request.method .. ' ' .. last_request.url .. ' (last)', vim.log.levels.INFO)
  local output = {}
  vim.fn.jobstart(build_curl(last_request), {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) if data then vim.list_extend(output, data) end end,
    on_stderr = function(_, data) if data and data[1] ~= '' then vim.list_extend(output, data) end end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 and #output == 0 then
          vim.notify('curl failed (exit ' .. code .. ')', vim.log.levels.ERROR)
          return
        end
        show_result(last_request, output)
      end)
    end,
  })
end

function M.select_env()
  -- Find .env files in cwd and config dir
  local cwd = vim.fn.getcwd()
  local config_dir = vim.fn.stdpath('config')
  local env_files = {}
  local seen = {}
  for _, dir in ipairs({ cwd, config_dir }) do
    local found = vim.fs.find(function(name) return name:match('%.env') end, { path = dir, type = 'file', limit = 20 })
    for _, path in ipairs(found) do
      if not seen[path] then
        seen[path] = true
        env_files[#env_files + 1] = path
      end
    end
  end
  if #env_files == 0 then
    vim.notify('No .env files found', vim.log.levels.WARN)
    return
  end
  vim.ui.select(env_files, { prompt = 'Select env file:' }, function(choice)
    if choice then load_env(choice, 'manual') end
  end)
end

function M.attach(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or (buf or vim.api.nvim_get_current_buf())
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].filetype ~= 'http' then return end
  if vim.b[buf]._rest_client_attached then return end
  vim.b[buf]._rest_client_attached = true

  local map = vim.keymap.set
  map('n', '<leader>kr', M.run, { desc = 'REST: run request', buffer = buf })
  map('n', '<leader>kl', M.run_last, { desc = 'REST: run last', buffer = buf })
  map('n', '<leader>ke', M.select_env, { desc = 'REST: select env', buffer = buf })

  if env_source ~= 'manual' then
    local name = vim.api.nvim_buf_get_name(buf)
    local start_dir = name ~= '' and vim.fn.fnamemodify(name, ':p:h') or vim.fn.getcwd()
    local nearby = vim.fs.find(function(fname) return fname:match('%.env') end,
      { path = start_dir, upward = true, type = 'file', limit = 1 })
    if nearby[1] then
      load_env(nearby[1], 'auto')
    elseif env_source == 'auto' then
      clear_env()
    end
  end
end

-- ── Auto-load on http filetype ──────────────────────────────────────
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('RestClientLoad', { clear = true }),
  pattern = 'http',
  callback = function(ev)
    M.attach(ev.buf)
  end,
})

return M
