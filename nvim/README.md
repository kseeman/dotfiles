# Kelly's Nvim Configuration

A powerful Neovim configuration built on NvChad with multi-profile support for different development environments.

## Overview

This configuration extends NvChad with:
- **Multi-profile system** for language-specific development environments
- Enhanced LSP support for .NET, Java and Python development
- Interactive Jupyter notebooks (Python profile)
- Debugging capabilities via DAP
- Integrated testing frameworks
- Custom keymaps and productivity features

## Base Configuration

Built on **NvChad v2.5** using:
- **Lazy.nvim** for plugin management
- **Treesitter** for syntax highlighting and language features
- **LSP** integration with language servers
- **DAP** for debugging support
- **Telescope** for fuzzy finding
- **NvimTree** for file exploration

## Multi-Profile System

This configuration supports multiple profiles optimized for different development environments:

### Available Profiles

- **default**: General-purpose configuration with basic plugins
- **dotnet**: .NET development with C#, F#, omnisharp, debugging, and testing tools
- **java**: Java development with jdtls, Maven/Gradle support, debugging, and testing
- **python**: Python development with pyright/ruff, debugging, pytest, and interactive Jupyter notebooks

### Using Profiles

#### Method 1: Environment Variable
```bash
export NVIM_PROFILE=dotnet
nvim

# Or for a single session:
NVIM_PROFILE=java nvim
```

#### Method 2: Command Line Argument
```bash
nvim --cmd "lua vim.g.nvim_profile='dotnet'"
nvim --cmd "lua vim.g.nvim_profile='java'"
```

#### Method 3: Interactive Switching
Inside nvim, use these commands:
- `:ProfileSwitch` - Open profile selection menu
- `:ProfileStatus` - Show current profile
- `:ProfileRestart` - Restart nvim with current profile
- `:ProfileClear` - Clear saved profile preference

#### Method 4: Keymaps
- `<leader>ps` - Switch profile
- `<leader>pr` - Restart with current profile  
- `<leader>pi` - Show profile info
- `<leader>pc` - Clear saved profile

### Profile-Specific Features

#### Dotnet Profile
- **Languages**: C#, F#, Visual Basic
- **LSP**: Omnisharp with Roslyn analyzers
- **Debugging**: Full .NET debugging support via DAP
- **Testing**: Neotest integration for .NET tests
- **Package Management**: NuGet integration
- **Documentation**: XML doc generation with Neogen
- **Project Detection**: .sln, .csproj, .fsproj files
- **Build Tools**: MSBuild integration
- **Azure Functions**: Seamless debugging with automatic DAP integration
- **Additional Plugins**: csharp.nvim, neotest-dotnet, omnisharp-extended-lsp, azfunc.nvim

#### Java Profile  
- **Languages**: Java, Kotlin, Groovy
- **LSP**: Eclipse JDT Language Server (jdtls)
- **Debugging**: Java debugging via DAP
- **Testing**: JUnit/TestNG support via Neotest
- **Build Tools**: Maven and Gradle integration
- **Framework Support**: Spring Boot integration
- **Project Detection**: pom.xml, build.gradle, gradlew files
- **Documentation**: Javadoc generation with Neogen
- **Additional Plugins**: nvim-jdtls, neotest-java, maven.nvim, spring-boot.nvim

#### Python Profile
- **Languages**: Python, plus Jupyter notebooks (`.ipynb`)
- **LSP**: pyright for types, ruff for linting (both via Mason). pyright uses the project's `.venv`/`venv` when there is one
- **Formatting**: ruff formats `.py` files and notebook cells on save (and on `<leader>fm`)
- **Notebooks**: molten-nvim runs code in a real Jupyter kernel with output, including plots, shown inline under each cell
- **Notebook editing**: jupytext.nvim opens `.ipynb` as markdown and saves it back as a notebook; quarto-nvim + otter.nvim give LSP and completion inside the code cells
- **Debugging**: debugpy via nvim-dap-python
- **Testing**: pytest via Neotest and the custom test runner, using the project's `.venv`/`venv` when there is one
- **Documentation**: Google-style docstrings with Neogen
- **Project Detection**: pyproject.toml, setup.py, setup.cfg, requirements.txt, Pipfile
- **Additional Plugins**: molten-nvim, quarto-nvim, otter.nvim, jupytext.nvim, nvim-dap-python, neotest-python

## Key Features

### Enhanced Keymaps
- `;` - Enter command mode (instead of `:`)
- `jk` - Exit insert mode
- `J/K` in visual mode - Move lines up/down
- `<C-d>/<C-u>` - Page down/up with cursor centering
- `<leader>s` - Find and replace current word/selection
- `<C-/>` - Toggle comments
- `<C-`>` - Toggle floating terminal

### Git Integration
- `<leader>gc` - Git commits (Telescope)
- `<leader>gb` - Git branches
- `<leader>gs` - Git status
- `<leader>gf` - Git files
- `<leader>gh` - Git buffer history
- `<leader>gd` - Git diff current file
- `<leader>gr` - Git reset hunk
- `<leader>gp` - Git preview hunk

### LSP & Navigation
- `gI` - Go to implementation
- `<leader>li` - LSP implementations (Telescope)
- Folding: `zR`, `zM`, `za`, `zo`, `zc`, `zj`, `zk`

### Custom Test Runner
Integrated test runner with language detection and execution.

### Azure Functions (Dotnet Profile)
- `<leader>as` - Start Azure Functions debugging
- `<leader>aS` - Stop Azure Functions debugging

### Jupyter (Python Profile)

Open a `.ipynb` and its kernel starts automatically, if the notebook names one
that is registered (otherwise pick one with `<leader>ji`). The notebook's
metadata header is folded closed; `za` opens it. Code cells are the
` ```python ` blocks. The cell commands (`jc`, `ja`, `jA`)
only work there; in a plain `.py` file, run lines and selections with `jl`/`je`.

- `<leader>ji` - Start a kernel (pick from the installed kernelspecs); automatic for notebooks that name a registered one
- `<leader>jc` - Run the cell under the cursor
- `<leader>ja` / `<leader>jA` - Run all cells above / every cell
- `<leader>jl` - Run the current line
- `<leader>je` - Run a motion (normal) or the selection (visual)
- `<leader>jr` - Re-run the cell molten last ran here
- `<leader>jo` - Enter the output window (scroll, yank)
- `<leader>jh` - Hide output
- `<leader>jm` - Open image output in a popup
- `<leader>jn` / `<leader>jp` - Next / previous cell
- `<leader>jx` - Delete the cell's output
- `<leader>jk` - Interrupt the kernel
- `<leader>jR` - Restart the kernel
- `<leader>jd` - Stop the kernel

The Jupyter host runs from its own venv at `~/.local/opt/nvim-python`, created
by `install.sh`. That venv ships a `python3` kernel, so `<leader>ji` works right
away, but that kernel only sees the venv's own packages. To run a notebook
against a project's dependencies, register the project's venv as a kernel once:

```bash
.venv/bin/pip install ipykernel
.venv/bin/python -m ipykernel install --user --name my-project
```

It then appears in the `<leader>ji` picker. After the first install (or a
`:Lazy update` of molten), restart nvim once so the `:Molten*` commands appear.

## File Structure
```
.
├── init.lua                 # Main configuration entry point
├── lazy-lock.<profile>.json # Plugin version lock file, one per profile
├── lua/
│   ├── profile-manager.lua  # Profile management logic
│   ├── profiles/
│   │   ├── default/
│   │   │   └── plugins.lua  # Default profile plugins
│   │   ├── dotnet/
│   │   │   └── plugins.lua  # .NET development plugins
│   │   ├── java/
│   │   │   └── plugins.lua  # Java development plugins
│   │   └── python/
│   │       └── plugins.lua  # Python + Jupyter plugins
│   ├── plugins/
│   │   └── init.lua         # Legacy plugin configuration
│   ├── configs/
│   │   ├── conform.lua      # Code formatting config
│   │   ├── dap.lua          # Debug adapter config
│   │   ├── lazy.lua         # Lazy.nvim configuration
│   │   ├── lspconfig.lua    # LSP server configurations
│   │   └── test-runner.lua  # Test execution logic
│   ├── chadrc.lua          # NvChad configuration
│   ├── options.lua         # Vim options
│   ├── mappings.lua        # Key mappings
│   └── autocmds.lua        # Autocommands
└── README.md               # This file
```

## Adding New Profiles

1. Create a new directory: `lua/profiles/your_profile/`
2. Add `plugins.lua` with your profile-specific plugins
3. Update `M.profiles` array in `lua/profile-manager.lua`
4. Restart nvim to use the new profile

## Installation

1. Backup your existing nvim config:
```bash
mv ~/.config/nvim ~/.config/nvim.backup
```

2. Clone this configuration:
```bash
git clone <your-repo-url> ~/.config/nvim
```

3. Start nvim and let plugins install automatically

4. Choose your profile:
```bash
NVIM_PROFILE=dotnet nvim  # For .NET development
NVIM_PROFILE=java nvim    # For Java development
NVIM_PROFILE=python nvim  # For Python and Jupyter notebooks
nvim                      # For default profile
```

## Dependencies

### Required
- Neovim >= 0.9.0
- Git
- A C compiler (for Treesitter)
- Node.js (for some LSP servers)

### Language-Specific Dependencies

#### For .NET Profile
- .NET SDK
- omnisharp-roslyn language server (installed via Mason)
- netcoredbg debugger (Mason on Linux; `~/.local/opt` on Apple Silicon — see
  [SETUP_DOTNET_DEBUGGING.md](SETUP_DOTNET_DEBUGGING.md))

#### For Java Profile
- JDK 17+
- Eclipse JDT Language Server (installed via Mason)
- java-debug-adapter (installed via Mason)
- Maven or Gradle (optional)

#### For Python Profile
- Python 3, and the `~/.local/opt/nvim-python` venv that `install.sh` builds
  (pynvim, jupyter_client, ipykernel, jupytext)
- ImageMagick (`magick`) and a terminal with the Kitty graphics protocol, for
  plot output
- pyright, ruff and debugpy (installed automatically via Mason on first launch)

## Credits

- Built on [NvChad](https://github.com/NvChad/NvChad) v2.5
- Inspired by [LazyVim starter](https://github.com/LazyVim/starter)
- Profile system custom implementation
