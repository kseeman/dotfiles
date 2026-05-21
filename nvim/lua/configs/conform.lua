local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    sql = { "sqlfluff" },
    mysql = { "sqlfluff" },
    plsql = { "sqlfluff" },
  },

  formatters = {
    sqlfluff = {
      args = { "format", "--dialect=postgres", "--config", vim.fn.expand("~/.sqlfluff"), "-" },
      require_cwd = false,
    },
  },

  format_on_save = function(bufnr)
    local ft = vim.bo[bufnr].filetype
    if ft == "sql" or ft == "mysql" or ft == "plsql" then
      return { timeout_ms = 2000, lsp_format = "never" }
    end
  end,
}

return options
