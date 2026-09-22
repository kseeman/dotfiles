-- A markdown buffer opened from an .ipynb by jupytext.nvim (python profile).
-- The buffer keeps the notebook's name, so the extension identifies it.
local function is_notebook(bufnr)
  return vim.api.nvim_buf_get_name(bufnr):match("%.ipynb$") ~= nil
end

local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_format" },
    sql = { "sqlfluff" },
    mysql = { "sqlfluff" },
    plsql = { "sqlfluff" },
    -- Notebook cells: `injected` runs each fenced block through that
    -- language's formatter, so python cells get ruff_format. Scoped to
    -- notebooks so a README's illustrative snippets are never rewritten.
    markdown = function(bufnr)
      return is_notebook(bufnr) and { "injected" } or {}
    end,
  },

  formatters = {
    sqlfluff = {
      -- sqlfluff exits with an error if --config names a missing file, so the
      -- personal ~/.sqlfluff is optional rather than required.
      args = function()
        local args = { "format", "--dialect=postgres" }
        local config = vim.fn.expand("~/.sqlfluff")
        if vim.uv.fs_stat(config) then
          vim.list_extend(args, { "--config", config })
        end
        table.insert(args, "-")
        return args
      end,
      require_cwd = false,
    },
  },

  -- SQL formats after the write, asynchronously. sqlfluff's time grows with
  -- the file (seconds for a few dozen statements), so a blocking
  -- format_on_save would hit its timeout; this has none, and conform writes
  -- the buffer again once the result is in.
  format_after_save = function(bufnr)
    local ft = vim.bo[bufnr].filetype
    if ft == "sql" or ft == "mysql" or ft == "plsql" then
      return { lsp_format = "never" }
    end
  end,

  format_on_save = function(bufnr)
    local ft = vim.bo[bufnr].filetype

    -- The python profile also formats Python on save. Other profiles leave it
    -- to <leader>fm, since reformatting a whole file on save turns any edit
    -- to someone else's code into a large diff.
    --
    -- Notebooks are formatted on save too, but not from here: jupytext.nvim
    -- saves them through a BufWriteCmd, and Neovim sends no BufWritePre for
    -- a write a BufWriteCmd handles. See the jupytext spec in
    -- profiles/python/plugins.lua.
    if vim.g.current_nvim_profile == "python" and ft == "python" then
      return { timeout_ms = 2000, lsp_format = "never" }
    end
  end,
}

return options
