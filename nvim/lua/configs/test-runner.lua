local M = {}

-- Test detection and command configuration
local test_configs = {
  -- Playwright (TypeScript/JavaScript)
  playwright = {
    pattern = function(filepath)
      return filepath:match("%.spec%.ts$") or filepath:match("%.test%.ts$") or filepath:match("%.spec%.js$") or filepath:match("%.test%.js$")
    end,
    run_file = function(filepath)
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      table.insert(args, filepath)
      return table.concat(args, ' ')
    end,
    run_all = function()
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      return table.concat(args, ' ')
    end,
    debug_file = function(filepath)
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test', '--debug'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      table.insert(args, filepath)
      return table.concat(args, ' ')
    end,
    debug_all = function()
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test', '--debug'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      return table.concat(args, ' ')
    end,
    run_single = function(filepath, test_name)
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      table.insert(args, filepath)
      table.insert(args, '--grep')
      table.insert(args, '"' .. test_name .. '"')
      return table.concat(args, ' ')
    end,
    debug_single = function(filepath, test_name)
      local config = M.get_playwright_config()
      local args = {'npx', 'playwright', 'test', '--debug'}
      if config then
        table.insert(args, '--config')
        table.insert(args, config)
      end
      table.insert(args, filepath)
      table.insert(args, '--grep')
      table.insert(args, '"' .. test_name .. '"')
      return table.concat(args, ' ')
    end,
  },

  -- Java (Maven/Gradle)
  java = {
    pattern = function(filepath)
      return filepath:match("Test%.java$") or filepath:match("Tests%.java$") or filepath:match("IT%.java$")
    end,
    run_file = function(filepath)
      -- Extract test class name from filepath
      local class_name = filepath:match("([^/]+)%.java$"):gsub("%.java$", "")
      
      -- Check if it's Maven or Gradle project
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test -Dtest=' .. class_name
      elseif vim.fn.filereadable(vim.fn.getcwd() .. '/build.gradle') == 1 or vim.fn.filereadable(vim.fn.getcwd() .. '/build.gradle.kts') == 1 then
        return './gradlew test --tests ' .. class_name
      else
        return 'java -cp . org.junit.runner.JUnitCore ' .. class_name
      end
    end,
    run_all = function()
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test'
      elseif vim.fn.filereadable(vim.fn.getcwd() .. '/build.gradle') == 1 or vim.fn.filereadable(vim.fn.getcwd() .. '/build.gradle.kts') == 1 then
        return './gradlew test'
      else
        return 'mvn test'  -- Default fallback
      end
    end,
    debug_file = function(filepath)
      -- For Java debugging, we'll need to set up remote debugging
      local class_name = filepath:match("([^/]+)%.java$"):gsub("%.java$", "")
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test -Dtest=' .. class_name .. ' -Dmaven.surefire.debug'
      else
        return './gradlew test --tests ' .. class_name .. ' --debug-jvm'
      end
    end,
    debug_all = function()
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test -Dmaven.surefire.debug'
      else
        return './gradlew test --debug-jvm'
      end
    end,
    run_single = function(filepath, test_name)
      local class_name = filepath:match("([^/]+)%.java$"):gsub("%.java$", "")
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test -Dtest=' .. class_name .. '#' .. test_name
      else
        return './gradlew test --tests ' .. class_name .. '.' .. test_name
      end
    end,
    debug_single = function(filepath, test_name)
      local class_name = filepath:match("([^/]+)%.java$"):gsub("%.java$", "")
      if vim.fn.filereadable(vim.fn.getcwd() .. '/pom.xml') == 1 then
        return 'mvn test -Dtest=' .. class_name .. '#' .. test_name .. ' -Dmaven.surefire.debug'
      else
        return './gradlew test --tests ' .. class_name .. '.' .. test_name .. ' --debug-jvm'
      end
    end,
  },

  -- .NET (C#)
  dotnet = {
    pattern = function(filepath)
      return filepath:match("Test%.cs$") or filepath:match("Tests%.cs$") or filepath:match("Spec%.cs$")
    end,
    run_file = function(filepath)
      -- Extract test class name or use filter
      local class_name = filepath:match("([^/]+)%.cs$"):gsub("%.cs$", "")
      return 'dotnet test --filter ClassName=' .. class_name
    end,
    run_all = function()
      return 'dotnet test'
    end,
    debug_file = function(filepath)
      local class_name = filepath:match("([^/]+)%.cs$"):gsub("%.cs$", "")
      return 'dotnet test --filter ClassName=' .. class_name .. ' --logger "console;verbosity=detailed"'
    end,
    debug_all = function()
      return 'dotnet test --logger "console;verbosity=detailed"'
    end,
  },
}

-- Helper function for Playwright config
function M.get_playwright_config()
  local cwd = vim.fn.getcwd()
  local playwright_config = cwd .. '/playwright.config.ts'
  if vim.fn.filereadable(playwright_config) == 1 then
    return playwright_config
  end
  return nil
end

-- Detect test type based on current file
function M.detect_test_type(filepath)
  filepath = filepath or vim.fn.expand('%:p')
  
  for test_type, config in pairs(test_configs) do
    if config.pattern(filepath) then
      return test_type, config
    end
  end
  
  return nil, nil
end

-- Extract test name under cursor
function M.get_test_name_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  
  -- Look for test patterns around the cursor
  for i = row, math.max(1, row - 10), -1 do
    local check_line = vim.api.nvim_buf_get_lines(0, i-1, i, false)[1]
    if check_line then
      -- Playwright/Jest: test('name') or it('name')
      local playwright_match = check_line:match('test%s*%(%s*["\']([^"\']*)') or check_line:match('it%s*%(%s*["\']([^"\']*)') 
      if playwright_match then
        return playwright_match
      end
      
      -- Java: @Test followed by method name
      if check_line:match('@Test') then
        -- Look for method name on next few lines
        for j = i, math.min(vim.api.nvim_buf_line_count(0), i + 3) do
          local method_line = vim.api.nvim_buf_get_lines(0, j-1, j, false)[1]
          local java_match = method_line and method_line:match('void%s+([%w_]+)%s*%(')
          if java_match then
            return java_match
          end
        end
      end
    end
  end
  
  return nil
end

-- Generic test runner functions
function M.run_current_test()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for file: " .. filepath, vim.log.levels.WARN)
    return
  end
  
  local cmd = config.run_file(filepath)
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

function M.run_all_tests()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for current project", vim.log.levels.WARN)
    return
  end
  
  local cmd = config.run_all()
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

function M.debug_current_test()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for file: " .. filepath, vim.log.levels.WARN)
    return
  end
  
  local cmd = config.debug_file(filepath)
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

function M.debug_all_tests()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for current project", vim.log.levels.WARN)
    return
  end
  
  local cmd = config.debug_all()
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

-- Run single test under cursor
function M.run_single_test()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for file: " .. filepath, vim.log.levels.WARN)
    return
  end
  
  if not config.run_single then
    vim.notify("Single test running not supported for this test type: " .. test_type, vim.log.levels.WARN)
    return
  end
  
  local test_name = M.get_test_name_under_cursor()
  if not test_name then
    vim.notify("No test found under cursor. Place cursor on or near a test function.", vim.log.levels.WARN)
    return
  end
  
  local cmd = config.run_single(filepath, test_name)
  vim.notify("Running test: " .. test_name)
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

-- Debug single test under cursor
function M.debug_single_test()
  local filepath = vim.fn.expand('%:p')
  local test_type, config = M.detect_test_type(filepath)
  
  if not config then
    vim.notify("No test configuration found for file: " .. filepath, vim.log.levels.WARN)
    return
  end
  
  if not config.debug_single then
    vim.notify("Single test debugging not supported for this test type: " .. test_type, vim.log.levels.WARN)
    return
  end
  
  local test_name = M.get_test_name_under_cursor()
  if not test_name then
    vim.notify("No test found under cursor. Place cursor on or near a test function.", vim.log.levels.WARN)
    return
  end
  
  local cmd = config.debug_single(filepath, test_name)
  vim.notify("Debugging test: " .. test_name)
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
  vim.cmd('startinsert')
end

-- Setup keymaps
function M.setup()
  vim.keymap.set('n', '<leader>rt', M.run_current_test, { desc = 'Run Current Test File' })
  vim.keymap.set('n', '<leader>rT', M.run_all_tests, { desc = 'Run All Tests' })
  vim.keymap.set('n', '<leader>rs', M.run_single_test, { desc = 'Run Single Test Under Cursor' })
  vim.keymap.set('n', '<leader>dt', M.debug_current_test, { desc = 'Debug Current Test File' })
  vim.keymap.set('n', '<leader>dT', M.debug_all_tests, { desc = 'Debug All Tests' })
  vim.keymap.set('n', '<leader>ds', M.debug_single_test, { desc = 'Debug Single Test Under Cursor' })
end

return M