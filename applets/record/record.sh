#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# record — start and stop a Wayland screen recording from one keybind.
#
# wf-recorder is the recorder: it is small, lives in the official repos, and
# writes a plain file. What was missing is the part every other desktop has and
# hand-rolled dotfiles never do — knowing whether a recording is running, where
# it is going, and how to stop it cleanly so the file is playable.
#
# wf-recorder finalises the container on SIGINT, so "stop" is a signal and a
# wait, not a kill. State lives in ~/.local/state/archway/record so a second
# press (or the bar) can find the process again even in another shell.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ACTION='status'
REGION=0
AUDIO=0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
STATE_FILE="$STATE_DIR/record"
LOG_FILE="$STATE_DIR/recording.log"
OUT_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"

usage() {
  cat << 'EOF'
record — screen recording (wf-recorder)

Usage:
  record.sh status [--json]
  record.sh start [--region] [--audio]
  record.sh stop
  record.sh toggle [--region] [--audio]     # Super+Shift+R
  record.sh --dry-run <action>

start     record the whole output, or a slurp selection with --region, and
          system audio with --audio. Files go to ~/Videos/Recordings as
          recording-YYYYmmdd-HHMMSS.mkv.
stop      send SIGINT (wf-recorder finalises the file on it), wait for the
          process, then report the path and duration.
toggle    stop if something is recording, start otherwise.
status    running file, elapsed seconds and file size.

The bar's recording pill appears while wf-recorder runs, so there is no extra
module and no polling loop here.
EOF
}

die() {
  printf 'record: %s\n' "$1" >&2
  notify "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "Screen recording" "$1" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

state_get() {
  local key=$1
  [[ -r $STATE_FILE ]] || return 0
  awk -F= -v k="$key" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$STATE_FILE"
}

state_write() {
  local file=$1 pid=$2 mode=$3
  ((DRY_RUN)) && return 0
  mkdir -p -- "$STATE_DIR"
  {
    printf 'pid=%s\n' "$pid"
    printf 'file=%s\n' "$file"
    printf 'mode=%s\n' "$mode"
    printf 'started=%s\n' "$(date +%s)"
  } > "$STATE_FILE"
}

state_clear() {
  ((DRY_RUN)) || rm -f -- "$STATE_FILE"
}

pid_alive() {
  local pid=${1:-} state
  [[ -n $pid ]] || return 1
  # kill -0 succeeds for a zombie, and a container whose pid 1 is not an init
  # does not reap orphans — `stop` would then wait the full 6s and report a
  # failure for a recorder that already exited.
  state=$(ps -o stat= -p "$pid" 2> /dev/null) || return 1
  [[ -n $state && ${state:0:1} != Z ]]
}

# True when a recorder is running, whether Archway started it or not: the pill
# and `toggle` must agree with `pgrep`, which is what the bar shows.
recording_pid() {
  local pid
  pid=$(state_get pid)
  if pid_alive "$pid"; then
    printf '%s' "$pid"
    return 0
  fi
  # Only an exact process name: matching the command line would also hit the
  # applet itself, its tests and any shell that merely mentions the recorder
  # (a container's pid 1 does), and `start` would refuse to record.
  pid=$(pgrep -x wf-recorder 2> /dev/null | head -n 1 || true)
  [[ -n $pid ]] && printf '%s' "$pid"
}

record_file() {
  local file
  file=$(state_get file)
  if [[ -n $file ]]; then
    printf '%s' "$file"
    return 0
  fi
  # Not started by Archway: ask the process for its open file, which is the only
  # honest source. lsof may be absent, so this is best-effort.
  local pid
  pid=$(recording_pid) || return 0
  have lsof && lsof -p "$pid" 2> /dev/null | awk '/\.(mkv|mp4|webm)$/ { print $NF; exit }'
}

start_record() {
  # --dry-run prints the plan even on a machine without the recorder, which is
  # how CI checks this applet (the container ships no Wayland compositor).
  ((DRY_RUN)) || have wf-recorder || die "wf-recorder is not installed (pacman -S wf-recorder)" 3
  local pid
  pid=$(recording_pid || true)
  if [[ -n $pid ]]; then
    die "already recording (pid $pid); press the shortcut again to stop" 1
  fi

  local geometry='' mode='full'
  if ((REGION)); then
    if ((DRY_RUN)); then
      geometry='<slurp selection>'
    else
      have slurp || die "slurp is required for --region (pacman -S slurp)" 3
      geometry=$(slurp) || exit 4
    fi
    [[ -n $geometry ]] || exit 4
    mode="region $geometry"
  fi

  local file
  file="$OUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
  local -a cmd=(wf-recorder -f "$file")
  [[ -n $geometry ]] && cmd+=(-g "$geometry")
  ((AUDIO)) && cmd+=(--audio)

  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "${cmd[*]}"
    return 0
  fi

  mkdir -p -- "$OUT_DIR" "$STATE_DIR"
  # setsid keeps the recorder alive after the applet exits (a keybind has no
  # terminal to keep it attached to) and puts it in its own session, so a
  # Ctrl+C aimed at a terminal cannot reach it.
  #
  # $! is not trustworthy here: it can be setsid or a wrapper shell. The child
  # writes $$ and then execs the recorder, so that number is the process we must
  # signal later, not something to rediscover with pgrep.
  local pid_file
  pid_file=$(mktemp "$STATE_DIR/record-pid.XXXXXX")
  # A command started with `&` inherits SIGINT/SIGQUIT ignored (POSIX), and an
  # ignored signal cannot be trapped by the child — wf-recorder would then never
  # finalise the file on `stop`. env --default-signal restores the default
  # disposition before exec, so the recorder can handle INT itself.
  # shellcheck disable=SC2016 # $$ must be expanded by the child, not here.
  setsid nohup env --default-signal=INT --default-signal=TERM \
    bash -c 'printf %s "$$" > "$1"; shift; exec "$@"' _ "$pid_file" "${cmd[@]}" \
    > "$LOG_FILE" 2>&1 &
  local waited=0
  while [[ ! -s $pid_file ]] && ((waited < 50)); do
    sleep 0.05
    waited=$((waited + 1))
  done
  pid=$(cat -- "$pid_file" 2> /dev/null || true)
  rm -f -- "$pid_file"
  [[ -n $pid ]] || die "could not determine the recorder pid" 1
  state_write "$file" "$pid" "$mode"

  # A recorder that dies immediately (missing encoder, bad geometry) must be
  # reported now, not discovered when the file turns out to be empty.
  sleep 1
  if ! pid_alive "$pid"; then
    state_clear
    local err=''
    [[ -r $LOG_FILE ]] && err=$(tail -n 2 "$LOG_FILE" | tr '\n' ' ')
    die "wf-recorder exited immediately${err:+: $err}" 1
  fi

  notify "recording ${mode#full}${mode:+ }to $file"
  printf 'recording to %s\n' "$file"
}

stop_record() {
  local pid file started elapsed
  pid=$(recording_pid || true)
  [[ -n $pid ]] || die "nothing is recording" 1
  file=$(record_file)
  started=$(state_get started)

  if ((DRY_RUN)); then
    printf '[dry-run] kill -INT %s\n' "$pid"
    return 0
  fi

  kill -INT "$pid" 2> /dev/null || true
  # wf-recorder writes the container trailer on SIGINT. Give it time; never
  # SIGKILL, which would leave an unplayable file.
  local waited=0
  while pid_alive "$pid" && ((waited < 60)); do
    sleep 0.1
    waited=$((waited + 1))
  done
  if pid_alive "$pid"; then
    die "recorder did not stop after 6s (pid $pid); the file may be incomplete" 1
  fi

  state_clear
  # A very short recording can legitimately be a few KiB; an empty file still
  # means wf-recorder never opened the encoder, so check existence, not size.
  [[ -n $file && -e $file ]] || die "recording stopped but no file was written" 1

  if [[ -n $started ]]; then
    elapsed=$(($(date +%s) - started))
    notify "saved ${file##*/} (${elapsed}s)"
    printf 'saved %s (%ss)\n' "$file" "$elapsed"
  else
    notify "saved ${file##*/}"
    printf 'saved %s\n' "$file"
  fi
}

status() {
  local pid file started size elapsed
  pid=$(recording_pid || true)
  if [[ -z $pid ]]; then
    if ((JSON)); then
      printf '{"recording":false}\n'
    else
      printf 'record: idle\n'
    fi
    return 0
  fi
  file=$(record_file)
  started=$(state_get started)
  elapsed=''
  [[ -n $started ]] && elapsed=$(($(date +%s) - started))
  size=0
  [[ -n $file && -r $file ]] && size=$(stat -c %s -- "$file" 2> /dev/null || printf 0)

  if ((JSON)); then
    printf '{"recording":true,"pid":%s,"file":"%s","seconds":%s,"bytes":%s}\n' \
      "$pid" "$file" "${elapsed:-null}" "${size:-0}"
    return 0
  fi
  printf 'record: recording\n'
  printf '  pid      %s\n' "$pid"
  printf '  file     %s\n' "${file:-unknown}"
  printf '  elapsed  %s\n' "${elapsed:+${elapsed}s}"
  printf '  size     %s\n' "$size"
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    --region) REGION=1 ;;
    --audio) AUDIO=1 ;;
    status | start | stop | toggle) ACTION=$1 ;;
    *)
      printf 'record: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

case $ACTION in
  status) status ;;
  start) start_record ;;
  stop) stop_record ;;
  toggle)
    if [[ -n $(recording_pid || true) ]]; then stop_record; else start_record; fi
    ;;
esac
