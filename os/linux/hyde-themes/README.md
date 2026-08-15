# HyDE themes

Hand-authored HyDE themes. Every directory here is installed as its own theme
into `~/.config/hyde/themes/<name>` by `install_hyde_themes()` in
`os/linux/install.sh`.

**The directory name is the theme name.** That's how HyDE identifies a theme, so
there's no name recorded anywhere in the scripts:

- add a theme → add a directory, re-run the installer
- rename a theme → `git mv`, re-run, then delete the old
  `~/.config/hyde/themes/<old-name>` by hand (the installer only adds)

`Custom/` was scaffolded from the shipped `Red Stone` theme, so out of the box it
looks identical to it. Everything here is yours to edit.

## Ordering in the switcher

An optional `.sort` file (first line, a number) sets a theme's position;
themes without one default to `0`. The shipped themes that bother use `1`–`12`,
and sorting is ascending — so your themes already appear before those. Use a
negative value to pin one to the very top:

```sh
echo -1 > Custom/.sort
```

## Why some files are symlinked and others copied

This is not a style choice — HyDE's discovery uses `find -H`, which does **not**
follow symlinks encountered during traversal. A symlink is therefore `-type l`,
never `-type d` or `-type f`:

| Path | Installed as | Reason |
|------|--------------|--------|
| `~/.config/hyde/themes/<name>/` | real directory | `get_themes()` scans with `find -H … -maxdepth 1 -type d`; a symlinked directory is invisible and the theme never appears in the switcher |
| `wallpapers/` and its images | real directory, **copied** files | `get_hashmap()` scans with `find -H … -type f`; symlinked images are invisible |
| `*.theme`, `kvantum/` | symlinks into this repo | read by path (`-r`), which follows symlinks — so editing here edits the live theme |

The practical consequence: **text configs are live**, but adding or changing a
wallpaper requires re-running the installer to copy it across.

A theme with no wallpaper at all is skipped entirely by `get_themes()`, which is
why every theme here commits at least one.

The linkable set is listed in `HYDE_THEME_LINKABLE` in `os/linux/install.sh`:
`hypr.theme`, `kitty.theme`, `waybar.theme`, `rofi.theme`, `theme.dcol`,
`animations.theme`, `hyprlock.theme`, `swaync.theme`, `.sort`. Add to that array
if a theme needs a file type not yet covered — anything unlisted is ignored.

## Runtime state stays out of the repo

HyDE writes `wall.set` and `wall.{swww,hyprlock,awww}.png` into the theme
directory whenever the wallpaper or theme changes. Because the installed
directory is a *real* directory rather than a symlink to this one, those files
land in `~/.config` and never reach the repo — so no `.gitignore` entries are
needed.

## Files

| File | Written to on theme switch | Contents |
|------|---------------------------|----------|
| `hypr.theme` | `~/.config/hypr/themes/theme.conf` | `$GTK_THEME`/`$ICON_THEME`/`$SDDM_THEME`, `general{}`, `decoration{}`, `group{}` — gaps, borders, rounding, blur |
| `kitty.theme` | `~/.config/kitty/theme.conf` | terminal palette |
| `waybar.theme` | `~/.config/waybar/theme.css` | `@define-color` bar colors |
| `rofi.theme` | `~/.config/rofi/theme.rasi` | menu colors |
| `kvantum/` | Qt/Kvantum styling | |

Line 1 of each `.theme` file is a **header line** (`target` or `target|command`)
telling HyDE where to write it and what to run afterward. Keep it.

## Colors: static vs wallbash

Currently **static** — the `.theme` files carry literal hex, inherited from
`Red Stone`. The theme looks the same regardless of wallpaper.

To make it follow the wallpaper instead, replace the hex with wallbash
placeholders (`<wallbash_pry1>`, `<wallbash_txt1>`, `<wallbash_1xa3>`, …). To
keep it static but define the palette explicitly in one place, add a
`theme.dcol` file — the installer picks it up automatically if present.

## Adding another theme

```sh
cp -r Custom "My Other Theme"      # or copy a shipped theme from ~/.config/hyde/themes
rm -f "My Other Theme"/wall.set    # runtime state, never commit it
./install.sh                        # installs every directory here
hydectl theme set "My Other Theme"
```

Directory names may contain spaces — the shipped themes do.

## Editing

```sh
hydectl theme set "<name>"    # switch to it
hydectl theme next / prev     # cycle, yours included
```

Because the `.theme` files are symlinks, edit them here and re-switch to the
theme to see changes.
