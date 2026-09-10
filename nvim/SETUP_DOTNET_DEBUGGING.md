# .NET Debugging Setup

## The debugger

Debugging goes through `netcoredbg`, wired up as the `coreclr` DAP adapter in
`nvim/lua/configs/dap.lua`. Both `azfunc.nvim` and the manual
`attach - netcoredbg` configuration route through that one adapter.

**Nothing needs installing by hand.** Where it comes from depends on the
platform, and `dap.lua` resolves between the two at startup:

| Platform | Source | Installed by |
|----------|--------|--------------|
| Linux x86_64 | Mason | the .NET profile's `ensure_installed` |
| macOS arm64 | `~/.local/opt/netcoredbg` | `os/macos/install.sh` |

On Linux, opening nvim in the .NET profile installs the Mason package if it is
missing — see `ensure_installed` in `nvim/lua/profiles/dotnet/plugins.lua`. On
macOS, `./install.sh` fetches the debugger. `~/.local/opt` wins whenever it
exists; otherwise the adapter falls back to `mason/bin/netcoredbg`.

### Why macOS bypasses Mason

mason-registry pins netcoredbg to `3.1.3-1062` and maps **both** darwin targets
to `netcoredbg-osx-amd64.tar.gz`, because 3.1.3 shipped no osx-arm64 asset. On
an Apple Silicon Mac that installs an x86_64 binary which runs under Rosetta and
cannot load the arm64 DAC out of an arm64 debuggee. Every attach fails at
`configurationDone` with `0x80131c3c` (`CORDBG_E_DEBUG_COMPONENT_MISSING`).

`:MasonUpdate` does not help — the pin is the problem — and installing into the
Mason package directory by hand gets clobbered by the next update. Hence
`~/.local/opt`, which Mason does not manage. The version installed there is
`3.2.0-1092`, the first release with `netcoredbg-osx-arm64.zip`.

The download also needs `xattr -dr com.apple.quarantine` and an ad-hoc
`codesign`; the installer does both.

**This is temporary.** Once mason-registry bumps the pin and splits the darwin
targets, delete `~/.local/opt/netcoredbg` and everything falls back to Mason
with no config change.

## Verifying

`netcoredbg --version` proves **nothing** — the broken x86_64 build starts and
reports its version perfectly happily. The architecture mismatch only surfaces
on a real attach. Check the architecture instead:

```bash
# must match `uname -m`
file "$(nvim --headless -c 'lua io.write(require("dap").adapters.coreclr.command)' -c qa 2>/dev/null)"
```

To confirm the adapter is resolving where you expect:

```vim
:lua print(require("dap").adapters.coreclr.command)
```

## Usage

1. **Set breakpoints**: `<F9>` or `<leader>db`
2. **Start debugging**: `<F5>`
3. **Step through code**: `<F1>` (step into), `<F2>` (step over), `<F3>` (step out)
4. **Toggle DAP UI**: `<F7>`

### Azure Functions

1. Press `<leader>as` from anywhere in the repository — no need to have a C#
   file open, and it searches from the git root rather than the cwd, so any
   subdirectory or worktree works.
2. It finds the Azure Functions project (any `.csproj` with
   `<AzureFunctionsVersion>`), prompting only if the repo has more than one.
3. `func host start --dotnet-isolated-debug` runs in a split, and the debugger
   attaches to the worker once it comes up.
4. Set breakpoints, trigger your functions, debug as normal.
5. `<leader>aS` stops the session.

## Dependencies

- .NET SDK
- Azure Functions Core Tools (`func` CLI)
- Your project built in Debug configuration

## Troubleshooting

**`Failed command 'configurationDone' : 0x80131c3c`** — architecture mismatch
between debugger and debuggee. Compare `file` on the adapter command against
`dotnet --info | grep RID`. On macOS this means the `~/.local/opt` override is
missing; re-run `./install.sh`.

**`Executable ... not found ... adapter definition for 'coreclr'`** — the
debugger is not installed at all. On Linux, open nvim in the .NET profile and
let `ensure_installed` fetch it, or run `:MasonInstall netcoredbg`.

**Worker timeouts in the `func` terminal** — `Starting worker process failed`,
`The operation has timed out`, `A debugger was not attached within the expected
time limit`. These are consequences of a failed attach, not causes:
`--dotnet-isolated-debug` blocks the worker until a debugger attaches, and the
host's 60s gRPC timeout then fires. Fix the attach and they disappear.

**Anything else**:

```bash
dotnet build -c Debug   # ensure the project is built
```

```vim
:DapShowLog
```
