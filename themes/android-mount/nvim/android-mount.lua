-- SPDX-License-Identifier: GPL-3.0-or-later
-- Android Mount — reference theme for base46 (NvChad).
--
-- This file is the *artifact* Archway ships and validates against
-- themes/android-mount/palette.toml. It is consumed by the upstream
-- grubberdubber/nvim-config via its local, git-ignored hook; it is not a copy
-- of the live Neovim configuration.
--
-- Derived from the palette in palette.toml. Changing a colour here requires the
-- same change there: `archway theme validate` compares both.

local M = {}

M.base_30 = {
  white = "#E6EDF3",
  darker_black = "#0B0F14",
  black = "#0B0F14",
  black2 = "#11161D",
  one_bg = "#11161D",
  one_bg2 = "#1A212B",
  one_bg3 = "#222B37",
  grey = "#2A3441",
  grey_fg = "#9BA7B4",
  grey_fg2 = "#9BA7B4",
  light_grey = "#9BA7B4",
  red = "#F28B82",
  baby_pink = "#F28B82",
  pink = "#F28B82",
  line = "#222B37",
  green = "#81C995",
  vibrant_green = "#81C995",
  nord_blue = "#8AB4F8",
  blue = "#8AB4F8",
  yellow = "#FDD663",
  sun = "#FDD663",
  purple = "#8AB4F8",
  dark_purple = "#8AB4F8",
  teal = "#81C995",
  orange = "#FDD663",
  cyan = "#81C995",
  statusline_bg = "#11161D",
  lightbg = "#1A212B",
  pmenu_bg = "#1A212B",
  folder_bg = "#8AB4F8",
}

M.base_16 = {
  base00 = "#0B0F14",
  base01 = "#11161D",
  base02 = "#1A212B",
  base03 = "#222B37",
  base04 = "#2A3441",
  base05 = "#9BA7B4",
  base06 = "#E6EDF3",
  base07 = "#E6EDF3",
  base08 = "#F28B82",
  base09 = "#FDD663",
  base0A = "#8AB4F8",
  base0B = "#81C995",
  base0C = "#81C995",
  base0D = "#8AB4F8",
  base0E = "#8AB4F8",
  base0F = "#FDD663",
}

-- Selection background is not a base46 field; it is documented here so the
-- artifact stays a complete 1:1 projection of palette.toml (validated in CI).
M.selection_bg = "#1F2A3A"
M.overlay = "#222B37"
M.selection = "#8AB4F8"

M.type = "dark"

M = require("base46").override_theme(M, "android-mount")

return M
