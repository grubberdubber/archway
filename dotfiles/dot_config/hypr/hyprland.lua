-- SPDX-License-Identifier: GPL-3.0-or-later
-- Archway Hyprland session. Managed by chezmoi — local edits are reported by
-- `archway update` instead of being overwritten silently.
--
-- Hyprland 0.57 replaced hyprlang with a Lua configuration API (hl.*), so this
-- file is Lua, not key=value. Two generated pieces are loaded when present:
--   ~/.config/archway/theme.d/hyprland.lua   colours, gaps, rounding, opacity
--   ~/.config/hypr/conf.d/20-keybinds.lua    binds from keybinds/keybinds.toml
-- Session entry: start Hyprland through uwsm (ADR-013) so the compositor and
-- its components get a clean systemd lifecycle. Nothing here changes the
-- display manager or the user's default session.

local home = os.getenv("HOME") or error("HOME is not set")
local config_dir = home .. "/.config/hypr"

-- Missing generated files are not fatal: a fresh checkout must still parse.
local function source(path)
  local handle = io.open(path, "r")
  if not handle then
    return false
  end
  handle:close()
  dofile(path)
  return true
end

source(home .. "/.config/archway/theme.d/hyprland.lua")
source(config_dir .. "/conf.d/20-keybinds.lua")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:ralt",
    follow_mouse = 1,
    sensitivity = 0,
    -- Touchpad and mouse are configured separately on purpose: natural scroll
    -- is correct on a trackpad and wrong on a wheel. `input.touchpad` only
    -- affects trackpads, so the mouse keeps the traditional direction.
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      scroll_factor = 1.0,
    },
  },
  general = {
    layout = "dwindle",
    allow_tearing = false,
    resize_on_border = true,
    snap = { enabled = true },
  },
  dwindle = {
    preserve_split = true,
    smart_split = true,
  },
  master = {
    new_status = "master",
  },
  -- Animations off by default: this desktop targets laptops and old GPUs, and
  -- the budget in AGENTS.md §2.7 is about latency, not eye candy. Set
  -- `animations = { enabled = true }` here if you prefer the movement.
  animations = {
    enabled = false,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    focus_on_activate = true,
    mouse_move_enables_dpms = true,
  },
  debug = {
    -- Variable refresh rate: less work per frame on a battery-powered laptop.
    vfr = true,
  },
  -- XWayland stays enabled for legacy X11 clients (documented, not hidden).
  xwayland = {
    force_zero_scaling = false,
  },
})

-- Mice keep the classic scroll direction even when they identify oddly.
hl.device({ name = ".*[Mm]ouse.*", natural_scroll = false })

-- Three-finger horizontal swipe switches workspaces (no compositor animation).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Some toolkits (kitty included) ask to be maximized on map; tiling is the
-- whole point of this desktop, so the request is dropped instead of honoured.
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Floating scratchpad and dialogs. `floating-term` is what Super+Shift+Return,
-- yazi and the cheatsheet launch, so a single rule keeps them consistent.
hl.window_rule({
  name = "floating-term",
  match = { class = "^(floating-term)$" },
  float = true,
  center = true,
  size = "70% 60%",
})
-- Terminals are square. A rounded corner arcs the compositor border over the
-- first cells of the grid; with a full-bleed background that reads as a phantom
-- frame inside the window, most obvious around Neovim.
hl.window_rule({
  name = "terminal-square",
  match = { class = "^(kitty|floating-term|Alacritty|Foot|foot)$" },
  rounding = 0,
})

-- Firefox paints its own square surface edge to edge, so the compositor
-- rounding only shaved the corners into arcs that do not match the content.
hl.window_rule({
  name = "firefox-square",
  match = { class = "^(firefox|firefox-esr|librewolf|LibreWolf)$" },
  rounding = 0,
})

hl.window_rule({ name = "pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "nm-connection-editor", match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "blueman-manager", match = { class = "^(blueman-manager)$" }, float = true })

-- Session components. Started from the compositor so they exit with it; when
-- the session came from uwsm they inherit its systemd scope. Optional tools are
-- probed first: a missing package must not produce a failed unit on every boot.
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("swaync")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("command -v swayosd-server >/dev/null 2>&1 && swayosd-server")
  hl.exec_cmd("command -v hyprpaper >/dev/null 2>&1 && hyprpaper")
  -- cliphist only records what a watcher feeds it; without this the Super+V
  -- history is permanently empty.
  hl.exec_cmd("command -v cliphist >/dev/null 2>&1 && wl-paste --type text --watch cliphist store")
  hl.exec_cmd("command -v cliphist >/dev/null 2>&1 && wl-paste --type image --watch cliphist store")
  -- Restore the wallpaper picked with Super+Alt+W (no-op when none was set).
  hl.exec_cmd("command -v archway >/dev/null 2>&1 && archway applet wallpaper --restore")
end)
