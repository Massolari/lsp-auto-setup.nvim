# LSP Auto Setup

A Neovim plugin that automatically sets up language servers based on available executables.

With this plugin you don't need to manually configure each language server in your `init.vim` or `init.lua`. It will automatically detect and set up servers based on the executables available on your system.

## Features

- Automatically detects and configures LSP servers based on available executables
- Allows custom configuration for each server
- Provides options to exclude specific servers

## Requirements

- Neovim >= 0.8.0
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Massolari/lsp-auto-setup.nvim",
  dependencies = { "neovim/nvim-lspconfig" },
  config = true
}
```

## Usage

The plugin provides a simple setup function that can be customized with options:

```lua
require("lsp-auto-setup").setup({
  -- Options here
})
```

### Default Configuration

With no options provided, the plugin will:

1. Scan all available language server configurations from `nvim-lspconfig`
2. Check if each server's executable is available on your system
3. Automatically set up servers that are found
4. Skip deprecated servers

### Configuration Options

```lua
```lua
require("lsp-auto-setup").setup({
  -- Table of server-specific configuration functions
  server_config = {
    -- Example: Add custom settings for specific servers
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
  
  -- List of server names to exclude from auto-setup
  exclude = { "tsserver", "rust_analyzer" }
})
```

## How It Works

The plugin:
1. Locates the `nvim-lspconfig` installation in your runtime path
2. Scans all available language server configurations
3. For each server, it checks if its executable is available on your system
4. If found, it sets up the server with your custom configuration or the default configuration
