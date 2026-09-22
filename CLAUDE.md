# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository covering Neovim, zsh, and terminal configuration across macOS and Linux. The Neovim configuration is built on NvChad v2.5 and features a custom multi-profile system that loads different plugin sets and configurations based on the development environment (default, .NET, Java, or Python).

## Cross-Platform Structure

The repo supports macOS (Apple Silicon) and Arch-based Linux from one tree. Shared configuration lives at the top level; anything that genuinely differs per platform lives under `os/<os>/`.

```
lib/os.sh              OS detection, shared by install.sh (bash) and zsh
install.sh             Shared install steps; dispatches to the OS installer
zsh/                   Shared shell configuration
kitty/ fastfetch/      Shared config sources (linked per-OS, see below)
tmux/                  Shared tmux config; OS fragment in os/<os>/tmux.conf
nvim/                  Shared; already cross-platform via profile-manager.lua
os/macos/              Brewfile, install.sh, zsh/{exports,aliases}.zsh
os/linux/              pacman.txt, aur.txt, install.sh, zsh/{exports,aliases}.zsh
os/linux/hypr/         User-tier Hyprland config (see below)
os/linux/hyde-themes/  Hand-authored HyDE themes, one dir each (see below)
```

### Detection

`lib/os.sh` is the single source of truth and must stay **POSIX sh** — it is sourced by both bash (`install.sh`) and zsh (`zsh/bootstrap.zsh`). It exports:

- `DOTFILES_OS` — `macos` or `linux`
- `DOTFILES_DISTRO` — normalized to a *family* (`arch`, `debian`, `fedora`), so derivatives resolve to the package manager they actually use. CachyOS reports `arch`.

`dotfiles_detect_distro()` reads `/etc/os-release` in a subshell on purpose; sourcing it directly would leak `ID`/`NAME`/`VERSION` into every interactive shell.

### Shell load order

`zsh/init.zsh` sources `os/$DOTFILES_OS/zsh/{exports,aliases,functions}.zsh` **before** the shared files.

OS files own what differs — package-manager paths, `NVM_SH`, `JAVA_HOME`, the `ls` color flag — and shared files read those. **A shared file must never redefine something an OS file owns.** That one rule keeps load order significant in a single direction; violating it makes the ordering load-bearing in both, which is how these setups become unpredictable.

### Adding a package

Add it to **both** `os/macos/Brewfile` and `os/linux/pacman.txt` — they are parallel manifests and drift silently otherwise. AUR-only packages go in `os/linux/aur.txt` (installed via `paru`, falling back to `yay`).

### NVM

Deliberately split: Node versions live in `$NVM_DIR` (`~/.nvm`) on both platforms, but `nvm.sh` itself is at `/opt/homebrew/opt/nvm/nvm.sh` on macOS and `/usr/share/nvm/nvm.sh` on Arch. The OS files set `NVM_SH`/`NVM_COMPLETION`; shared code just sources whatever they point at. `nvm` is a shell function, not a binary, so `command -v nvm` cannot be used to check for it.

### Which configs get linked is per-OS

`install.sh` links what is universally shared (`~/.dotfiles`, `~/.zshrc`, `~/.config/nvim` — `nvim/` is already cross-platform via `profile-manager.lua`). Each OS installer may define an `os_link_configs()` hook, called after the `~/.dotfiles` symlink exists, for everything else.

**On Linux this matters:** HyDE (the Hyprland desktop) generates and owns `~/.config/kitty` and `~/.config/fastfetch`, rewriting them on every theme switch — `kitty.conf` does `include hyde.conf`, and the Fastfetch logo comes from a theme-aware `fastfetch.sh logo` call. `os/linux/install.sh` detects HyDE (via `hyde-shell`/`hydectl`/`~/.config/kitty/hyde.conf`) and skips linking both, preserving the existing desktop setup. Without HyDE it links them normally. macOS always links them, since nothing else claims those directories there.

The Fastfetch startup banner still runs on Linux; it just renders with HyDE's config. `run_fastfetch` in `zsh/functions.zsh` points at `~/.config/fastfetch/config.jsonc`, whichever config that happens to be.

### tmux

`tmux/tmux.conf` is shared and linked to `~/.config/tmux/tmux.conf` by the shared installer. The only genuinely platform-specific part is clipboard integration, which lives in `os/<os>/tmux.conf`, is linked to `~/.config/tmux/os.conf`, and is pulled in by `source-file -q` at the end of the shared config. The `-q` keeps `tmux.conf` usable standalone.

This inverts the usual pattern: rather than the OS file loading first, tmux sources it **last**, because a `bind` simply replaces any earlier binding. So `y` in copy mode is bound to `wl-copy` on Linux and `pbcopy` on macOS, overriding nothing else.

The prefix is deliberately left at the default `C-b` — the config is written for someone learning tmux, where matching every tutorial and working unchanged over SSH matters more than ergonomics.

Two settings are load-bearing for Neovim and should not be removed: `escape-time 10` (the 500ms default makes `Esc` feel broken in nvim) and `focus-events on` (nvim's autoread). Colors are left to the terminal palette rather than hardcoded, so the status bar follows whatever HyDE theme is active.

In-tmux help replaces two defaults: `prefix + ?` opens `tmux/cheatsheet.txt` in a `display-popup`, and `prefix + /` pipes `list-keys -N` into fzf. `list-keys -N` shows **only bindings with a note**, so every custom `bind` carries `-N "…"` — a binding added without one is silently missing from the search. The cheatsheet is hand-written and read from `~/.dotfiles` at runtime, so it needs no linking, but it must be updated by hand when a binding changes.

Validate config changes without touching a live session by using a separate socket:

```sh
tmux -L cfgtest -f ~/.config/tmux/tmux.conf new-session -d && \
  tmux -L cfgtest list-keys -T prefix; tmux -L cfgtest kill-server
```

#### Plugins

Managed by tpm, cloned by `install.sh` into `~/.config/tmux/plugins/` — a real directory outside the repo, so nothing needs gitignoring. `tmux-resurrect` saves/restores sessions, `tmux-continuum` drives it on a 15-minute timer and restores on server start.

`TMUX_PLUGIN_MANAGER_PATH` is deliberately **not** set. tpm derives `<xdg>/tmux/plugins` itself when it finds `tmux.conf` under XDG, and setting it in the config would actively break things — tmux does not expand `~` in `set-environment`, so the literal tilde path fails to resolve.

The `run '…/tpm'` line must stay last; tpm only sees plugins declared above it.

Installing plugins needs a server with the config loaded. From outside a session:

```sh
tmux -L boot -f ~/.config/tmux/tmux.conf new-session -d
tmux -L boot run-shell '~/.config/tmux/plugins/tpm/bin/install_plugins'
tmux -L boot kill-server
```

#### Session management

`tmux/scripts/tmux-sessionizer` fuzzy-finds a project under the `SEARCH_PATHS` array (currently `~/Repos` and `~/dotfiles`) and attaches to a session named after it, creating it if needed. Bound to `prefix + f` and linked into `~/.local/bin`, so it works from a plain shell too. It handles being run both inside tmux (`switch-client`) and outside (`attach-session`), and strips dots from session names since tmux treats them as host/port separators.

#### Wallbash theming (Linux)

`os/linux/wallbash/tmux.dcol` is a wallbash template that regenerates `~/.config/tmux/wallbash.conf` from the current wallpaper on every theme, wallpaper or mode change, then re-sources it into any running server via its header-line command. `tmux.conf` sources it with `-q`, so macOS and non-HyDE machines fall back to the plain terminal-palette styling.

It is **copied**, not symlinked, into `~/.config/hyde/wallbash/always/` by `install_wallbash_templates()`. Wallbash finds templates with `find -H … -type f`, which does not follow symlinks — the same constraint as theme wallpapers. Re-run the installer after editing the template.

The template sets styles only; `tmux.conf` owns formats and layout. Keeping that split is what lets colors be regenerated without touching the bar's structure.

### Claude Code harness

`claude/` is a self-contained Claude Code configuration installed into
`~/.claude` by the shared installer. It is shared across platforms — nothing in
it is OS-specific, so there is no `os/` counterpart.

**This repo is public, and that constraint shapes the whole design.**
`~/.claude` is a live state directory holding session transcripts,
`.credentials.json`, plugin state, and the per-project memory Claude writes
under `projects/`. It is therefore **never linked as a whole**. Only four known-
safe paths are symlinked in (`CLAUDE.md`, `agents/`, `skills/`, `hooks/`), so
anything Claude Code creates later stays outside the repo by construction rather
than by remembering to gitignore it.

The invariant, stated in `claude/CLAUDE.md` so Claude enforces it too: **this
harness describes how the user works, never what they are working on.** No
project or product names, hostnames, domains, organisation names, infrastructure
details, or filesystem paths belong in any file under `claude/`. Project
knowledge goes in that project's own `CLAUDE.md` / `.claude/`, which this repo
does not track.

**`settings.json` is merged, not symlinked** — the one asymmetry, and the reason
`merge_json_config()` exists in `install.sh`. Every other file in the harness is
written only by the user, so a symlink is right. `settings.json` is also written
by *Claude Code itself*: plugin toggles, `/config`, and the auto-mode classifier
all rewrite it, and the `autoMode.environment` block it maintains records
organisation name, cloud providers, internal domains, and protected production
namespaces. Through a symlink that would land in a public repo automatically,
unprompted.

So the installer runs `jq -s '.[0] * .[1]' <local> <repo>`: repo values win,
local-only keys (`enabledPlugins`, `extraKnownMarketplaces`, `autoMode`) survive,
and the result is idempotent. The consequence to remember: **editing
`claude/settings.json` requires re-running `./install.sh`.** Everything else in
`claude/` is live on save.

The function also replaces the target if it finds a symlink there, since a
symlink would make the merge write into the repo — the exact failure it exists
to prevent.

Two details that are load-bearing:

- `claude/agents/researcher.md` declares `tools: Read, Grep, Glob` with no
  `Bash`. Read-only is enforced by the tool list, not by prompt instruction.
  Adding `Bash` to it silently removes that guarantee.
- Both hooks require `jq` (already in both package manifests) and must exit 0
  on every path. `protect-git.sh` fails open when `jq` is absent, because the
  `ask` rules in `settings.json` are the second layer; `verify-task.sh` honours
  `stop_hook_active`, without which a `Stop` hook loops.

`protect-git.sh` splits commands on shell separators and strips `sudo`,
`env FOO=bar`, and git's global options (`-C`, `-c`, `--git-dir`) before
matching — that is what makes a chained destructive command catchable, which a
prefix-matching permission rule cannot do. **The split must stay quote-aware:** a
separator inside quotes does not start a new command, and without that rule any
command merely quoting a destructive git string (a grep pattern, a JSON payload,
this very documentation) invents a segment beginning with `git` and is refused.

Every `git worktree` subcommand is deliberately left alone, so `claude -w <name>`
workflows are never blocked.

See `claude/README.md` for the agent/skill/hook reference and how to add more.

### Hyprland user configuration (Linux)

`os/linux/hypr/` holds the user-tier Hyprland files, linked into `~/.config/hypr/` by `install_hypr_configs()` — the list is the `HYPR_USER_CONFIGS` array: `userprefs.conf`, `keybindings.conf`, `windowrules.conf`.

These are safe to own because HyDE seeds but never rewrites them; its generated output goes to `~/.config/hypr/themes/` instead. Linking is HyDE-independent — it happens whether or not HyDE is installed.

**Deliberately excluded, and they must stay that way:** `monitors.conf` and `workspaces.conf` are both generated by nwg-displays and both name physical outputs (`monitor:DP-1`, `monitor:DP-2`), and `nvidia.conf` is hardware-specific. They describe *this* machine and would be wrong on any other. The nwg-displays pair is also regenerated whenever displays are rearranged, so tracking them means fighting that tool. Any file carrying a "Generated by … Do not edit manually" header belongs in this list, not in `HYPR_USER_CONFIGS`.

Remember the precedence rule when editing `userprefs.conf`: `hyprland.conf` sources it *last*, so it outranks the active theme. Keep structure and behaviour there and leave colors/gaps/rounding/blur to the theme, or theme switching will look half-applied.

**Hazard — HyDE updates can write through these symlinks.** HyDE's `restore.config.sh` deploys with `cp -r`/`cp -rf`, and a plain copy onto a symlink writes through to the target rather than replacing the link. A HyDE update can therefore overwrite the tracked files *inside this repo* while the symlinks still look correct. Installing HyDE before the dotfiles avoids it; otherwise check `git status os/linux/hypr` after any HyDE update and `git checkout --` to restore. This is the main reason these files are worth tracking in git at all.

### HyDE themes (Linux)

`os/linux/hyde-themes/` holds hand-authored HyDE themes, one directory each. `install_hyde_themes()` in `os/linux/install.sh` loops over them and installs each to `~/.config/hyde/themes/<name>`.

**The directory name is the theme name** — that's how HyDE identifies a theme, so no name is hardcoded anywhere. Adding a theme means adding a directory; renaming is a `git mv` plus deleting the stale `~/.config/hyde/themes/<old-name>` by hand, since the installer only adds.

Which files get symlinked is controlled by the `HYDE_THEME_LINKABLE` array; extend it if a theme needs a file type not yet listed. An optional `.sort` file (first line, a number, default `0`) orders the theme in the switcher — shipped themes use `1`–`12` and the sort is ascending, so custom themes appear first by default; a negative value pins one to the top.

Unlike Kitty/Fastfetch, this is **additive** — a directory HyDE doesn't own and never overwrites — so it installs whenever HyDE is present, regardless of the desktop-config skip. Without HyDE it isn't installed at all, since nothing would consume it.

**The symlink/copy split is forced by HyDE, not a style choice.** Discovery uses `find -H`, which does not follow symlinks encountered during traversal, so a symlink is `-type l` — never `-type d` or `-type f`:

| Path | Must be | Mechanism |
|------|---------|-----------|
| `themes/<name>/` | real directory | `get_themes()` uses `find -H … -maxdepth 1 -type d` |
| `wallpapers/` + images | real directory, **copied** files | `get_hashmap()` uses `find -H … -type f` |
| `*.theme`, `kvantum/` | may be symlinks | read by path (`-r`), which follows symlinks |

Get this wrong and there is no error — the theme simply never appears in the switcher. A theme with **no wallpaper at all is skipped entirely** by `get_themes()`, which is why one image is committed.

Consequences worth knowing:

- Editing a `.theme` file in the repo edits the live theme. Adding a wallpaper requires re-running the installer to copy it.
- HyDE writes `wall.set` and `wall.{swww,hyprlock,awww}.png` into the installed directory as wallpapers change. Because that directory is real rather than a symlink to the repo, this state never reaches the repo and **no `.gitignore` entries are needed**.
- `get_themes()` self-heals a missing or dangling `wall.set` by relinking it to the first wallpaper it finds.

### Adding a new OS or distro

1. Create `os/<name>/` with `install.sh` and `zsh/`
2. Have the installer install packages, set `NVM_SH`, and optionally define `os_link_configs()`
3. Extend `dotfiles_detect_os()` / `dotfiles_detect_distro()` in `lib/os.sh`

The OS installer is **sourced, not executed**, so it inherits `DOTFILES_DIR`, `DRY_RUN`, `info()`, `run()`, and `link_config()` — and hands `NVM_SH` back.

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
- **Python**: Detects `test_*.py`, `*_test.py` files, runs `python -m pytest` with the project's `.venv`/`venv` interpreter when one exists. Test-name lookup has its own Python pass, because the shared Playwright pattern also matches `s.split(",")`.

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

To add a new profile (e.g., Go):

1. Create `nvim/lua/profiles/go/plugins.lua` returning a lazy.nvim spec table
2. Add `"go"` to `M.profiles` array in `profile-manager.lua`
3. Follow the pattern from existing profiles for LSP setup (remember to call NvChad's `on_attach`)

A profile can branch shared config on `vim.g.current_nvim_profile`. `init.lua` sets it in `load_profile()`, before `configs.lazy` or `options` are required. The Python profile does this; see below.

### Common Profile Issues

- **LSP keymaps not working**: Check that `on_attach` calls `require("nvchad.configs.lspconfig").on_attach(client, bufnr)`
- **Plugins not loading**: Verify the profile returns a proper table structure, check `:Lazy` for errors
- **jdtls not starting**: Check launcher jar exists, config directory matches OS/arch, and jdtls is NOT in lspconfig servers list

## Python Profile and Jupyter

Interactive notebooks come from four plugins: **molten-nvim** runs code in a real Jupyter kernel and draws output inline (plots through the shared image.nvim spec); **jupytext.nvim** opens `.ipynb` as markdown and writes it back on save; **quarto-nvim** + **otter.nvim** give LSP/completion and cell-aware running inside the markdown code blocks. Keymaps are under `<leader>j` (`<leader>m` would prefix NvChad's `<leader>ma`).

### molten is a remote plugin, and this config disables remote plugins

Two separate switches have to be undone, and both are undone **only for the python profile**:

- **`nvchad.options` sets `g.loaded_python3_provider = 0`.** The provider's guard is `exists()`, so any value blocks it; `options.lua` *deletes* the variable after requiring `nvchad.options`. Setting it earlier would just be overwritten.
- **`configs/lazy.lua` lists `"rplugin"` in `disabled_plugins`.** lazy.nvim matches those names against runtime *filenames*, so `rplugin.vim` (which sources the `:UpdateRemotePlugins` manifest) is never loaded and no `:Molten*` command exists. The entry is filtered out of the list before `lazy.setup`.

molten is `lazy = false` on purpose: `:UpdateRemotePlugins` rewrites the whole manifest from the current runtimepath, so running it while molten isn't loaded silently deletes every `:Molten*` command. After molten is installed or updated, restart nvim once for the commands to appear.

### The Python host venv

`install.sh` builds `~/.local/opt/nvim-python` (next to the netcoredbg override) with pynvim, jupyter_client, ipykernel, jupytext, nbformat, pillow and pyperclip, and the profile sets `python3_host_prog` to it at module load. It is a venv because Arch's Python is PEP 668 externally-managed. It is *dedicated* because pointing the host at a project venv breaks molten in every project without pynvim.

- ipykernel's wheel ships a `python3` kernelspec into the venv, and jupyter_client finds it through `sys.prefix`, so `:MoltenInit` has a kernel on a fresh machine. Project kernels are registered with `ipykernel install --user` from the project's own venv.
- **molten writes connection files to `<jupyter data dir>/runtime` without creating it.** On a machine where Jupyter has never run, every `:MoltenInit` fails with ENOENT. The installer creates it, asking `jupyter_core` for the data dir (it is `~/Library/Jupyter` on macOS).
- **jupytext.nvim requires `jupytext` on PATH** and has no setting for it. Only that binary is linked into `~/.local/bin`. Putting the venv's `bin/` on PATH would shadow projects' `python`.
- The venv is rebuilt with `--clear` when `bin/python` is not executable, which is what a Homebrew Python minor-version bump leaves behind.

image.nvim's `magick_cli` processor needs ImageMagick's `magick`, which both manifests install.

### LSP

`pyright` and `ruff` are in the shared `servers` list. ruff's `hoverProvider` is switched off in its `on_attach`, otherwise `K` stacks ruff's lint-rule hover on top of pyright's. otter's LSP client (inside notebook cells) gets `gd`/`K` from NvChad's `LspAttach` autocmd like any other server. quarto-nvim no longer has a `keymap` option, despite molten's notebook guide passing one.

### Validating headless

NvChad loads lspconfig on `User FilePost`, which only fires after `UIEnter`, so under `--headless` no LSP ever attaches unless the event is fired by hand. Also, **any nvim run rewrites `nvim/lazy-lock.json` from the plugins the current profile loaded**, even with `XDG_DATA_HOME` pointed elsewhere, because the lockfile lives in the config dir. Check `git diff nvim/lazy-lock.json` after testing.

## Git Ignore Patterns

Important git-ignored files:
- `nvim/lazy-lock.json` - Plugin version lockfile (tracked, but may have local changes)
- `nvim/lua/local-commands.lua` - Project-specific commands (should be git-ignored for work-specific code)

## Mason Package Dependencies

Language servers and debuggers are installed via Mason:

- **Java**: `jdtls`, `java-debug-adapter`
- **.NET**: `omnisharp`, `netcoredbg`
- **TypeScript**: `typescript-language-server`, `js-debug-adapter`
- **Python**: `pyright`, `ruff`, `debugpy` (all three via the profile's `ensure_installed`)

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
