--- Automatically sets up LSP servers based on available executables

local cache = require("lsp-auto-setup.cache")
local M = {}

--- List of deprecated LSP servers that should not be set up
local DEPRECATED_SERVER = {
  "typst_lsp",
  "ruff_lsp",
  "bufls"
}

local function notify(message, level)
  vim.notify(message, level, { title = "LSP Auto Setup" })
end

---@alias ServerConfig table<string, fun(default_config: table): table>

---@class ConfigOptions
---@field server_config? ServerConfig Table of server configurations, where the key is the server name and the value is a function that gets the default configuration and returns the custom configuration
---@field exclude? table List of server names to exclude from auto-setup
---@field cache? CacheOptions Whether to cache the servers or not
---@field stop_unused_servers? boolean Whether to automatically stop a server when there is no buffer attached to it

---@class CacheOptions
---@field enable? boolean Whether to cache the servers or not
---@field ttl? number Time-to-live for the cache in seconds
---@field path? string Path to the cache directory

---@class Config
---@field server_config ServerConfig
---@field exclude table
---@field cache CacheConfig
---@field stop_unused_servers boolean

---@type Config
local DEFAULT_OPTS = {
  server_config = {},
  exclude = {},
  cache = {
    enable = true,
    ttl = 60 * 60 * 24 * 7,
    path = vim.fn.stdpath("cache") .. "/lsp-auto-setup"
  },
  stop_unused_servers = true
}

--- Gets the configuration options
--- @param opts ConfigOptions
--- @return Config
local function get_config(opts)
  ---@type CacheOptions
  local user_cache_options = opts.cache or {}

  ---@type CacheConfig
  local cache_options = vim.tbl_extend("keep", user_cache_options, DEFAULT_OPTS.cache)

  ---@type Config
  local options = vim.tbl_extend("keep", opts, DEFAULT_OPTS)
  options.cache = cache_options

  return options
end

local function create_stop_unused_servers_autocmd()
  vim.api.nvim_create_autocmd({ "LspDetach" }, {
    group = vim.api.nvim_create_augroup("lsp-auto-setup-stop-unused-servers", { clear = true }),
    callback = vim.schedule_wrap(function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or not client.attached_buffers then
        return
      end

      -- Check if there are any other buffers attached to the client
      for buf_id in pairs(client.attached_buffers) do
        if buf_id ~= args.buf then
          return
        end
      end

      -- Stop the client if no other buffers are attached
      client.stop()
    end),
    desc = "LspAutoSetup: Stop server when no buffer is attached",
  })
end

---Finds the path to nvim-lspconfig in the runtime path
---@return string|nil lspconfig_path Path to the nvim-lspconfig installation or `nil` if not found
local function get_lspconfig_path()
  local runtime_paths = vim.opt.rtp:get()
  local lspconfig_path = vim.tbl_filter(function(path)
    return vim.endswith(path, "nvim-lspconfig")
  end, runtime_paths)[1]

  return lspconfig_path
end

---Checks if a server should be skipped
---@param name string The name of the LSP server
---@param exclude table List of server names to exclude from auto-setup
---@param deprecated table List of deprecated LSP servers
---@return boolean should_skip True if the server should be skipped, false otherwise
local function should_skip_server(name, exclude, deprecated)
  return (vim.tbl_contains(exclude, name) or vim.tbl_contains(deprecated, name))
end


---Sets up an individual LSP server if its executable is available
---@param name string The name of the LSP server
---@param server_config table<string, function> Function to generate server configuration
---@param exclude table List of server names to exclude from auto-setup
local function setup_server(name, server_config, exclude)
  if (should_skip_server(name, exclude, DEPRECATED_SERVER)) then
    return
  end

  local lspconfig = require("lspconfig")
  local server = lspconfig[name]
  local default_config = (server.default_config or server.document_config.default_config)
  local cmd_type = type(default_config.cmd)

  local user_options = server_config[name]
  local options = {}
  if (user_options) then
    if (type(user_options) ~= "function") then
      notify("Error while setting up " .. name .. ": `server_config` must be a function that returns a table",
        vim.log.levels.ERROR)
      return
    end
    options = user_options(default_config)
  end

  local cmd = nil
  -- If the user has provided a custom command, use that
  if options.cmd then
    cmd = options.cmd[1]
  elseif (cmd_type == "table") then
    cmd = default_config.cmd[1]
  elseif (cmd_type == "string") then
    cmd = default_config.cmd
  end

  -- Only set up the server if its executable is available
  if (cmd and vim.fn.executable(cmd) == 1) then
    server.setup(options)
  end
end

---Sets up LSP servers automatically based on available executables
---@param opts ConfigOptions|nil Configuration options
function M.setup(opts)
  local options = get_config(opts or {})

  if options.stop_unused_servers then
    create_stop_unused_servers_autocmd()
  end

  local lspconfig_path = get_lspconfig_path()

  if (lspconfig_path == nil) then
    notify("nvim-lspconfig not found in runtimepath", vim.log.levels.ERROR)
    return
  end

  local cached = cache.read_servers(options.cache)
  if (cached) then
    for _, server in pairs(cached.servers) do
      setup_server(server, options.server_config, options.exclude)
    end
    return
  end

  local servers_to_cache = {}
  -- Iterate through all available LSP server configurations
  for name, type_ in vim.fs.dir((lspconfig_path .. "/lua/lspconfig/configs")) do
    if (type_ ~= "file") then
      goto continue
    end

    local name_without_extension = vim.fn.fnamemodify(name, ":r")
    table.insert(servers_to_cache, name_without_extension)
    setup_server(name_without_extension, options.server_config, options.exclude)

    ::continue::
  end

  cache.write_servers(servers_to_cache, options.cache)
end

return M
