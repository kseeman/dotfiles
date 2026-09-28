-- Browse commits, then open a file one of them touched.
--
-- Telescope's git_commits checks the commit out on <CR>, which leaves a
-- detached HEAD when all that was wanted was to look. Here <CR> lists the
-- commit's files instead, previewing each one's change in that commit, and
-- opening one edits the working-tree copy. <C-v>/<C-x>/<C-t> split as usual.

local M = {}

-- A merge is diffed against its first parent, the branch it landed on, which
-- is what the commits list shows; a plain diff-tree lists nothing for merges.
-- Deletions are left out since there is nothing to open.
local function changed_files(root, sha)
  local result = vim
    .system({
      "git", "diff-tree", "-r", "--no-commit-id", "--name-only", "--root",
      "--diff-merges=first-parent", "--diff-filter=d", sha,
    }, { cwd = root, text = true })
    :wait()
  if result.code ~= 0 then
    return {}
  end
  return vim.split(result.stdout, "\n", { trimempty = true })
end

local function pick_file(root, sha)
  local files = changed_files(root, sha)
  if #files == 0 then
    vim.notify("No files to open in " .. sha:sub(1, 7), vim.log.levels.WARN)
    return
  end

  local conf = require("telescope.config").values
  local putils = require "telescope.previewers.utils"

  require("telescope.pickers")
    .new({}, {
      prompt_title = "Files in " .. sha:sub(1, 7),
      finder = require("telescope.finders").new_table {
        results = files,
        entry_maker = require("telescope.make_entry").gen_from_file { cwd = root },
      },
      sorter = conf.file_sorter {},
      previewer = require("telescope.previewers").new_buffer_previewer {
        title = "Change",
        define_preview = function(self, entry)
          putils.job_maker(
            { "git", "--no-pager", "show", "--format=", "--diff-merges=first-parent", sha, "--", entry.value },
            self.state.bufnr,
            {
              value = sha .. entry.value,
              bufname = self.state.bufname,
              cwd = root,
              callback = function(bufnr)
                if vim.api.nvim_buf_is_valid(bufnr) then
                  putils.highlighter(bufnr, "diff")
                end
              end,
            }
          )
        end,
      },
    })
    :find()
end

function M.pick()
  local root = vim.fs.root(vim.uv.cwd(), ".git")
  if not root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  require("telescope.builtin").git_commits {
    cwd = root,
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if entry then
          pick_file(root, entry.value)
        end
      end)
      return true
    end,
  }
end

return M
