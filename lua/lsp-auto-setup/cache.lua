---- Functions for reading and writing the cache file

local M = {}

---@class CacheConfig
---@field enable boolean
---@field ttl number
---@field path string

---@class CacheContent
---@field timestamp number The timestamp of the cache file
---@field servers table<string> The servers that were cached

---Reads the cache file and returns the content
---If the cache file does not exist or is older than 7 days, returns nil
---@param config CacheConfig The cache configuration
---@return CacheContent|nil
function M.read_servers(config)
  if not config.enable then
    return nil
  end

  local cache_file = config.path .. "/servers.json"
  local file = io.open(cache_file, 'r')

  if not file then
    return nil
  end

  local json = file:read('*a')
  file:close()

  ---@type boolean, CacheContent
  local decoded, content = pcall(vim.json.decode, json)
  if not decoded or type(content) ~= "table" or not content.timestamp or not content.servers then
    return nil
  end

  -- Check if cache is expired (7 days)
  if content.timestamp < os.time() - config.ttl then
    return nil
  end

  return content
end

---Writes the servers to the cache file
---@param servers table<string> The servers to write to the cache
---@param config CacheConfig The cache configuration
---@return boolean success `true` if the servers were written to the cache, `false` otherwise
function M.write_servers(servers, config)
  if not config.enable then
    return false
  end

  local cache_dir = config.path

  -- Ensure directory exists
  if vim.fn.isdirectory(cache_dir) == 0 then
    local ok, err = pcall(vim.fn.mkdir, cache_dir, 'p')
    if not ok then
      vim.notify("Failed to create cache directory: " .. tostring(err), vim.log.levels.WARN, { title = "LSP Auto Setup" })
      return false
    end
  end

  -- Write to temporary file first
  local temp_path = cache_dir .. '/servers.json.tmp'
  local file = io.open(temp_path, 'w')

  if not file then
    vim.notify("Failed to open cache file for writing", vim.log.levels.WARN, { title = "LSP Auto Setup" })
    return false
  end

  local content = {
    timestamp = os.time(),
    servers = servers,
  }

  local ok, json = pcall(vim.json.encode, content)
  if not ok then
    vim.notify("Failed to encode cache data", vim.log.levels.WARN, { title = "LSP Auto Setup" })
    file:close()
    os.remove(temp_path)
    return false
  end

  file:write(json)
  file:close()

  -- Atomic rename
  local final_path = cache_dir .. '/servers.json'
  os.rename(temp_path, final_path)

  return true
end

return M
