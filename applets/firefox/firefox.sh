#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# firefox — render the Archway chrome theme and the prefs that make it usable.
#
# Two things are written into the Firefox profile:
#   chrome/userChrome.css   flat, monochrome, square browser chrome
#   chrome/userContent.css  the same for about: pages
#   user.js                 the prefs both files need, plus the file-picker fix
#
# The picker pref is the important one: since Firefox 149 the XDG portal file
# picker is the default, and that dialog (a) is a separate window that Hyprland
# tiled behind the browser, (b) does not take keyboard focus, and (c) drops
# double-click-to-open and Ctrl+click multi-select on several setups. The
# in-process GTK3 picker is the one this desktop themes, focuses and floats, so
# Archway pins it explicitly instead of hoping for the platform default.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
MODE='theme'
PROFILE=''
THEME=''
PREF_WRITE=1

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

usage() {
  cat << 'EOF'
firefox — Archway theme for Firefox (chrome CSS + prefs)

Usage:
  firefox.sh [theme] [--profile DIR] [--theme ID] [--dry-run]
  firefox.sh status [--json]
  firefox.sh --help

  theme      render userChrome.css, userContent.css and user.js into the
             profile (default profile unless --profile is given).
  status     show the profile, whether the theme is installed and the state of
             the file-picker pref.

The profile is discovered from installs.ini/profiles.ini under
~/.config/mozilla/firefox (Firefox 160+ XDG layout) or ~/.mozilla/firefox.
Restart Firefox after applying; chrome CSS is only read at startup.
EOF
}

die() {
  printf 'firefox: %s\n' "$1" >&2
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "Firefox" "$1" > /dev/null 2>&1 || true
}

# ------------------------------------------------------------ profile ------

# Print the default profile path, or nothing. `installs.ini` wins because it is
# what the running binary wrote; `profiles.ini` is the fallback for a profile
# created before the install was registered.
default_profile() {
  local root ini path
  for root in "$CONFIG_HOME/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [[ -d $root ]] || continue
    for ini in "$root/installs.ini" "$root/profiles.ini"; do
      [[ -r $ini ]] || continue
      path=$(sed -n 's/^Default=//p' "$ini" | head -n1)
      [[ -n $path ]] && {
        printf '%s/%s' "$root" "$path"
        return 0
      }
      # profiles.ini: the profile flagged Default=1.
      path=$(awk -F= '
        /^\[Profile/ { p = "" }
        $1 == "Path" { p = $2 }
        $1 == "IsRelative" && $2 == "1" { rel = 1 }
        $1 == "Default" && $2 == "1" && p != "" { print (rel ? root "/" p : p); exit }
      ' root="$root" "$ini") || true
      [[ -n $path ]] && {
        printf '%s' "$path"
        return 0
      }
    done
    # No ini at all: the only .default* directory is the answer.
    path=$(find "$root" -maxdepth 1 -type d -name '*.default*' -print -quit 2> /dev/null)
    [[ -n $path ]] && {
      printf '%s' "$path"
      return 0
    }
  done
  return 1
}

resolve_profile() {
  if [[ -n $PROFILE ]]; then
    [[ -d $PROFILE ]] || die "not a directory: $PROFILE" 3
    printf '%s' "$PROFILE"
    return 0
  fi
  local p
  p=$(default_profile) || die "no Firefox profile found; run Firefox once, or pass --profile DIR" 3
  printf '%s' "$p"
}

# ------------------------------------------------------------- palette -----

# The state file is written by lib/state.sh as a flat `theme=<id>` line, so the
# parser accepts both that and a quoted `theme = "<id>"` (hand-written) form.
current_theme() {
  local file="$CONFIG_HOME/archway/theme.toml" id=''
  if [[ -r $file ]]; then
    id=$(sed -n 's/^[[:space:]]*theme[[:space:]]*=[[:space:]]*"\{0,1\}\([a-z0-9-]*\)"\{0,1\}[[:space:]]*$/\1/p' "$file" | head -n1)
  fi
  [[ -n $id ]] || id=android-mount
  if [[ ! -f $ROOT/themes/$id/palette.toml ]]; then
    printf 'firefox: theme %s has no palette, falling back to android-mount\n' "$id" >&2
    id=android-mount
  fi
  printf '%s' "$id"
}

# Flat `key = "#rrggbb"` pairs from the [palette] section.
palette_value() {
  local id=$1 key=$2 file="$ROOT/themes/$1/palette.toml"
  [[ -r $file ]] || die "unknown theme: $id" 3
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\(#[0-9A-Fa-f]\\{6\\}\\)\".*/\\1/p" "$file" | head -n1
}

render_palette() {
  local id=$1 src=$2 out=$3 key value tmp
  [[ -r $ROOT/themes/$id/palette.toml ]] || die "unknown theme: $id" 3
  tmp=$(mktemp)
  cp -- "$src" "$tmp"
  # Every `name = "#rrggbb"` pair in the palette is a token; a template only
  # uses the ones it needs, and an unused colour costs nothing.
  while read -r key value; do
    sed -i "s|@$key@|$value|g" "$tmp"
  done < <(sed -n 's/^[[:space:]]*\([a-z_]*\)[[:space:]]*=[[:space:]]*"\(#[0-9A-Fa-f]\{6\}\)".*/\1 \2/p' "$ROOT/themes/$id/palette.toml")
  if grep -q '@[a-z_]*@' "$tmp"; then
    die "unresolved palette token in $(basename -- "$src")" 3
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] render %s from %s\n' "$out" "$(basename -- "$src")"
    rm -f -- "$tmp"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$out")"
  mv -- "$tmp" "$out"
}

# --------------------------------------------------------------- prefs -----

prefs_file() {
  local out=$1
  cat << 'EOF' > "$out"
// Archway — prefs applied on every start by Firefox (user.js wins over prefs.js).
// Edit the applet (applets/firefox/firefox.sh) and re-run `archway applet firefox`.

// Load chrome/userChrome.css at all.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Use Firefox's own GTK3 file picker instead of the XDG portal one. See the
// header of the applet: the portal dialog loses focus, shortcuts and
// multi-selection on this desktop.
user_pref("widget.use-xdg-desktop-portal.file-picker", 0);
user_pref("widget.use-xdg-desktop-portal.mime-handler", 0);

// Square, dense chrome.
user_pref("browser.uidensity", 1);
user_pref("browser.compactmode.show", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.tabs.tabMinWidth", 120);
// Closing the last tab must close the window. With `false`, clicking the tab's
// X leaves an empty window behind and Firefox looks like it refuses to quit.
user_pref("browser.tabs.closeWindowWithLastTab", true);
user_pref("browser.tabs.insertAfterCurrent", true);
user_pref("toolkit.tabbox.switchByScrolling", true);
user_pref("browser.toolbars.bookmarks.visibility", "never");

// One dark surface, whatever the site asks for.
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.prefers-color-scheme.content-override", 0);

// Quiet, useful defaults.
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.hoverPreview.enabled", false);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("general.autoScroll", true);
EOF
}

# ---------------------------------------------------------------- apply ----

apply_theme() {
  local profile chrome id backup
  profile=$(resolve_profile)
  chrome="$profile/chrome"
  id=${THEME:-$(current_theme)}

  printf 'firefox: profile %s\n' "$profile"
  printf 'firefox: theme   %s\n' "$id"

  if ((DRY_RUN)); then
    render_palette "$id" "$SCRIPT_DIR/userChrome.css" "$chrome/userChrome.css"
    render_palette "$id" "$SCRIPT_DIR/userContent.css" "$chrome/userContent.css"
    ((PREF_WRITE)) && printf '[dry-run] write %s/user.js\n' "$profile"
    return 0
  fi

  backup="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)/firefox"
  mkdir -p -- "$backup"
  local f
  for f in chrome/userChrome.css chrome/userContent.css user.js; do
    [[ -e $profile/$f ]] && cp -- "$profile/$f" "$backup/$(basename -- "$f")"
  done

  render_palette "$id" "$SCRIPT_DIR/userChrome.css" "$chrome/userChrome.css"
  render_palette "$id" "$SCRIPT_DIR/userContent.css" "$chrome/userContent.css"
  if ((PREF_WRITE)); then
    prefs_file "$profile/user.js"
  fi

  printf 'firefox: chrome + prefs written; restart Firefox to see them\n'
  printf 'firefox: previous files (if any) in %s\n' "$backup"
  notify "theme applied — restart Firefox"
}

status() {
  local profile id has_css picker
  profile=$(default_profile || true)
  id=$(current_theme)
  has_css=false
  [[ -n $profile && -e $profile/chrome/userChrome.css ]] && has_css=true
  picker='default'
  if [[ -n $profile && -r $profile/user.js ]]; then
    picker=$(sed -n 's/.*"widget.use-xdg-desktop-portal.file-picker",[[:space:]]*\([0-9]*\).*/\1/p' "$profile/user.js" | head -n1)
    picker=${picker:-default}
  fi
  if ((JSON)); then
    printf '{"profile":"%s","theme":"%s","chrome":%s,"file_picker":"%s"}\n' \
      "${profile:-}" "$id" "$has_css" "$picker"
    return 0
  fi
  printf 'firefox: profile %s\n' "${profile:-none}"
  printf 'firefox: theme   %s\n' "$id"
  printf 'firefox: chrome  %s\n' "$has_css"
  printf 'firefox: picker  %s\n' "$picker"
}

# ----------------------------------------------------------------- main ----

while (($#)); do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    --no-prefs) PREF_WRITE=0 ;;
    --profile)
      shift
      [[ -n ${1:-} ]] || die "--profile needs a directory" 2
      PROFILE=$1
      ;;
    --profile=*) PROFILE=${1#*=} ;;
    --theme)
      shift
      [[ -n ${1:-} ]] || die "--theme needs an id" 2
      THEME=$1
      ;;
    --theme=*) THEME=${1#*=} ;;
    --*) die "unknown option: $1" 2 ;;
    *) MODE=$1 ;;
  esac
  shift
done

case $MODE in
  theme | apply) apply_theme ;;
  status) status ;;
  *) die "unknown command: $MODE (try --help)" 2 ;;
esac
