local dap = require("dap")
local dapui = require("dapui")

-- Setup DAP UI
dapui.setup({
  controls = {
    element = "repl",
    enabled = true,
    icons = {
      disconnect = "",
      pause = "",
      play = "",
      run_last = "",
      step_back = "",
      step_into = "",
      step_out = "",
      step_over = "",
      terminate = ""
    }
  },
  element_mappings = {},
  expand_lines = true,
  floating = {
    border = "single",
    mappings = {
      close = { "q", "<Esc>" }
    }
  },
  force_buffers = true,
  icons = {
    collapsed = "",
    current_frame = "",
    expanded = ""
  },
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.25 },
        { id = "breakpoints", size = 0.25 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 }
      },
      position = "left",
      size = 40
    },
    {
      elements = {
        { id = "repl", size = 0.5 },
        { id = "console", size = 0.5 }
      },
      position = "bottom",
      size = 10
    }
  },
  mappings = {
    edit = "e",
    expand = { "<CR>", "<2-LeftMouse>" },
    open = "o",
    remove = "d",
    repl = "r",
    toggle = "t"
  },
  render = {
    indent = 1,
    max_value_lines = 100
  }
})

-- Setup virtual text for variables
require("nvim-dap-virtual-text").setup({
  enabled = true,
  enabled_commands = true,
  highlight_changed_variables = true,
  highlight_new_as_changed = false,
  show_stop_reason = true,
  commented = false,
  only_first_definition = true,
  all_references = false,
  clear_on_continue = false,
  display_callback = function(variable, buf, stackframe, node, options)
    if options.virt_text_pos == 'inline' then
      return ' = ' .. variable.value
    else
      return variable.name .. ' = ' .. variable.value
    end
  end,
  virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',
  all_frames = false,
  virt_lines = false,
  virt_text_win_col = nil
})

-- Java DAP configuration
dap.configurations.java = {
  {
    type = 'java',
    request = 'attach',
    name = "Debug (Attach) - Remote",
    hostName = "127.0.0.1",
    port = 5005,
  },
}

-- TypeScript/JavaScript DAP configuration using js-debug-adapter
dap.adapters['pwa-node'] = {
  type = 'server',
  host = 'localhost',
  port = '${port}',
  executable = {
    command = 'node',
    args = {
      vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js',
      '${port}'
    },
  },
}

dap.configurations.typescript = {
  {
    name = 'Launch TypeScript',
    type = 'pwa-node',
    request = 'launch',
    program = '${file}',
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    skipFiles = {'<node_internals>/**'},
  },
  {
    name = 'Attach to Node Process',
    type = 'pwa-node',
    request = 'attach',
    processId = require'dap.utils'.pick_process,
    skipFiles = {'<node_internals>/**'},
  },
}

dap.configurations.javascript = dap.configurations.typescript



-- Add simplified DAP configurations for Node debugging (not Playwright)
table.insert(dap.configurations.typescript, {
  name = 'Debug Node.js Script',
  type = 'pwa-node',
  request = 'launch',
  program = '${file}',
  cwd = vim.fn.getcwd(),
  sourceMaps = true,
  skipFiles = {'<node_internals>/**'},
})

-- Auto open/close DAP UI
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

-- Key mappings
vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() dap.step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() dap.step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() dap.step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<F9>', function() dap.toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>dB', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, { desc = 'Debug: Set Breakpoint with Condition' })

-- Toggle DAP UI
vim.keymap.set('n', '<F7>', function() dapui.toggle() end, { desc = 'Debug: Toggle UI' })