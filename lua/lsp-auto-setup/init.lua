---@module "lsp-auto-setup"
---@description Automatically sets up LSP servers based on available executables

local M = {}

--- List of deprecated LSP servers that should not be set up
local deprecated_server = {
  "typst_lsp",
  "ruff_lsp",
  "bufls"
}

local function notify(message, level)
  vim.notify(message, level, { title = "LSP Auto Setup" })
end

---@class ConfigOptions
---@field server_config table<string, fun(default_config: table): table> Table of server configurations, where the key is the server name and the value is a function that gets the default configuration and returns the custom configuration
---@field exclude table List of server names to exclude from auto-setup

local default_opts = {
  server_config = {},
  exclude = {}
}

---Checks if a server should be skipped
---@param name string The name of the LSP server
---@param exclude table List of server names to exclude from auto-setup
---@param deprecated table List of deprecated LSP servers
---@return boolean should_skip True if the server should be skipped, false otherwise
local function should_skip_server(name, exclude, deprecated)
  return (vim.tbl_contains(exclude, name) or vim.tbl_contains(deprecated, name))
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

---Sets up an individual LSP server if its executable is available
---@param name string The name of the LSP server
---@param server_config function Function to generate server configuration
local function setup_server(name, server_config)
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
  local options = vim.tbl_extend("keep", opts or {}, default_opts)

  local lspconfig_path = get_lspconfig_path()

  if (lspconfig_path == nil) then
    notify("nvim-lspconfig not found in runtimepath", vim.log.levels.ERROR)
    return
  end

  -- Iterate through all available LSP server configurations
  for name, type_ in vim.fs.dir((lspconfig_path .. "/lua/lspconfig/configs")) do
    if (type_ ~= "file") then
      goto continue
    end

    local name_without_extension = vim.fn.fnamemodify(name, ":r")
    if (should_skip_server(name_without_extension, options.exclude, deprecated_server)) then
      goto continue
    end

    setup_server(name_without_extension, options.server_config)

    ::continue::
  end
end

return M
