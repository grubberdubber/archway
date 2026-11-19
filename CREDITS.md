# Credits

Archway is GPL-3.0-or-later. It borrows ideas — and in places, carefully
attributed structure — from the projects below. No third-party code is
vendored here unless stated.

## Inspirations

| Project | Author | License | What Archway takes |
|---|---|---|---|
| [gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles) | gh0stzk | GPL-3.0 | Philosophy: hand-written palettes, hot-swappable themes, Rofi applets, bspwm-first desktop, fast native zsh. The `android-mount` applet concept (mounting Android devices over MTP from Rofi) originates there. Archway reimplements it; no code is copied. |
| [NvChad](https://github.com/NvChad/NvChad) | NvChad team | GPL-3.0 | Base for the external Neovim configuration (via `grubberdubber/nvim-config`). |

## External dependencies consumed at install time

| Project | Author | License | Role |
|---|---|---|---|
| [grubberdubber/nvim-config](https://github.com/grubberdubber/nvim-config) | grubberdubber | Unlicense | The single source of truth for Neovim. Consumed as a pinned git checkout at `~/.config/nvim`; never copied into this repository, never relicensed. |

## Assets

- **Palette**: written by hand for Archway. "Android Mount" is an aesthetic
  homage to Material You, not a reproduction of Google or Android branding.
- **Fonts**: none are redistributed. Archway references system packages
  (`ttf-jetbrains-mono-nerd`, `ttf-inter`/`noto-fonts`, `noto-fonts-emoji`).
- **Wallpapers**: none are shipped in v0.1.0. Contributions must be original or
  licensed compatibly and recorded here before inclusion.

## Naming

"Archway" is an independent project. It is not affiliated with Arch Linux,
Google, or Android.
