-- ─────────────────────────────────────────────────────────────────────────────
-- lua/utils/git_root.lua — shared, cached git-root lookup
--
-- Consolidates three previously separate per-file caches in git.lua,
-- diffview.lua, and resession.lua into a single bounded table (full flush
-- when entry count exceeds CACHE_MAX) so duplicate `git rev-parse
-- --show-toplevel` calls are avoided globally.
-- ─────────────────────────────────────────────────────────────────────────────

local M = {}

local _cache = {}        -- dir -> root string, or false = known non-git dir
local _cache_count = 0
local CACHE_MAX = 200

--- Nonblocking cache lookup.
--- Returns (cached_root_or_false, true) when the dir is known,
--- or (nil, false) when no cache entry exists yet.
function M.peek(dir)
  local cached = _cache[dir]
  if cached == nil then return nil, false end
  return cached, true
end

--- Synchronously get the git root for *dir*.
--- Returns the root path string, or nil if *dir* is not inside a git repo.
function M.get(dir)
  local cached = _cache[dir]
  if cached ~= nil then return cached or nil end  -- false → nil

  local obj = vim.system(
    { 'git', 'rev-parse', '--show-toplevel' },
    { cwd = dir, text = true }
  ):wait()

  local root
  if obj.code == 0 then
    root = vim.trim(obj.stdout)
    _cache[dir] = root
  else
    _cache[dir] = false   -- sentinel: do not re-query this dir
    root = nil
  end

  _cache_count = _cache_count + 1
  if _cache_count > CACHE_MAX then
    -- Partial eviction: drop ~25% of entries rather than flushing everything,
    -- which avoids a git rev-parse spike after the 200th unique directory.
    local evict = math.floor(CACHE_MAX / 4)
    for dir in pairs(_cache) do
      _cache[dir] = nil
      _cache_count = _cache_count - 1
      evict = evict - 1
      if evict == 0 then break end
    end
  end

  return root
end

--- Store a known root for a directory (e.g. after an async rev-parse call).
--- Use this to populate the cache without a blocking :wait() call.
function M.store(dir, root)
  if _cache[dir] == nil then _cache_count = _cache_count + 1 end
  _cache[dir] = root or false
  if _cache_count > CACHE_MAX then
    local evict = math.floor(CACHE_MAX / 4)
    for d in pairs(_cache) do
      _cache[d] = nil
      _cache_count = _cache_count - 1
      evict = evict - 1
      if evict == 0 then break end
    end
  end
end

--- Drop a specific entry (e.g. after git init / git clone in that dir).
function M.invalidate(dir)
  if _cache[dir] ~= nil then
    _cache[dir] = nil
    _cache_count = math.max(0, _cache_count - 1)
  end
end

--- Drop all cached entries.
function M.clear()
  _cache = {}
  _cache_count = 0
end

return M
