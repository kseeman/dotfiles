# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository containing a Neovim configuration built on NvChad v2.5. The configuration features a custom multi-profile system that loads different plugin sets and configurations based on the development environment (default, .NET, or Java).

## Profile System Architecture

The profile system is the core architectural feature of this config. Understanding how it works requires reading multiple files:

### Profile Loading Flow

1. **`nvim/init.lua`** - Entry point that initializes the profile manager before loading plugins
2. **`nvim/lua/profile-manager.lua`** - Contains profile detection logic (checks `vim.g.nvim_profile`, env var `NVIM_PROFILE`, or persisted file)
3. **`nvim/lua/profiles/{profile}/plugins.lua`** - Profile-specific plugin configurations that get loaded by the profile manager
4. **`nvim/lua/configs/lspconfig.lua`** - General LSP configuration that applies across all profiles

### Key Profile System Details

- Profile selection order: command-line flag (`vim.g.nvim_profile`) → environment variable → persisted file (`~/.local/share/nvim/data/current_profile`) → "default"
- Profiles can be switched interactively via `:ProfileSwitch`, but requires a restart to take effect
- Each profile returns a Lua table of lazy.nvim plugin specifications
- The profile manager provides cross-platform utilities: `detect_os()`, `detect_arch()`, and `get_config_dir_name()`

### Cross-Platform Architecture Detection

The profile manager includes OS and architecture detection that's crucial for tools like jdtls:

- `M.detect_os()` returns `'mac'`, `'linux'`, or `'windows'`
- `M.detect_arch()` detects ARM vs x86_64 (important for Apple Silicon)
- `M.get_config_dir_name()` returns the correct jdtls config directory name (e.g., `config_mac_arm` for Apple Silicon)

**Critical for jdtls setup**: The Java profile uses these functions to dynamically select the correct jdtls configuration directory. On Apple Silicon, this must be `config_mac_arm`, not `config_mac`.

## LSP Configuration Gotchas

### jdtls Special Handling

jdtls (Java LSP) is **NOT** included in the `servers` list in `nvim/lua/configs/lspconfig.lua` because the `nvim-jdtls` plugin manages it separately with a custom configuration in the Java profile. Adding it to both places causes conflicts.

The Java profile configuration:
- Uses `vim.fn.glob()` to find the launcher jar (wildcards don't expand in Lua arrays)
- Must include both `on_attach` (for keymaps) and `capabilities` (for features like completion)
- Requires calling `require("nvchad.configs.lspconfig").on_attach()` to set up standard LSP keymaps like `gd`

### LSP on_attach Chain

All custom `on_attach` functions must call NvChad's default `on_attach` **first** to ensure standard LSP keymaps are set up:

```lua
local on_attach = function(client, bufnr)
  require("nvchad.configs.lspconfig").on_attach(client, bufnr)
  -- Then add custom keymaps or setup
end
```

## Test Runner System

The test runner (`nvim/lua/configs/test-runner.lua`) is a custom implementation that auto-detects test types and generates appropriate commands.

### Architecture

- **Pattern-based detection**: Each test type has a `pattern()` function that matches file paths
- **Command generators**: Functions like `run_file()`, `run_all()`, `debug_file()` dynamically build commands
- **Project-aware**: Detects Maven vs Gradle for Java, checks for Playwright config files
- **Cursor-aware**: `get_test_name_under_cursor()` extracts test names using regex patterns for different test frameworks

### Supported Test Types

- **Playwright/Jest** (TypeScript/JavaScript): Detects `*.spec.ts`, `*.test.ts` files
- **Java**: Detects `*Test.java`, `*Tests.java`, `*IT.java` files, generates Maven/Gradle commands
- **.NET**: Detects `*Test.cs`, `*Tests.cs` files, uses `dotnet test --filter`

### Keymaps

- `<leader>rt` - Run current test file
- `<leader>rT` - Run all tests
- `<leader>rs` - Run single test under cursor
- `<leader>dt` - Debug current test file
- `<leader>dT` - Debug all tests
- `<leader>ds` - Debug single test under cursor

## Local Commands System

The `nvim/lua/local-commands.lua` file is git-ignored and provides project-specific commands. The system:

1. Checks if loaded via `pcall()` in `nvim/lua/mappings.lua`
2. Only sets up commands if in the target project (uses git root detection)
3. Provides custom commands for running/debugging specific applications with Maven

This pattern allows work-specific configurations without polluting the main config.

## DAP (Debug Adapter Protocol) Setup

### Multi-Language Support

The DAP configuration (`nvim/lua/configs/dap.lua`) supports:

- **.NET**: Uses `netcoredbg` from Mason, supports both launch and attach
- **Java**: Attach-only configuration on port 5005 (assumes remote debugging enabled)
- **TypeScript/JavaScript**: Uses `pwa-node` adapter for Node.js debugging

### Auto UI Behavior

DAP UI automatically opens on debug session start and closes on termination/exit via listeners. This can be disabled by removing the listeners at the bottom of `dap.lua`.

### Debugging Keymaps

- `<F5>` - Start/Continue
- `<F9>` - Toggle breakpoint
- `<F1>/<F2>/<F3>` - Step into/over/out
- `<F7>` - Toggle DAP UI
- `<leader>db` - Toggle breakpoint (alternative)

## Working with Profiles

### Testing Profile Changes

When modifying profile configurations:

1. Edit the profile's `plugins.lua` file
2. Run `:ProfileRestart` or restart nvim manually
3. Run `:Lazy sync` to install/update plugins
4. Check `:Lazy` to verify plugins loaded correctly

### Adding New Language Profiles

To add a new profile (e.g., Python):

1. Create `nvim/lua/profiles/python/plugins.lua` returning a lazy.nvim spec table
2. Add `"python"` to `M.profiles` array in `profile-manager.lua`
3. Follow the pattern from existing profiles for LSP setup (remember to call NvChad's `on_attach`)

### Common Profile Issues

- **LSP keymaps not working**: Check that `on_attach` calls `require("nvchad.configs.lspconfig").on_attach(client, bufnr)`
- **Plugins not loading**: Verify the profile returns a proper table structure, check `:Lazy` for errors
- **jdtls not starting**: Check launcher jar exists, config directory matches OS/arch, and jdtls is NOT in lspconfig servers list

## Git Ignore Patterns

Important git-ignored files:
- `nvim/lazy-lock.json` - Plugin version lockfile (tracked, but may have local changes)
- `nvim/lua/local-commands.lua` - Project-specific commands (should be git-ignored for work-specific code)

## Mason Package Dependencies

Language servers and debuggers are installed via Mason:

- **Java**: `jdtls`, `java-debug-adapter`
- **.NET**: `omnisharp`, `netcoredbg`
- **TypeScript**: `typescript-language-server`, `js-debug-adapter`

Install missing packages: `:Mason` then search and press `i` to install.

## Customization Patterns

### Adding Custom Keymaps

Add to `nvim/lua/mappings.lua` after line 5 (`local map = vim.keymap.set`). The file already loads at the end of initialization via `vim.schedule()`.

### Adding LSP Servers

For standard LSP servers (not jdtls):
1. Add server name to `servers` array in `nvim/lua/configs/lspconfig.lua`
2. Install via Mason if needed
3. The config applies NvChad defaults + custom `on_attach`

### Profile-Specific Keymaps

Add keymaps in the profile's plugin config function, not in global mappings.lua. This keeps profile-specific bindings isolated.
