# SPDX-License-Identifier: GPL-3.0-or-later
# Workflow helpers for programming and authorised security work.
#
# Rules: no network calls unless the command name says so, no automation of
# offensive actions, no hidden state, and every dependency is optional. These
# are conveniences; the real tools stay where they belong.

# cd to the root of the current git repository.
croot() {
  local root
  root=$(git rev-parse --show-toplevel 2> /dev/null) || {
    print -u2 -- "croot: not inside a git repository"
    return 1
  }
  cd -- "$root" || return 1
}

# Serve the current directory over loopback only (never 0.0.0.0 by accident).
serve() {
  local port=${1:-8000} root=${2:-.}
  if (( ! $+commands[python3] )); then
    print -u2 -- "serve: python3 is required"
    return 1
  fi
  print -- "http://127.0.0.1:${port}/ (Ctrl-C to stop)"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root"
}

# Kill whatever listens on a TCP port. lsof is preferred; fuser is the fallback.
killport() {
  local port=${1:?usage: killport <port>} pids=''
  if (( $+commands[lsof] )); then
    pids=$(lsof -ti "tcp:${port}" 2> /dev/null)
  elif (( $+commands[fuser] )); then
    pids=$(fuser -n tcp "$port" 2> /dev/null)
  fi
  if [[ -z ${pids// /} ]]; then
    print -u2 -- "killport: nothing listening on ${port}"
    return 1
  fi
  print -r -- "$pids" | xargs -r kill
}

# Pick a process with fzf and send it SIGTERM.
fkill() {
  if (( ! $+commands[fzf] )); then
    print -u2 -- "fkill: fzf is required"
    return 1
  fi
  local pid
  pid=$(ps -eo pid=,user=,pcpu=,pmem=,comm= --sort=-pcpu |
    fzf --header='pid user cpu% mem% command' | awk '{ print $1 }') || return 1
  [[ -n $pid ]] || return 1
  kill "$pid"
}

# HTTP status, time and size in one line.
status() {
  local url=${1:?usage: status <url>}
  curl -sS -o /dev/null --max-time 20 -w '%{http_code}  %{time_total}s  %{size_download}B  %{url_effective}\n' -- "$url"
}

# Response headers only, following redirects.
headers() {
  local url=${1:?usage: headers <url>}
  curl -fsSIL --max-time 20 -- "$url"
}

# Certificate subject, issuer and validity for an https host.
cert() {
  local host=${1:?usage: cert <host-or-url>}
  host=${host#*://}
  host=${host%%/*}
  host=${host%%:*}
  if (( ! $+commands[openssl] )); then
    print -u2 -- "cert: openssl is required"
    return 1
  fi
  print | timeout 15 openssl s_client -servername "$host" -connect "${host}:443" 2> /dev/null |
    openssl x509 -noout -subject -issuer -dates
}

# Pretty-print JSON from a file or stdin.
json() {
  if (( $+commands[jq] )); then
    jq -C . "${1:--}"
  else
    python3 -m json.tool "${1:--}"
  fi
}

# SHA-256 for files or stdin, with the algorithm named in the output.
sha() {
  if (($#)); then
    sha256sum -- "$@"
  else
    sha256sum
  fi
}

# Base64 from stdin (single line) and back.
b64e() { base64 -w0; print; }
b64d() { base64 -d; }

# Percent-encode / decode a single line, e.g. for payloads and query strings.
urlenc() {
  python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().rstrip("\n"), safe=""))'
}

urldec() {
  python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().rstrip("\n")))'
}

# Decode the header and payload of a JWT without verifying it. Local only.
jwt() {
  local token=${1:-$(</dev/stdin)}
  python3 - "$token" << 'PY'
import base64
import json
import sys

parts = sys.argv[1].strip().split(".")
for name, part in zip(("header", "payload"), parts[:2]):
    part += "=" * (-len(part) % 4)
    print(f"-- {name} --")
    print(json.dumps(json.loads(base64.urlsafe_b64decode(part)), indent=2, ensure_ascii=False))
PY
}

# ISO-8601 timestamp and unix epoch, for logs and notes.
now() { date -Ins; }
epoch() { date +%s; }

# Jump to a directory picked by fuzzy search, without typing the path.
fcd() {
  if (( ! $+commands[fzf] )); then
    print -u2 -- "fcd: fzf is required"
    return 1
  fi
  local dir
  if (( $+commands[fd] )); then
    dir=$(fd --type d --hidden --exclude .git --exclude node_modules | fzf --prompt='dir> ') || return 1
  else
    dir=$(find . -type d -not -path '*/.git/*' | fzf --prompt='dir> ') || return 1
  fi
  cd -- "$dir" || return 1
}

# A/AAAA/MX in one shot, with a resolver fallback.
dns() {
  local name=${1:?usage: dns <name>}
  if (( $+commands[dig] )); then
    print -r -- '-- A --'
    dig +short A -- "$name"
    print -r -- '-- AAAA --'
    dig +short AAAA -- "$name"
    print -r -- '-- MX --'
    dig +short MX -- "$name"
  elif (( $+commands[resolvectl] )); then
    resolvectl query -- "$name"
  else
    getent ahosts -- "$name"
  fi
}

# Create and activate a project-local virtualenv, so test tools stay out of
# the system Python.
venv() {
  local dir=${1:-.venv}
  if (( ! $+commands[python3] )); then
    print -u2 -- "venv: python3 is required"
    return 1
  fi
  [[ -d $dir ]] || python3 -m venv "$dir" || return 1
  source "$dir/bin/activate"
}

# Interactive zoxide jump: pick a directory from the frecency database and cd
# there. `cd` itself already matches with zoxide; this is the picker variant.
zi() {
  if (( ! $+commands[zoxide] )); then
    print -u2 -- "zi: zoxide is required"
    return 1
  fi
  local dir
  dir=$(zoxide query -i) || return 1
  cd -- "$dir" || return 1
}

# Load per-project variables from a .env file without ever printing the values.
# direnv handles .envrc automatically; this is the manual, auditable path.
loadenv() {
  local file=${1:-.env} mode
  if [[ ! -r $file ]]; then
    print -u2 -- "loadenv: cannot read $file"
    return 1
  fi
  mode=$(stat -c '%a' -- "$file" 2> /dev/null)
  if [[ -n $mode ]] && ((8#$mode & 8#077)); then
    print -u2 -- "loadenv: warning: $file is readable by group/others; chmod 600 it"
  fi
  set -a
  source -- "$file"
  set +a
  print -r -- "loaded $file"
}

# Random password from the kernel CSPRNG (openssl), printed on one line.
passgen() {
  local len=${1:-24}
  if (( ! $+commands[openssl] )); then
    print -u2 -- "passgen: openssl is required"
    return 1
  fi
  openssl rand -base64 $(((len * 3 + 3) / 4)) | tr -d '\n' | cut -c 1-"$len"
  print
}

# Extract by extension instead of remembering the tar flags.
extract() {
  local file=${1:?usage: extract <archive>}
  [[ -f $file ]] || { print -u2 -- "extract: not a file: $file"; return 1; }
  case $file in
    *.tar.bz2 | *.tbz2) tar xjf "$file" ;;
    *.tar.gz | *.tgz) tar xzf "$file" ;;
    *.tar.xz | *.txz) tar xJf "$file" ;;
    *.tar.zst) tar --zstd -xf "$file" ;;
    *.tar) tar xf "$file" ;;
    *.zip) unzip -q "$file" ;;
    *.7z) 7z x "$file" ;;
    *.rar) unrar x "$file" ;;
    *.gz) gunzip -k "$file" ;;
    *.xz) unxz -k "$file" ;;
    *.zst) zstd -d "$file" ;;
    *) print -u2 -- "extract: unknown archive type: $file"; return 1 ;;
  esac
}
