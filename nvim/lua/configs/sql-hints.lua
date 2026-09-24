-- Column names beside INSERT values, the way IntelliJ's database tools show
-- them: `VALUES (id: 1, name: 'Kelly')`. No SQL language server sends inlay
-- hints, so these are drawn from the tree-sitter parse instead. That needs no
-- database connection, but it does need the statement to list its columns;
-- `INSERT INTO t VALUES (...)` gets no hints.
--
-- They follow the LSP inlay-hint switch rather than keeping their own, so
-- <leader>ih toggles both. Values named the same as their column are skipped,
-- as jdtls does for arguments.
local M = {}

local ns = vim.api.nvim_create_namespace("sql_insert_hints")
local FILETYPES = { sql = true, mysql = true, plsql = true }

local query

-- The expressions an INSERT supplies, one list per row: each VALUES tuple, or
-- the select list of an INSERT ... SELECT. The column list is the first
-- `list` of `column` nodes; every `list` after the VALUES keyword is a row.
local function columns_and_rows(insert)
  local columns, rows, in_values = nil, {}, false
  for child in insert:iter_children() do
    local type = child:type()
    if type == "keyword_values" then
      in_values = true
    elseif type == "list" then
      local first = child:named_child(0)
      if not in_values and not columns and first and first:type() == "column" then
        columns = child
      elseif in_values then
        table.insert(rows, child)
      end
    elseif type == "select" then
      for sub in child:iter_children() do
        if sub:type() == "select_expression" then
          table.insert(rows, sub)
        end
      end
    end
  end
  return columns, rows
end

local function named_nodes(node)
  local nodes = {}
  for child in node:iter_children() do
    if child:named() and child:type() ~= "comment" then
      table.insert(nodes, child)
    end
  end
  return nodes
end

function M.refresh(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not vim.lsp.inlay_hint.is_enabled() then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "sql")
  if not ok or not parser then
    return
  end
  query = query or vim.treesitter.query.parse("sql", "(insert) @insert")
  local root = parser:parse()[1]:root()

  for _, insert in query:iter_captures(root, buf) do
    local columns, rows = columns_and_rows(insert)
    if columns then
      local names = vim.tbl_map(function(column)
        return vim.treesitter.get_node_text(column, buf)
      end, named_nodes(columns))

      for _, row in ipairs(rows) do
        for i, value in ipairs(named_nodes(row)) do
          local name = names[i]
          local text = vim.treesitter.get_node_text(value, buf)
          if name and text:lower() ~= name:lower() then
            local line, col = value:start()
            vim.api.nvim_buf_set_extmark(buf, ns, line, col, {
              virt_text = { { name .. ":", "LspInlayHint" }, { " " } },
              virt_text_pos = "inline",
            })
          end
        end
      end
    end
  end
end

function M.refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and FILETYPES[vim.bo[buf].filetype] then
      M.refresh(buf)
    end
  end
end

-- Global autocmds filtered by filetype, not buffer-local ones, so `:Reload`
-- re-running this keeps already-open SQL buffers covered. mappings.lua runs
-- after startup, when a file named on the command line has already had its
-- FileType and BufEnter, hence the refresh_all() at the end.
function M.setup()
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("SqlInsertHints", { clear = true }),
    callback = function(args)
      if FILETYPES[vim.bo[args.buf].filetype] then
        M.refresh(args.buf)
      end
    end,
  })
  M.refresh_all()
end

return M
