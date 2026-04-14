local M = {}

-- Available profiles
M.profiles = {
  "default",
  "dotnet",
  "java"
}

-- Detect operating system
function M.detect_os()
  local system = vim.loop.os_uname().sysname
  if system == 'Darwin' then
    return 'mac'
  elseif system:match('Windows') then
    return 'windows'
  else
    return 'linux'
  end
end

-- Detect CPU architecture
function M.detect_arch()
  local machine = vim.loop.os_uname().machine
  -- arm64, aarch64, arm (Apple Silicon, ARM Linux)
  if machine:match('arm') or machine:match('aarch64') then
    return 'arm'
  else
    return 'x86_64'
  end
end

-- Get OS-specific config name (for tools like jdtls)
function M.get_config_dir_name()
  local os = M.detect_os()
  local arch = M.detect_arch()
  local suffix = arch == 'arm' and '_arm' or ''

  if os == 'mac' then
    return 'config_mac' .. suffix
  elseif os == 'windows' then
    return 'config_win'  -- Windows doesn't have ARM suffix in jdtls
  else
    return 'config_linux' .. suffix
  end
end

-- Get current profile name
function M.get_current_profile()
  -- Check global variable first (set via command line)
  if vim.g.nvim_profile then
    return vim.g.nvim_profile
  end
  
  -- Check environment variable
  local env_profile = vim.fn.getenv("NVIM_PROFILE")
  if env_profile ~= vim.NIL and env_profile ~= "" then
    return env_profile
  end
  
  -- Check persisted profile file
  local profile_file = vim.fn.stdpath("data") .. "/current_profile"
  local file = io.open(profile_file, "r")
  if file then
    local saved_profile = file:read("*all"):gsub("%s+", "")
    file:close()
    if saved_profile ~= "" and M.profile_exists(saved_profile) then
      return saved_profile
    end
  end
  
  -- Default fallback
  return "default"
end

-- Check if profile exists
function M.profile_exists(profile)
  for _, p in ipairs(M.profiles) do
    if p == profile then
      return true
    end
  end
  return false
end

-- Load profile configuration
function M.load_profile(profile)
  if not M.profile_exists(profile) then
    vim.notify("Profile '" .. profile .. "' does not exist. Using default.", vim.log.levels.WARN)
    profile = "default"
  end
  
  vim.g.current_nvim_profile = profile
  
  -- Load profile-specific plugins
  local profile_plugins = "profiles." .. profile .. ".plugins"
  local ok, plugins = pcall(require, profile_plugins)
  if ok then
    return plugins
  else
    vim.notify("Could not load plugins for profile: " .. profile, vim.log.levels.ERROR)
    return {}
  end
end

-- Switch profile (requires restart)
function M.switch_profile()
  vim.ui.select(M.profiles, {
    prompt = "Select profile:",
    format_item = function(item)
      local current = M.get_current_profile()
      if item == current then
        return item .. " (current)"
      end
      return item
    end
  }, function(choice)
    if choice then
      if choice == M.get_current_profile() then
        vim.notify("Already using profile: " .. choice)
        return
      end
      
      -- Set the profile and provide restart instructions
      vim.g.nvim_profile = choice
      vim.notify("Profile set to: " .. choice .. "\nRestart nvim or use :ProfileRestart", vim.log.levels.INFO)
      
      -- Optionally write to a file for persistence
      local profile_file = vim.fn.stdpath("data") .. "/current_profile"
      local file = io.open(profile_file, "w")
      if file then
        file:write(choice)
        file:close()
      end
    end
  end)
end

-- Restart nvim with current profile
function M.restart_with_profile()
  local current = vim.g.nvim_profile or M.get_current_profile()
  vim.cmd("silent! wall") -- Save all files
  
  -- Get current working directory and arguments
  local cwd = vim.fn.getcwd()
  local args = vim.fn.argv()
  local args_str = ""
  if #args > 0 then
    args_str = table.concat(args, " ")
  end
  
  -- Create restart command
  local restart_cmd
  if current == "default" then
    -- For default profile, just restart normally
    restart_cmd = string.format([[cd '%s' && nvim %s]], cwd, args_str)
  else
    -- For other profiles, use command line argument
    restart_cmd = string.format([[cd '%s' && nvim --cmd "lua vim.g.nvim_profile='%s'" %s]], cwd, current, args_str)
  end
  
  -- Execute restart in background
  vim.fn.jobstart({"bash", "-c", restart_cmd}, {detach = true})
  
  -- Close nvim
  vim.defer_fn(function()
    vim.cmd("qall!")
  end, 100)
end

-- Clear persisted profile (reset to environment/command-line control)
function M.clear_persisted_profile()
  local profile_file = vim.fn.stdpath("data") .. "/current_profile"
  os.remove(profile_file)
  vim.notify("Persisted profile cleared. Profile will now be determined by environment variable or command line.", vim.log.levels.INFO)
end

-- Get profile status for statusline
function M.get_status()
  local profile = vim.g.current_nvim_profile or "unknown"
  return "[" .. profile:upper() .. "]"
end

return M
