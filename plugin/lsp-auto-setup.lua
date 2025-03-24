vim.api.nvim_create_user_command(
  "LspAutoSetupClearCache",
  function()
    local path = vim.fn.stdpath('cache') .. '/lsp-auto-setup/servers.json'

    -- Check if cache exists
    if vim.fn.filereadable(path) == 0 then
      vim.notify("Cache does not exist", vim.log.levels.INFO, { title = "LSP Auto Setup" })
      return
    end

    local removed, err = os.remove(path)
    if removed then
      vim.notify("Cache cleared", vim.log.levels.INFO, { title = "LSP Auto Setup" })
      return
    end

    vim.notify("Error while clearing cache: " .. err, vim.log.levels.ERROR, { title = "LSP Auto Setup" })
  end,
  {}
)
