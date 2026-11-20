-- SPDX-License-Identifier: GPL-3.0-or-later
-- Archway Hyprland session. Managed by chezmoi — local edits are reported by
-- `archway update` instead of being overwritten silently.
--
-- Hyprland 0.57 replaced hyprlang with a Lua configuration API (hl.*), so this
-- file is Lua, not key=value. Two generated pieces are loaded when present:
--   ~/.config/archway/theme.d/hyprland.lua   colours, gaps, rounding, blur
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

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:ralt",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
    },
  },
  general = {
    layout = "dwindle",
    allow_tearing = false,
    resize_on_border = true,
  },
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    focus_on_activate = true,
    mouse_move_enables_dpms = true,
  },
  -- XWayland stays enabled for legacy X11 clients (documented, not hidden).
  xwayland = {
    force_zero_scaling = false,
  },
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
hl.window_rule({ name = "pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "nm-connection-editor", match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "blueman-manager", match = { class = "^(blueman-manager)$" }, float = true })

-- Session components. Started from the compositor so they exit with it; when
-- the session came from uwsm they inherit its systemd scope.
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("swaync")
  hl.exec_cmd("hypridle")
end)
