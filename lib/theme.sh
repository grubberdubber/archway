#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# theme.sh — palette parsing, template rendering, contrast validation, hot reload.
# shellcheck shell=bash
# shellcheck disable=SC2153
# ARCHWAY_THEME_D_DIR comes from paths.sh; globals are shared across lib files.

if [[ -n ${ARCHWAY_THEME_LOADED:-} ]]; then return 0; fi
ARCHWAY_THEME_LOADED=1

THEMES_DIR="$ARCHWAY_ROOT/themes"
THEME_REQUIRED_KEYS=(
  bg surface surface_alt overlay border text text_muted
  primary secondary tertiary error warning success selection selection_bg
)

# module -> stable filename inside $THEME_D_DIR
declare -gA THEME_TARGETS=(
  [kitty]=kitty.conf
  [hyprland]=hyprland.lua
  [waybar]=waybar.css
  [swaync]=swaync.css
  [swayosd]=swayosd.css
  [hyprlock]=hyprlock.conf
  [rofi]=rofi.rasi
  [tmux]=tmux.conf
  [starship]=starship.toml
  [fzf]=fzf.sh
  [bat]=archway.tmTheme
  [alacritty]=alacritty-theme.toml
  [gtk]=gtk.css
  [yazi]=yazi-theme.toml
  [zathura]=zathura-theme
  [mpv]=mpv-theme.conf
  [lazygit]=lazygit-theme.yml
)

# Templates shared by every theme live here; a theme only ships the modules it
# styles differently (usually just palette.toml). This is what keeps a family of
# colour variants from becoming fifteen copies of the same CSS.
THEME_SHARED_DIR="$THEMES_DIR/_shared"

declare -gA PALETTE=()

theme_path() { printf '%s/%s' "$THEMES_DIR" "$1"; }

theme_exists() { [[ -f $(theme_path "$1")/palette.toml ]]; }

theme_list() {
  local d
  for d in "$THEMES_DIR"/*/; do
    [[ -f $d/palette.toml ]] || continue
    basename -- "$d"
  done
}

# Human-readable name from theme.toml (falls back to the id).
theme_display_name() {
  local id=$1 file name=''
  file="$(theme_path "$id")/theme.toml"
  if [[ -r $file ]]; then
    name=$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"$/\1/p' "$file" | head -n1)
  fi
  printf '%s' "${name:-$id}"
}

# Where a module's template lives: the theme's own directory wins, then _shared.
theme_module_template() {
  local id=$1 module=$2 dir found=''
  for dir in "$(theme_path "$id")/$module" "$THEME_SHARED_DIR/$module"; do
    [[ -d $dir ]] || continue
    found=$(find "$dir" -type f 2> /dev/null | sort | head -n1)
    [[ -n $found ]] && break
  done
  [[ -n $found ]] || return 1
  printf '%s' "$found"
}

# Parse flat `key = "value"` / `key = number` pairs out of a TOML section.
# Only the sections we care about, and only scalar values (no nested tables).
theme_load_palette() {
  local id=$1 file
  theme_exists "$id" || die "unknown theme: $id" "$EX_USAGE"
  file="$(theme_path "$id")/palette.toml"
  PALETTE=()

  local line key value section=''
  while IFS= read -r line || [[ -n $line ]]; do
    # Only full-line comments: colour values legitimately start with '#'.
    [[ $line =~ ^[[:space:]]*# ]] && continue
    line=$(trim "$line")
    [[ -z $line ]] && continue
    if [[ $line =~ ^\[([a-zA-Z0-9_.-]+)\]$ ]]; then
      section=${BASH_REMATCH[1]}
      continue
    fi
    [[ -z $section ]] && continue
    if [[ $line =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"$ ]]; then
      key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
    elif [[ $line =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?)$ ]]; then
      key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
    else
      continue
    fi
    PALETTE["$key"]=$value
  done < "$file"

  ((${#PALETTE[@]})) || die "palette is empty or unparsable: $file" "$EX_FAIL"
}

_palette_get() { printf '%s' "${PALETTE[$1]:-}"; }

_hex_to_rgb() {
  local hex=${1#\#}
  printf '%d %d %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# WCAG 2.x relative luminance + contrast ratio, printed with 2 decimals.
contrast_ratio() {
  local fg=$1 bg=$2
  local r1 g1 b1 r2 g2 b2
  read -r r1 g1 b1 < <(_hex_to_rgb "$fg")
  read -r r2 g2 b2 < <(_hex_to_rgb "$bg")
  awk -v r1="$r1" -v g1="$g1" -v b1="$b1" -v r2="$r2" -v g2="$g2" -v b2="$b2" '
    function lin(c,  s) {
      s = c / 255
      return (s <= 0.03928) ? s / 12.92 : ((s + 0.055) / 1.055) ^ 2.4
    }
    BEGIN {
      l1 = 0.2126 * lin(r1) + 0.7152 * lin(g1) + 0.0722 * lin(b1)
      l2 = 0.2126 * lin(r2) + 0.7152 * lin(g2) + 0.0722 * lin(b2)
      if (l1 < l2) { t = l1; l1 = l2; l2 = t }
      printf "%.2f", (l1 + 0.05) / (l2 + 0.05)
    }'
}

# Required AA pairs: "fg bg minimum"
theme_contrast_pairs() {
  cat << 'EOF'
text bg 4.5
text surface 4.5
text_muted surface 4.5
primary bg 4.5
primary surface 4.5
secondary surface 4.5
tertiary surface 4.5
error surface 4.5
success surface 4.5
warning surface 4.5
selection_bg selection 3.0
EOF
}

# Decorative separators are not WCAG text/UI indicators; report them without
# failing the theme (a visible-but-subtle 1px border is intentional here).
theme_advisory_pairs() {
  cat << 'EOF'
border surface_alt 1.2
EOF
}

theme_validate() {
  local id=$1 errors=() warnings=()
  theme_load_palette "$id"

  local key
  for key in "${THEME_REQUIRED_KEYS[@]}"; do
    if [[ -z ${PALETTE[$key]:-} ]]; then
      errors+=("missing required palette key: $key")
      continue
    fi
    if [[ ! ${PALETTE[$key]} =~ ^#[0-9A-Fa-f]{6}$ ]]; then
      errors+=("invalid color for $key: ${PALETTE[$key]} (expected #RRGGBB)")
    fi
  done

  local fg bg min ratio
  while read -r fg bg min; do
    [[ ${PALETTE[$fg]:-} =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    [[ ${PALETTE[$bg]:-} =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    ratio=$(contrast_ratio "${PALETTE[$fg]}" "${PALETTE[$bg]}")
    if awk -v r="$ratio" -v m="$min" 'BEGIN { exit !(r < m) }'; then
      errors+=("contrast ${fg}/${bg} = ${ratio}:1 (needs ${min}:1)")
    else
      debug "contrast ${fg}/${bg} = ${ratio}:1 ok"
    fi
  done < <(theme_contrast_pairs)

  local adv_fg adv_bg adv_min adv_ratio
  while read -r adv_fg adv_bg adv_min; do
    [[ ${PALETTE[$adv_fg]:-} =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    [[ ${PALETTE[$adv_bg]:-} =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    adv_ratio=$(contrast_ratio "${PALETTE[$adv_fg]}" "${PALETTE[$adv_bg]}")
    if awk -v r="$adv_ratio" -v m="$adv_min" 'BEGIN { exit !(r < m) }'; then
      warnings+=("decorative contrast ${adv_fg}/${adv_bg} = ${adv_ratio}:1 (below ${adv_min}:1)")
    fi
  done < <(theme_advisory_pairs)

  local radius
  for radius in radius_window radius_input radius_pill padding; do
    if [[ -z ${PALETTE[$radius]:-} ]]; then
      warnings+=("missing geometry key: $radius")
    elif [[ ! ${PALETTE[$radius]} =~ ^[0-9]+$ ]]; then
      errors+=("geometry key $radius must be an integer: ${PALETTE[$radius]}")
    fi
  done

  [[ -n ${PALETTE[font_mono]:-} ]] || warnings+=("font_mono is not set")
  [[ -n ${PALETTE[font_ui]:-} ]] || warnings+=("font_ui is not set")

  local module template
  for module in "${!THEME_TARGETS[@]}"; do
    theme_module_template "$id" "$module" > /dev/null || warnings+=("no template for module: $module")
  done

  if ((JSON_OUT)); then
    local e w sep=''
    printf '{"theme":%s,"ok":%s,"errors":[' "$(json_str "$id")" "$([[ ${#errors[@]} -eq 0 ]] && echo true || echo false)"
    for e in "${errors[@]}"; do
      printf '%s%s' "$sep" "$(json_str "$e")"
      sep=','
    done
    printf '],"warnings":['
    sep=''
    for w in "${warnings[@]}"; do
      printf '%s%s' "$sep" "$(json_str "$w")"
      sep=','
    done
    printf ']}\n'
  else
    for w in "${warnings[@]}"; do warn "$w"; done
    for e in "${errors[@]}"; do err "$e"; done
  fi

  if ((${#errors[@]} == 0)); then
    if ((! JSON_OUT)); then
      ok "theme '$id' validates (WCAG AA contrast, required keys present)"
    fi
    return 0
  fi
  return 1
}

_sed_escape() { printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'; }

# Render a single template file, substituting every @key@ token.
theme_render_file() {
  local src=$1 dest=$2
  [[ -f $src ]] || die "template not found: $src" "$EX_FAIL"
  local sedscript='' key bare
  for key in "${!PALETTE[@]}"; do
    # @key:hex@ yields the value without the leading '#', for apps whose
    # colour syntax is ARGB (Hyprland, hyprlock) instead of CSS hex.
    bare=${PALETTE[$key]#\#}
    sedscript+="s|@${key}:hex@|$(_sed_escape "$bare")|g;"
    sedscript+="s|@${key}@|$(_sed_escape "${PALETTE[$key]}")|g;"
  done
  if ((DRY_RUN)); then
    ui_note "[dry-run] render $src -> $dest"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$dest")"
  sed -e "$sedscript" "$src" > "$dest"
  chmod 644 -- "$dest"
}

# A theme may adjust a shared module without duplicating it: files under
# themes/<id>/overrides/ are rendered and appended after the module's own
# template. Geometry belongs in data, so a flush status line is one small file
# instead of a 400-line copy of the shared stylesheet that would drift.
theme_render_overrides() {
  local id=$1 dest=$2 module target src tmp
  for module in "${!THEME_TARGETS[@]}"; do
    target=${THEME_TARGETS[$module]}
    src="$(theme_path "$id")/overrides/$target"
    [[ -f $src && -f $dest/$target ]] || continue
    tmp="$dest/.${target}.override"
    theme_render_file "$src" "$tmp"
    ((DRY_RUN)) && continue
    printf '\n' >> "$dest/$target"
    cat -- "$tmp" >> "$dest/$target"
    rm -f -- "$tmp"
  done
}

# Render every module of a theme into <dest_dir>/<module>.<ext>.
theme_render() {
  local id=$1 dest=$2
  theme_load_palette "$id"
  local module template
  for module in "${!THEME_TARGETS[@]}"; do
    template=$(theme_module_template "$id" "$module") || continue
    theme_render_file "$template" "$dest/${THEME_TARGETS[$module]}"
  done
  theme_render_overrides "$id" "$dest"

  # Drop artifacts for targets this theme no longer ships, otherwise a file from
  # an older Archway (e.g. hyprland.conf after the Lua migration) lingers and
  # gets sourced by mistake.
  local file target keep
  for file in "$dest"/*; do
    [[ -f $file ]] || continue
    keep=0
    for target in "${THEME_TARGETS[@]}"; do
      if [[ $(basename -- "$file") == "$target" ]]; then
        keep=1
        break
      fi
    done
    [[ $keep == 1 || $(basename -- "$file") == theme.conf ]] && continue
    rm -f -- "$file"
  done
  ok "rendered theme '$id' into $dest"
}

theme_nvim_hook_target() {
  printf '%s/nvim/lua/archway.lua' "$XDG_CONFIG_HOME"
}

# Write the local Neovim hook. Never edits tracked files (AGENTS.md §9.5).
theme_nvim_sync() {
  local id=$1 hook nvim_dir=$XDG_CONFIG_HOME/nvim
  hook=$(theme_nvim_hook_target)

  if [[ ! -d $nvim_dir ]]; then
    ui_note "Neovim config not installed; skipping theme hook"
    return 0
  fi

  if have git && git -C "$nvim_dir" rev-parse --git-dir > /dev/null 2>&1; then
    if ! git -C "$nvim_dir" check-ignore -q 'lua/archway.lua'; then
      err "Neovim checkout does not ignore lua/archway.lua; upstream hook is missing."
      err "Archway will not edit tracked files. Ask upstream to add the hook (AGENTS.md §9.5)."
      return 1
    fi
    if git -C "$nvim_dir" ls-files --error-unmatch 'lua/archway.lua' > /dev/null 2>&1; then
      err "lua/archway.lua is tracked upstream; refusing to write it."
      return 1
    fi
  fi

  if ((DRY_RUN)); then
    ui_note "[dry-run] write Neovim hook: $hook"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$hook")"
  cat > "$hook" << EOF
-- Generated by Archway. Local override, intentionally untracked upstream.
-- Active theme: $id
return { theme = "$id" }
EOF
  ok "Neovim theme hook written: $hook"
}

theme_set() {
  local id=$1
  require_not_root
  theme_validate "$id" || die "theme '$id' failed validation" "$EX_FAIL"

  ensure_dirs "$THEME_D_DIR"
  ui_header "Applying theme: $id"
  theme_render "$id" "$THEME_D_DIR"

  if ((! DRY_RUN)); then
    state_set "$THEME_STATE_FILE" theme "$id"
    render_theme_metadata "$id"
    theme_publish_generated
  fi

  local rc=0
  theme_nvim_sync "$id" || rc=1
  theme_reload || true

  if ((rc != 0)); then
    err "theme applied everywhere except Neovim (see messages above)"
    return "$EX_FAIL"
  fi
  ok "theme '$id' is active; new shells pick up the rest"
}

# waybar, swaync and bat only read assets from their own config trees, so those
# artifacts are published next to them and imported from the tracked config.
# Everything else is sourced from theme.d/ by absolute path.
theme_publish_generated() {
  local waybar_dir="$XDG_CONFIG_HOME/waybar"
  local swaync_dir="$XDG_CONFIG_HOME/swaync"
  local swayosd_dir="$XDG_CONFIG_HOME/swayosd"
  local bat_dir="$XDG_CONFIG_HOME/bat/themes"
  # GTK3 reads exactly one gtk.css per user; publishing as archway.css keeps it
  # side by side with a gtk.css the user owns, which imports it in one line.
  local gtk_dir="$XDG_CONFIG_HOME/gtk-3.0"
  # Yazi reads exactly one theme.toml and has no include, so the generated theme
  # replaces it. Whatever was there before the first Archway run is backed up
  # once and named, instead of disappearing silently (AGENTS.md §2.1).
  local yazi_dir="$XDG_CONFIG_HOME/yazi"
  local f

  if [[ -f $THEME_D_DIR/waybar.css ]]; then
    mkdir -p -- "$waybar_dir"
    cp -f -- "$THEME_D_DIR/waybar.css" "$waybar_dir/theme.css"
    record_managed "$waybar_dir/theme.css" theme
  fi
  if [[ -f $THEME_D_DIR/swaync.css ]]; then
    mkdir -p -- "$swaync_dir"
    cp -f -- "$THEME_D_DIR/swaync.css" "$swaync_dir/theme.css"
    record_managed "$swaync_dir/theme.css" theme
  fi
  # swayosd only reads $XDG_CONFIG_HOME/swayosd/style.css; it has no include.
  if [[ -f $THEME_D_DIR/swayosd.css ]]; then
    mkdir -p -- "$swayosd_dir"
    cp -f -- "$THEME_D_DIR/swayosd.css" "$swayosd_dir/style.css"
    record_managed "$swayosd_dir/style.css" theme
  fi
  if [[ -f $THEME_D_DIR/gtk.css ]]; then
    mkdir -p -- "$gtk_dir"
    cp -f -- "$THEME_D_DIR/gtk.css" "$gtk_dir/archway.css"
    record_managed "$gtk_dir/archway.css" theme
  fi
  if [[ -f $THEME_D_DIR/yazi-theme.toml ]]; then
    mkdir -p -- "$yazi_dir"
    if [[ -e $yazi_dir/theme.toml ]] && ! is_managed "$yazi_dir/theme.toml"; then
      local backup_dir
      backup_dir="$STATE_DIR/backups/$(date +%Y%m%dT%H%M%S)"
      mkdir -p -- "$backup_dir"
      cp -a -- "$yazi_dir/theme.toml" "$backup_dir/yazi-theme.toml"
      ui_note "previous Yazi theme kept at $backup_dir/yazi-theme.toml"
    fi
    cp -f -- "$THEME_D_DIR/yazi-theme.toml" "$yazi_dir/theme.toml"
    record_managed "$yazi_dir/theme.toml" theme
  fi
  for f in "$THEME_D_DIR"/*.tmTheme; do
    [[ -e $f ]] || continue
    mkdir -p -- "$bat_dir"
    cp -f -- "$f" "$bat_dir/"
    record_managed "$bat_dir/$(basename -- "$f")" theme
  done
  # bat caches themes by file name; without a rebuild it keeps the old palette.
  if have bat; then
    timeout 10 bat cache --build > /dev/null 2>&1 || true
  fi
}

render_theme_metadata() {
  local id=$1 file
  file="$THEME_D_DIR/theme.conf"
  {
    printf '# generated by archway; do not edit\n'
    printf 'ARCHWAY_THEME=%s\n' "$id"
    printf 'ARCHWAY_THEME_NAME=%s\n' "${PALETTE[theme_name]:-$id}"
    printf 'ARCHWAY_THEME_DIR=%s\n' "$THEME_D_DIR"
  } > "$file"
  chmod 644 "$file"
}

theme_reload() {
  if ((DRY_RUN)); then
    ui_note "[dry-run] would reload Hyprland, waybar, swaync, kitty, tmux"
    return 0
  fi
  # Never restart or kill the compositor: a config reload is enough, and the
  # user's session must survive a theme change (AGENTS.md §8.2).
  #
  # Every step is guarded twice: only touch apps that are actually running, and
  # bound the call with timeout. `swaync-client -rs` blocks forever when no
  # daemon owns the name (e.g. changing the theme from a non-Hyprland session),
  # which used to hang the whole install.
  if have hyprctl && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    timeout 5 hyprctl reload > /dev/null 2>&1 || true
  fi
  # kitty: every instance listens on /tmp/kitty-archway-<pid> (kitty.conf sets
  # `listen_on`), so a theme change reaches the terminals that are already open,
  # not only new ones. KITTY_LISTEN_ON is useless here: the applet runs from a
  # keybind or rofi, whose environment never belonged to kitty. `load-config`
  # also re-reads opacity and ligature settings from the tracked config.
  local kitty_sock
  if have kitty; then
    for kitty_sock in /tmp/kitty-archway-*; do
      [[ -S $kitty_sock ]] || continue
      timeout 5 kitty @ --to "unix:$kitty_sock" set-colors --all --configured "$THEME_D_DIR/kitty.conf" > /dev/null 2>&1 || true
      timeout 5 kitty @ --to "unix:$kitty_sock" load-config > /dev/null 2>&1 || true
    done
  fi
  if have pgrep && pgrep -x waybar > /dev/null 2>&1; then
    timeout 5 pkill -SIGUSR2 -x waybar > /dev/null 2>&1 || true
  fi
  if have pgrep && have swaync-client && pgrep -x swaync > /dev/null 2>&1; then
    timeout 5 swaync-client -rs > /dev/null 2>&1 || true
  fi
  if have tmux && tmux list-sessions > /dev/null 2>&1; then
    tmux setenv -g ARCHWAY_THEME_DIR "$THEME_D_DIR"
    timeout 5 tmux source-file "$XDG_CONFIG_HOME/tmux/tmux.conf" > /dev/null 2>&1 || true
  fi
  ok "reloaded running components"
}

# Compare the theme artifact in themes/<id>/nvim with palette.toml (CI drift check).
theme_nvim_contract() {
  local id=$1 lua errors=()
  theme_load_palette "$id"
  lua="$(theme_path "$id")/nvim/android-mount.lua"
  [[ -f $lua ]] || die "missing Neovim theme artifact: $lua" "$EX_FAIL"

  local key fg
  local -A reported=()
  for key in "${!PALETTE[@]}"; do
    fg=${PALETTE[$key]}
    [[ $fg =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    [[ -n ${reported[$fg]:-} ]] && continue
    reported[$fg]=1
    grep -qi -- "$fg" "$lua" || errors+=("$key ($fg) missing from Neovim artifact")
  done

  if ((JSON_OUT)); then
    printf '{"theme":%s,"artifact":%s,"ok":%s,"errors":[' "$(json_str "$id")" "$(json_str "$lua")" \
      "$([[ ${#errors[@]} -eq 0 ]] && echo true || echo false)"
    local sep='' e
    for e in "${errors[@]}"; do
      printf '%s%s' "$sep" "$(json_str "$e")"
      sep=','
    done
    printf ']}\n'
  else
    local e
    for e in "${errors[@]}"; do err "$e"; done
  fi
  if ((${#errors[@]} == 0)); then return 0; fi
  return 1
}

theme_preview() {
  local id=$1 previous
  previous=$(current_theme)
  ui_note "previewing '$id'; previous theme was '$previous'"
  theme_set "$id"
  ui_note "run 'archway theme set $previous' to go back"
}
