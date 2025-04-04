# LSP Auto Setup

A Neovim plugin that automatically sets up language servers based on available executables.

## Problem

Every time you want to use a new language server, you need to install it **and** configure it in your `init.lua`:

```lua
require("lspconfig").<server>.setup({
  -- Configuration here
})
```

This can get tedious, especially if you're working with multiple servers:

```lua
require"lspconfig".tsserver.setup{}
require"lspconfig".html.setup{}
require"lspconfig".cssls.setup{}
require"lspconfig".jsonls.setup{}
require"lspconfig".pyright.setup{}
require"lspconfig".rust_analyzer.setup{}
-- And so on...
```

## Solution

This plugin automatically detects and configures language servers based on available executables. It uses the `nvim-lspconfig` plugin to set up servers, so you don't need to worry about writing configuration for each server.

```lua
require"lsp-auto-setup".setup{} -- Already set up all available servers
```

## Features

- Automatically detects and configures LSP servers based on available executables
- Allows custom configuration for each server
- Provides options to exclude specific servers
- Cache server names to avoid re-scanning on subsequent calls
- Automatically stop servers that are not attached to any buffer
- Works with `lsp/[server].lua` files. The configuration will be merged with the default configuration from `nvim-lspconfig`

## Requirements

- Neovim >= 0.8.0
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Massolari/lsp-auto-setup.nvim",
  dependencies = { "neovim/nvim-lspconfig" },
  config = true,
  -- Those are the default options, you don't need to provide them if you're happy with the defaults
  opts = {
    -- Table of server-specific configuration functions
    server_config = {},

    -- List of server names to exclude from auto-setup
    exclude = {},

    -- Cache configuration
    cache = {
      enable = true, -- Enable/disable caching of server names
      ttl = 60 * 60 * 24 * 7, -- Time-to-live for cached server names (in seconds), default is 1 week
      path = vim.fn.stdpath("cache") .. "/lsp-auto-setup/servers.json" -- Path to the cache file
    },

    -- Stop servers that are not attached to any buffer. When a buffer is closed, the server attached to it will be stopped if it's not attached to any other buffer
    stop_unused_servers = {
      enable = true, -- Enable/disable stopping of unused servers
      exclude = {} -- List of server names to exclude from stopping
    }
  }
}
```

### Example configuration

#### Configuring the server on `setup`

```lua
require("lsp-auto-setup").setup({
  server_config = {
    lua_ls = function(default_config)
      return {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" }
            }
          }
        }
      }
    },
    -- Add other servers as needed
    -- pyright = function(default_config)
    --   return { ... }
    -- end
  },
  exclude = { "tsserver", "rust_analyzer" },
  cache = {
    ttl = 60 * 60 * 24 * 2, -- 2 days
    path = vim.fn.expand("~") .. "/cache-files" -- Custom cache path
  },
  stop_unused_servers = {
    exclude = {"lua_ls"} -- Don't stop the lua_ls server when it's not attached to any buffer
  }
})
```

#### Configuring the server in `lsp/[server].lua`

If you're using Neovim 0.11, you can set the server configuration in the `lsp/[server].lua` file:

```lua
-- ~/.config/nvim/lua/lsp/lua_ls.lua
return {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" }
      }
    }
  }
}
```

This configuration will be merged with the default configuration from `nvim-lspconfig`.

_Note: The filename must match the server name (e.g., `lua_ls.lua` for the `lua_ls` server)._

The `lsp-auto-setup`'s `setup` is still useful for configurations that use the default configuration coming from `nvim-lspconfig`:

```lua
require("lsp-auto-setup").setup({
  server_config = {
    tailwindcss = function(default_config)
      return {
        init_options = { userLanguages = { elm = "html", gleam = "html" } },
        filetypes = { "elm", "gleam", unpack(default_config.filetypes) },
      }
    end
  },
  exclude = { "tsserver", "rust_analyzer" },
  stop_unused_servers = {
    exclude = {"lua_ls"} -- Don't stop the lua_ls server when it's not attached to any buffer
  }
})
```

### Commands

The following commands are available:

- `LspAutoSetupClearCache`: Clear the cache file used to store server names. This will force the plugin to re-scan the available servers on the next call.

## How It Works

The plugin:
1. Locates the `nvim-lspconfig` installation in your runtime path
2. Scans all available language server configurations*
3. For each server, it checks if its executable is available on your system
4. If found, it sets up the server with your custom configuration or the default configuration skipping deprecated servers

_*This is done only once, and the results are cached to avoid re-scanning on subsequent calls. The cache is cleared after a week by default._

## Global configuration


If you want to set global configuration for all servers (like `capabilities` or `on_attach`), nvim-lspconfig and `vim.lsp.config` already provides a way to do that:

### nvim-lspconfig

```lua
 local lspconfig = require'lspconfig'
 lspconfig.util.default_config = vim.tbl_extend(
   "force",
   lspconfig.util.default_config,
   {
     autostart = false,
     handlers = {
       ["window/logMessage"] = function(err, method, params, client_id)
           if params and params.type <= vim.lsp.protocol.MessageType.Log then
             vim.lsp.handlers["window/logMessage"](err, method, params, client_id)
           end
         end,
       ["window/showMessage"] = function(err, method, params, client_id)
           if params and params.type <= vim.lsp.protocol.MessageType.Warning.Error then
             vim.lsp.handlers["window/showMessage"](err, method, params, client_id)
           end
         end,
     }
   }
 )
```

This is documented on [`:help lspconfig-global-defaults`](https://github.com/neovim/nvim-lspconfig/blob/8a1529e46eef5efc86c34c8d9bdd313abc2ecba0/doc/lspconfig.txt#L124)

### vim.lsp.config

```lua
vim.lsp.config("*", {
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_attach = function(client, bufnr)
        -- Your custom on_attach function
    end,
})
```

This is documented on [`:help vim.lsp.config()`](https://neovim.io/doc/user/lsp.html#vim.lsp.config())
