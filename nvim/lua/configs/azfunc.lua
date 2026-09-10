-- Azure Functions launching, scoped to the repository rather than the cwd.
--
-- azfunc.nvim's own `start()` discovers projects by shelling out to `find .`,
-- which is relative to nvim's current directory. That works only when nvim
-- happens to be rooted at or above the Functions project — open a file from a
-- sibling directory, or start nvim inside `apps/web`, and it finds nothing.
--
-- These wrappers search from the git root of the current buffer instead, which
-- is what "start the functions for this repo" actually means. It keeps working
-- from any subdirectory, and from a linked worktree, since each worktree has
-- its own root.
--
-- Discovery is reimplemented rather than reused because the plugin's project
-- scan is a local function with no path argument. Launching still goes through
-- its public `start_from_path()`, so the terminal, spinner, and DAP attach
-- retry logic remain the plugin's.

local M = {}

---Git root for the current buffer, falling back to the cwd for unnamed
---buffers (`:enew`, the dashboard, a terminal).
---@return string|nil
local function git_root()
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= "" and vim.fn.filereadable(buf) == 1) and buf or vim.fn.getcwd()
  return vim.fs.root(start, ".git")
end

---Does this .csproj build an Azure Functions app?
---@param csproj string
---@return boolean
local function is_functions_project(csproj)
  for _, line in ipairs(vim.fn.readfile(csproj)) do
    if line:match "<AzureFunctionsVersion>" then
      return true
    end
  end
  return false
end

---Every Azure Functions project under `root`.
---
---`bin`/`obj` are pruned rather than filtered: a built .NET tree copies its
---.csproj into both, so without this the same project is found three times.
---@param root string
---@return { name: string, path: string }[]
local function find_projects(root)
  local csprojs = vim.fn.systemlist {
    "find", root,
    "(", "-name", "bin", "-o", "-name", "obj", ")", "-prune",
    "-o", "-type", "f", "-name", "*.csproj", "-print",
  }

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local projects = {}
  for _, csproj in ipairs(csprojs) do
    if is_functions_project(csproj) then
      projects[#projects + 1] = {
        name = vim.fn.fnamemodify(csproj, ":t:r"),
        path = vim.fn.fnamemodify(csproj, ":h"),
      }
    end
  end

  return projects
end

---Start the Azure Functions project for the current repository.
---
---Prompts only when the repo genuinely has more than one.
function M.start()
  local root = git_root()
  if not root then
    vim.notify("azfunc: not inside a git repository", vim.log.levels.ERROR)
    return
  end

  local projects = find_projects(root)

  if #projects == 0 then
    vim.notify("azfunc: no Azure Functions project under " .. root, vim.log.levels.ERROR)
    return
  end

  if #projects == 1 then
    vim.notify("Starting Azure Function: " .. projects[1].name)
    require("azfunc").start_from_path(projects[1].path)
    return
  end

  vim.ui.select(projects, {
    prompt = "Select Azure Functions project:",
    format_item = function(project)
      return project.name
    end,
  }, function(project)
    if project then
      vim.notify("Starting Azure Function: " .. project.name)
      require("azfunc").start_from_path(project.path)
    end
  end)
end

---Stop the running session. Straight passthrough; kept here so both halves of
---the mapping pair come from one module.
function M.stop()
  require("azfunc").stop()
end

return M
