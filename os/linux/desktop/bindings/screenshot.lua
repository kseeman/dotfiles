-- Screenshots and the colour picker.
--
-- hyde-shell screenshot took a mode letter and dispatched to grimblast, which
-- HyDE vendors and which therefore disappears with it. hyprshot is packaged,
-- already installed, and covers three of the four modes directly.
--
-- Every capture then opens in satty, as HyDE's did: the shot is on the
-- clipboard straight away, and the file is written only when it is saved from
-- satty, so a throwaway shot leaves nothing behind in the folder.
local mod = "SUPER"

-- Resolved in Lua rather than left to the shell, so the folder is the same one
-- whether or not XDG_PICTURES_DIR happens to be exported into the session.
local pictures = os.getenv("XDG_PICTURES_DIR") or (os.getenv("HOME") .. "/Pictures")
local SHOTS = pictures .. "/Screenshots"

-- Captured to a temporary file rather than piped, so that a cancelled region
-- selection can be told apart and opens nothing. It is checked for a PNG
-- header rather than for being non-empty: cancelling leaves the capture
-- command to fail however it likes, and anything it prints is not an image.
local function annotate(capture)
    return hl.dsp.exec_cmd(
        "mkdir -p '" .. SHOTS .. "' && t=$(mktemp --suffix=.png) && " .. capture .. " > \"$t\""
            .. " && head -c 8 \"$t\" | grep -q PNG && wl-copy < \"$t\""
            .. " && satty -f \"$t\" -o '" .. SHOTS .. "/%Y-%m-%d-%H%M%S.png' --copy-command wl-copy"
            .. "; rm -f \"$t\""
    )
end

local function hyprshot(args)
    return annotate("hyprshot --raw " .. args)
end

hl.bind(mod .. " + P", hyprshot("-m region"), { desc = "screenshot: region" })

-- Freezing first is what makes it possible to capture a menu or a hover state,
-- which vanish the moment a selection overlay takes the pointer.
hl.bind(mod .. " + CONTROL + P", hyprshot("-m region --freeze"), { desc = "screenshot: region, frozen" })

hl.bind(mod .. " + ALT + P", hyprshot("-m output"), { desc = "screenshot: this monitor" })

-- hyprshot has no every-monitor mode, so the whole layout goes through grim,
-- which captures all outputs when given no geometry.
hl.bind("Print", annotate("grim -"), { desc = "screenshot: all monitors" })

-- Picks a colour from anywhere on screen and puts the hex on the clipboard.
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -an"), { desc = "colour picker" })
