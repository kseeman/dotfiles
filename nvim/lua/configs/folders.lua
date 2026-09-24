-- Fuzzy-find a folder and reveal it in nvim-tree.
--
-- Telescope's find_files only lists files, and walking nvim-tree by hand is
-- slow in a deep tree. The folder list is derived from `rg --files`, the same
-- listing find_files uses, so it honours .gitignore (build output such as
-- Maven's target/ stays out) without a hardcoded exclude list. Folders that
-- hold no files are never listed.

local M = {}

local function folders(cwd)
  local result = vim.system({ "rg", "--files", "--color", "never" }, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    return {}
  end

  -- Every ancestor of every file, not just its immediate parent, so a folder
  -- that only contains other folders is still listed.
  local seen, list = {}, {}
  for file in result.stdout:gmatch "[^\n]+" do
    local dir = vim.fs.dirname(file)
    while dir and dir ~= "." and not seen[dir] do
      seen[dir] = true
      list[#list + 1] = dir
      dir = vim.fs.dirname(dir)
    end
  end
  table.sort(list)
  return list
end

function M.pick()
  if vim.fn.executable "rg" == 0 then
    vim.notify("ripgrep (rg) not found", vim.log.levels.ERROR)
    return
  end

  local cwd = vim.uv.cwd()
  local list = folders(cwd)
  if #list == 0 then
    vim.notify("No folders found", vim.log.levels.WARN)
    return
  end

  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local conf = require("telescope.config").values

  require("telescope.pickers")
    .new({}, {
      prompt_title = "Folders",
      finder = require("telescope.finders").new_table { results = list },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            require("nvim-tree.api").tree.find_file {
              buf = vim.fs.joinpath(cwd, entry[1]),
              open = true,
              focus = true,
            }
          end
        end)
        return true
      end,
    })
    :find()
end

return M
