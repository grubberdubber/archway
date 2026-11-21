#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# keys.sh — parse keybinds.toml, validate, generate the Hyprland binds and the
# cheatsheet. Hyprland is the only compositor we generate for (AGENTS.md §10).
# shellcheck shell=bash

if [[ -n ${ARCHWAY_KEYS_LOADED:-} ]]; then return 0; fi
ARCHWAY_KEYS_LOADED=1

KEYBINDS_FILE="$ARCHWAY_ROOT/keybinds/keybinds.toml"
HYPRBINDS_TARGET="$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.lua"
KEYDOC_TARGET="$ARCHWAY_ROOT/docs/keybinds.md"

declare -ga K_ID=() K_KEYS=() K_CMD=() K_CAT=() K_DESC=() K_DISPATCH=() K_ARG=() K_REPEAT=()

keys_parse() {
  local file=${1:-$KEYBINDS_FILE}
  [[ -r $file ]] || die "keybinds file not found: $file" "$EX_PREFLIGHT"

  K_ID=() K_KEYS=() K_CMD=() K_CAT=() K_DESC=() K_DISPATCH=() K_ARG=() K_REPEAT=()
  local line key val idx=-1
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    line=$(trim "$line")
    [[ -z $line ]] && continue

    if [[ $line == '[[keybind]]' ]]; then
      idx=$((idx + 1))
      K_ID[idx]='' K_KEYS[idx]='' K_CMD[idx]='' K_CAT[idx]='' K_DESC[idx]=''
      K_DISPATCH[idx]='' K_ARG[idx]='' K_REPEAT[idx]=''
      continue
    fi
    ((idx < 0)) && continue

    if [[ $line =~ ^([a-z_]+)[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      key=${BASH_REMATCH[1]}
      val=${BASH_REMATCH[2]}
    else
      die "malformed line in $file: $line" "$EX_PREFLIGHT"
    fi

    case $key in
      id) K_ID[idx]=$val ;;
      keys) K_KEYS[idx]=$val ;;
      command) K_CMD[idx]=$val ;;
      category) K_CAT[idx]=$val ;;
      description) K_DESC[idx]=$val ;;
      dispatcher) K_DISPATCH[idx]=$val ;;
      argument) K_ARG[idx]=$val ;;
      repeat) K_REPEAT[idx]=$val ;;
      *) warn "unknown key in $file: $key" ;;
    esac
  done < "$file"

  ((${#K_ID[@]})) || die "no keybinds parsed from $file" "$EX_PREFLIGHT"
}

# Normalise a chord for duplicate detection: lowercase, alias ctrl->control,
# tokens trimmed and sorted (modifier order is irrelevant to Hyprland).
keys_normalize() {
  local chord=$1 token
  local -a tokens=() out=()
  IFS='+' read -r -a tokens <<< "${chord,,}"
  for token in "${tokens[@]}"; do
    token=$(trim "$token")
    [[ -z $token ]] && continue
    case $token in
      ctrl | control) token=ctrl ;;
      super | mod4 | win) token=super ;;
      alt | mod1) token=alt ;;
      shift) token='shift' ;;
    esac
    out+=("$token")
  done
  printf '%s' "$(printf '%s\n' "${out[@]}" | sort | paste -sd+ -)"
}

# Combinations we refuse to bind: they belong to the kernel/firmware.
keys_is_reserved() {
  local chord=${1,,}
  if [[ $chord =~ (^|\+)[[:space:]]*(ctrl|control)[[:space:]]*(\+|$) ]] &&
    [[ $chord =~ (^|\+)[[:space:]]*alt[[:space:]]*(\+|$) ]]; then
    if [[ $chord =~ (^|\+)[[:space:]]*f([1-9]|1[0-2])[[:space:]]*(\+|$) ]]; then
      return 0
    fi
  fi
  [[ $chord == *sysrq* ]] && return 0
  return 1
}

keys_validate() {
  local errors=() i norm
  local -A seen=()

  keys_parse
  for i in "${!K_ID[@]}"; do
    [[ -n ${K_ID[i]} ]] || errors+=("entry #$((i + 1)) has no id")
    [[ -n ${K_KEYS[i]} ]] || errors+=("${K_ID[i]:-entry #$((i + 1))}: empty keys")
    [[ -n ${K_CAT[i]} ]] || errors+=("${K_ID[i]:-entry #$((i + 1))}: empty category")
    if [[ -z ${K_CMD[i]} && -z ${K_DISPATCH[i]} ]]; then
      errors+=("${K_ID[i]:-entry #$((i + 1))}: needs a command or a dispatcher")
    fi
    if [[ -n ${K_CMD[i]} && -n ${K_DISPATCH[i]} ]]; then
      errors+=("${K_ID[i]}: command and dispatcher are mutually exclusive")
    fi
    if [[ -n ${K_ARG[i]} && -z ${K_DISPATCH[i]} ]]; then
      errors+=("${K_ID[i]}: argument requires a dispatcher")
    fi
    if [[ -n ${K_REPEAT[i]} && ${K_REPEAT[i]} != yes && ${K_REPEAT[i]} != no ]]; then
      errors+=("${K_ID[i]}: repeat must be 'yes' or 'no'")
    fi

    [[ -z ${K_KEYS[i]} ]] && continue
    if keys_is_reserved "${K_KEYS[i]}"; then
      errors+=("${K_ID[i]}: '${K_KEYS[i]}' is reserved by the kernel/firmware")
    fi
    norm=$(keys_normalize "${K_KEYS[i]}")
    if [[ -n ${seen[$norm]:-} ]]; then
      errors+=("duplicate chord '${K_KEYS[i]}' in '${K_ID[i]}' and '${seen[$norm]}'")
    else
      seen[$norm]=${K_ID[i]}
    fi
  done

  local -A ids=()
  for i in "${!K_ID[@]}"; do
    [[ -z ${K_ID[i]} ]] && continue
    if [[ -n ${ids[${K_ID[i]}]:-} ]]; then
      errors+=("duplicate id: ${K_ID[i]}")
    fi
    ids[${K_ID[i]}]=1
  done

  if ((JSON_OUT)); then
    local sep='' e
    printf '{"binds":%d,"ok":%s,"errors":[' "${#K_ID[@]}" \
      "$([[ ${#errors[@]} -eq 0 ]] && echo true || echo false)"
    for e in "${errors[@]}"; do
      printf '%s%s' "$sep" "$(json_str "$e")"
      sep=','
    done
    printf ']}\n'
  else
    local e
    for e in "${errors[@]}"; do err "$e"; done
    ((${#errors[@]} == 0)) && ok "keybinds OK (${#K_ID[@]} binds)"
  fi
  ((${#errors[@]} == 0)) && return 0
  return 1
}

# XKB keysym names are case-sensitive: `space` and `Space` are not the same
# token to Hyprland's parser, and a lowercase word bind fails to register.
keys_canonical_key() {
  local key=$1
  case ${key,,} in
    space) printf 'Space' ;;
    escape) printf 'Escape' ;;
    return) printf 'Return' ;;
    tab) printf 'Tab' ;;
    print) printf 'Print' ;;
    backspace) printf 'BackSpace' ;;
    delete) printf 'Delete' ;;
    insert) printf 'Insert' ;;
    home) printf 'Home' ;;
    end) printf 'End' ;;
    page_up | pageup | prior) printf 'Prior' ;;
    page_down | pagedown | next) printf 'Next' ;;
    *) printf '%s' "$key" ;;
  esac
}

# "super + shift + Q" -> "SUPER SHIFT" (mods) and "Q" (key). Single characters
# are upper-cased; keysym names (Return, Escape, Print, slash, XF86Audio*) are
# already in the form Hyprland expects.
keys_split_chord() {
  local chord=$1 token key=''
  local -a tokens=() mods=()
  IFS='+' read -r -a tokens <<< "$chord"
  local last=$((${#tokens[@]} - 1)) i
  for i in "${!tokens[@]}"; do
    token=$(trim "${tokens[i]}")
    [[ -z $token ]] && continue
    if ((i == last)); then
      if ((${#token} == 1)); then token=${token^^}; fi
      key=$(keys_canonical_key "$token")
      continue
    fi
    case ${token,,} in
      super | mod4 | win) mods+=(SUPER) ;;
      shift) mods+=(SHIFT) ;;
      alt | mod1) mods+=(ALT) ;;
      ctrl | control) mods+=(CTRL) ;;
      *) mods+=("${token^^}") ;;
    esac
  done
  printf '%s|%s' "$(
    IFS=' '
    printf '%s' "${mods[*]}"
  )" "$key"
}

# Human-readable action for the cheatsheet.
keys_action_text() {
  local i=$1
  if [[ -n ${K_DISPATCH[i]} ]]; then
    printf 'hyprctl dispatch %s%s' "${K_DISPATCH[i]}" "${K_ARG[i]:+ ${K_ARG[i]}}"
  else
    printf '%s' "${K_CMD[i]}"
  fi
}

# Lua string literal for the Hyprland configuration API.
keys_lua_str() {
  local s=${1//\\/\\\\}
  printf '"%s"' "${s//\"/\\\"}"
}

keys_direction() {
  case $1 in
    l) printf 'left' ;;
    d) printf 'down' ;;
    u) printf 'up' ;;
    r) printf 'right' ;;
    *) die "unknown direction '$1'" "$EX_PREFLIGHT" ;;
  esac
}

# Map a dispatcher from keybinds.toml to its hl.dsp.* call. Hyprland 0.57 has
# no hyprctl-style dispatcher strings in the config, so an unknown name must
# fail regeneration instead of writing a bind that silently does nothing.
keys_hypr_action() {
  local disp=$1 arg=$2 x y
  case $disp in
    exec) printf 'hl.dsp.exec_cmd(%s)' "$(keys_lua_str "$arg")" ;;
    killactive) printf 'hl.dsp.window.close()' ;;
    # Explicit mode: the no-argument form toggles whatever state the window is
    # in, so a fullscreen bind could land on "maximized" instead.
    fullscreen) printf 'hl.dsp.window.fullscreen({ mode = "fullscreen" })' ;;
    togglefloating) printf 'hl.dsp.window.float({ action = "toggle" })' ;;
    reload) printf 'hl.dsp.reload_config()' ;;
    movefocus) printf 'hl.dsp.focus({ direction = "%s" })' "$(keys_direction "$arg")" ;;
    movewindow) printf 'hl.dsp.window.move({ direction = "%s" })' "$(keys_direction "$arg")" ;;
    resizeactive)
      read -r x y <<< "$arg"
      [[ $x =~ ^-?[0-9]+$ && $y =~ ^-?[0-9]+$ ]] ||
        die "resizeactive needs two integers, got '$arg'" "$EX_PREFLIGHT"
      printf 'hl.dsp.window.resize({ x = %s, y = %s, relative = true })' "$x" "$y"
      ;;
    workspace)
      [[ $arg =~ ^[0-9]+$ ]] || die "workspace needs a number, got '$arg'" "$EX_PREFLIGHT"
      printf 'hl.dsp.focus({ workspace = %s })' "$arg"
      ;;
    movetoworkspace)
      [[ $arg =~ ^[0-9]+$ ]] || die "movetoworkspace needs a number, got '$arg'" "$EX_PREFLIGHT"
      printf 'hl.dsp.window.move({ workspace = %s })' "$arg"
      ;;
    *) die "no Hyprland Lua mapping for dispatcher '$disp'" "$EX_PREFLIGHT" ;;
  esac
}

keys_generate_hypr() {
  local target=${1:-$HYPRBINDS_TARGET}
  {
    printf '%s\n' '-- Generated by archway from keybinds/keybinds.toml. Do not edit.'
    printf '%s\n\n' '-- Regenerate: archway keys generate'
    local cat i split mods key chord action
    local -a cats=()
    while IFS= read -r cat; do cats+=("$cat"); done < <(
      for i in "${!K_CAT[@]}"; do printf '%s\n' "${K_CAT[i]}"; done | awk '!seen[$0]++'
    )
    for cat in "${cats[@]}"; do
      printf '%s\n\n' "-- --- $cat ---"
      for i in "${!K_ID[@]}"; do
        [[ ${K_CAT[i]} == "$cat" ]] || continue
        split=$(keys_split_chord "${K_KEYS[i]}")
        mods=${split%%|*}
        key=${split#*|}
        if [[ -n $mods ]]; then
          # "SUPER + SHIFT + Q": every modifier needs its own separator.
          chord="${mods// / + } + $key"
        else
          chord=$key
        fi
        if [[ -n ${K_DISPATCH[i]} ]]; then
          action=$(keys_hypr_action "${K_DISPATCH[i]}" "${K_ARG[i]}") || return 1
        else
          action=$(keys_hypr_action exec "${K_CMD[i]}") || return 1
        fi
        if [[ ${K_REPEAT[i]} == yes ]]; then
          printf 'hl.bind(%s, %s, { repeating = true })\n' "$(keys_lua_str "$chord")" "$action"
        else
          printf 'hl.bind(%s, %s)\n' "$(keys_lua_str "$chord")" "$action"
        fi
      done
      printf '\n'
    done
  } > "$target.tmp"
  if ((DRY_RUN)); then
    ui_note "[dry-run] would write $target"
    rm -f -- "$target.tmp"
    return 0
  fi
  mv -f -- "$target.tmp" "$target"
  ok "Hyprland binds written: $target"
}

keys_generate_doc() {
  local target=${1:-$KEYDOC_TARGET}
  mkdir -p -- "$(dirname -- "$target")"
  # shellcheck disable=SC2016 # markdown, not shell expansion
  {
    printf '# Keybinds\n\n'
    printf '<!-- Generated by `archway keys generate` from `keybinds/keybinds.toml`. Do not edit. -->\n\n'
    printf 'Press `Super + /` at any time to open this list in a floating terminal.\n\n'
    local cat i action
    local -a cats=()
    while IFS= read -r cat; do cats+=("$cat"); done < <(
      for i in "${!K_CAT[@]}"; do printf '%s\n' "${K_CAT[i]}"; done | awk '!seen[$0]++'
    )
    for cat in "${cats[@]}"; do
      printf '## %s\n\n' "$(printf '%s' "$cat" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
      printf '| Key | Action | Command |\n|---|---|---|\n'
      for i in "${!K_ID[@]}"; do
        [[ ${K_CAT[i]} == "$cat" ]] || continue
        action=$(keys_action_text "$i")
        printf '| `%s` | %s | `%s` |\n' "${K_KEYS[i]}" "${K_DESC[i]}" "${action//|/\\|}"
      done
      printf '\n'
    done
  } > "$target.tmp"

  if ((DRY_RUN)); then
    ui_note "[dry-run] would write $target"
    rm -f -- "$target.tmp"
    return 0
  fi
  mv -f -- "$target.tmp" "$target"
  ok "cheatsheet written: $target"
}

keys_generate() {
  keys_validate || die "refusing to generate from invalid keybinds" "$EX_FAIL"
  mkdir -p -- "$(dirname -- "$HYPRBINDS_TARGET")"
  keys_generate_hypr "$HYPRBINDS_TARGET"
  keys_generate_doc "$KEYDOC_TARGET"
  keys_apply_live
}

# Where the running compositor actually reads the binds from.
keys_live_path() { printf '%s/hypr/conf.d/20-keybinds.lua' "$XDG_CONFIG_HOME"; }

keys_live_stale() {
  local live
  live=$(keys_live_path)
  [[ -e $live ]] || return 1
  keys_same_content "$HYPRBINDS_TARGET" "$live" && return 1
  return 0
}

keys_reload_session() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
  have hyprctl || return 0
  if hyprctl reload > /dev/null 2>&1; then
    ok "Hyprland reloaded; new binds are live"
  else
    warn "could not reload Hyprland; press Super+Alt+R"
  fi
}

# The checkout is not what Hyprland reads. The generated file reaches the session
# through $XDG_CONFIG_HOME/hypr/conf.d and only a reload makes the new chords
# live — that gap is exactly how a new bind looks dead while every test passes.
keys_apply_live() {
  local live src
  live=$(keys_live_path)
  [[ -e $live ]] || return 0
  keys_same_content "$HYPRBINDS_TARGET" "$live" && return 0

  if ((DRY_RUN)); then
    ui_note "[dry-run] would copy $HYPRBINDS_TARGET -> $live"
    return 0
  fi
  cp -f -- "$HYPRBINDS_TARGET" "$live"
  record_managed "$live"
  ok "live Hyprland binds updated: $live"
  # Keep the chezmoi source in step, otherwise the next apply would undo this.
  if have chezmoi; then
    src=$(chezmoi source-path 2> /dev/null || true)
    if [[ -n $src && -f $src/dot_config/hypr/conf.d/20-keybinds.lua ]]; then
      cp -f -- "$HYPRBINDS_TARGET" "$src/dot_config/hypr/conf.d/20-keybinds.lua"
    fi
  fi
  keys_reload_session
}

# Content comparison without diffutils: a bare Arch container has coreutils but
# may not ship `diff`, and a missing diff must never look like drift.
keys_same_content() {
  local a=$1 b=$2
  [[ -r $a && -r $b ]] || return 1
  [[ $(sha256sum -- "$a" | cut -d' ' -f1) == "$(sha256sum -- "$b" | cut -d' ' -f1)" ]]
}

# Ensure the committed artifacts match the source (used by CI and `keys check`).
keys_check() {
  keys_parse
  local tmp rc=0 file target
  tmp=$(mktemp -d)
  keys_generate_hypr "$tmp/binds.conf" > /dev/null 2>&1 || true
  keys_generate_doc "$tmp/keybinds.md" > /dev/null 2>&1 || true

  for pair in "binds.conf:$HYPRBINDS_TARGET" "keybinds.md:$KEYDOC_TARGET"; do
    file=$tmp/${pair%%:*}
    target=${pair#*:}
    if ! keys_same_content "$file" "$target"; then
      err "$(basename -- "$target") is out of date; run 'archway keys generate'"
      # Unified diff is optional diagnostics, never required to detect drift.
      if have diff; then
        diff -u "$target" "$file" 2> /dev/null | head -n 40 >&2 || true
      fi
      rc=1
    fi
  done

  rm -rf -- "$tmp"
  ((rc == 0)) && ok "generated keybind artifacts are up to date"
  return "$rc"
}

keys_list() {
  keys_parse
  if ((JSON_OUT)); then
    local i sep='' action
    printf '['
    for i in "${!K_ID[@]}"; do
      action=$(keys_action_text "$i")
      printf '%s{"id":%s,"keys":%s,"command":%s,"dispatcher":%s,"argument":%s,"category":%s,"description":%s}' \
        "$sep" "$(json_str "${K_ID[i]}")" "$(json_str "${K_KEYS[i]}")" "$(json_str "${K_CMD[i]}")" \
        "$(json_str "${K_DISPATCH[i]}")" "$(json_str "${K_ARG[i]}")" \
        "$(json_str "${K_CAT[i]}")" "$(json_str "${K_DESC[i]}")"
      sep=','
    done
    printf ']\n'
    return 0
  fi
  printf '%-28s %-34s %s\n' 'KEYS' 'ACTION' 'CATEGORY'
  local i
  for i in "${!K_ID[@]}"; do
    printf '%-28s %-34s %s\n' "${K_KEYS[i]}" "${K_DESC[i]}" "${K_CAT[i]}"
  done
}

# Binds defined in the checkout but absent from the running compositor.
#
# A stale session is silent by nature: the chord simply falls through to the
# focused app (Ctrl+K kills the line in a terminal). Asking Hyprland what it
# actually loaded is the only way to catch the whole class of bug.
#
# Returns 0 when every bind is live, 1 with one chord per line on stdout when
# some are missing, and 2 when there is no session to ask.
keys_loaded_missing() {
  local sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
  have hyprctl && have jq || return 2
  [[ -n $sig ]] || return 2

  local loaded
  loaded=$(hyprctl binds -j 2> /dev/null | jq -r '.[] | "\(.modmask)\(.key)"' | tr '[:lower:]' '[:upper:]') || return 2
  [[ -n $loaded ]] || return 2

  keys_parse
  local i mods key mask bit missing=()
  for i in "${!K_ID[@]}"; do
    IFS='|' read -r mods key < <(keys_split_chord "${K_KEYS[i]}")
    mask=0
    for bit in $mods; do
      case $bit in
        SHIFT) mask=$((mask + 1)) ;;
        CTRL) mask=$((mask + 4)) ;;
        ALT) mask=$((mask + 8)) ;;
        SUPER) mask=$((mask + 64)) ;;
      esac
    done
    grep -qxF -- "$mask${key^^}" <<< "$loaded" || missing+=("${K_KEYS[i]}")
  done
  ((${#missing[@]})) || return 0
  printf '%s\n' "${missing[@]}"
  return 1
}

keys_search() {
  local pattern=$1 i found=0 action
  keys_parse
  for i in "${!K_ID[@]}"; do
    action=$(keys_action_text "$i")
    if [[ ${K_KEYS[i]}${K_DESC[i]}${action}${K_CAT[i]} == *"$pattern"* ]]; then
      printf '%-28s %-34s %s\n' "${K_KEYS[i]}" "${K_DESC[i]}" "$action"
      found=1
    fi
  done
  ((found)) || {
    warn "no keybind matches '$pattern'"
    return 1
  }
}
