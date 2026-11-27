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
