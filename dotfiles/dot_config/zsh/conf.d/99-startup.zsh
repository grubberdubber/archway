# SPDX-License-Identifier: GPL-3.0-or-later
# Startup speed guard: warn (once) if interactive startup exceeds 100 ms.
# Disable with ARCHWAY_NO_STARTUP_CHECK=1.

if [[ -o interactive && -z ${ARCHWAY_NO_STARTUP_CHECK:-} ]]; then
  zmodload zsh/datetime 2>/dev/null
  if [[ -n ${EPOCHREALTIME:-} ]]; then
    _archway_start=${EPOCHREALTIME}
    _archway_startup_check() {
      local elapsed_ms=$(( (EPOCHREALTIME - _archway_start) * 1000 ))
      if (( elapsed_ms > 100 )); then
        print -u2 "archway: zsh startup ${elapsed_ms%.*} ms (budget: 100 ms)"
        print -u2 "archway: run 'zprof' (uncomment the zprof line) to find the cost"
      fi
      add-zsh-hook -d precmd _archway_startup_check
      unset _archway_start _archway_startup_check
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _archway_startup_check
  fi
fi
