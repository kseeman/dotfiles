# .NET Debugging Setup

## Install netcoredbg Debugger

You need to install the `netcoredbg` debugger for .NET debugging support. Here are your options:

### Option 1: Install via Mason (Recommended)

1. Start nvim with dotnet profile:
   ```bash
   NVIM_PROFILE=dotnet nvim
   ```

2. Open Mason:
   ```vim
   :Mason
   ```

3. Search for and install `netcoredbg`:
   - Press `/` and search for "netcoredbg"
   - Press `i` to install it

### Option 2: Install manually

If Mason doesn't have netcoredbg available, install it manually:

```bash
# Create directory
mkdir -p ~/.local/share/nvim/mason/packages/netcoredbg

# Download and extract netcoredbg (adjust URL for your architecture)
cd ~/.local/share/nvim/mason/packages/netcoredbg
wget https://github.com/Samsung/netcoredbg/releases/download/3.1.0-1031/netcoredbg-linux-amd64.tar.gz
tar -xzf netcoredbg-linux-amd64.tar.gz
rm netcoredbg-linux-amd64.tar.gz
```

## Verify Installation

After installation, verify the debugger is available:

```bash
ls ~/.local/share/nvim/mason/packages/netcoredbg/
```

You should see the `netcoredbg` executable.

## Usage

Once installed, you can:

1. **Set breakpoints**: `<F9>` or `<leader>db`
2. **Start debugging**: `<F5>`
3. **Step through code**: `<F1>` (step into), `<F2>` (step over), `<F3>` (step out)
4. **Toggle DAP UI**: `<F7>`

### Azure Functions Debugging

With netcoredbg installed, the azfunc.nvim plugin will work:

1. Press `<leader>as` to start Azure Functions debugging
2. The plugin will automatically attach the debugger to your Azure Functions process
3. Set breakpoints in your function code
4. Trigger your functions (HTTP requests, timers, etc.)
5. Debug as normal

## Dependencies

Make sure you have:
- .NET SDK installed
- Azure Functions Core Tools (`func` CLI)
- Your project built in Debug configuration

## Troubleshooting

If debugging doesn't work:

1. **Check netcoredbg installation**:
   ```bash
   ~/.local/share/nvim/mason/packages/netcoredbg/netcoredbg --version
   ```

2. **Ensure your project is built**:
   ```bash
   dotnet build -c Debug
   ```

3. **Check DAP logs**:
   ```vim
   :DapShowLog
   ```