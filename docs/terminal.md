# Terminal workflow helpers

`~/.config/zsh/conf.d/40-workflow.zsh` adds small, dependency-guarded helpers.
They are conveniences, not wrappers that hide the real tool: every one either
prints what it runs or runs a single standard command. Nothing performs
offensive automation, and no helper talks to the network unless its name says
so (`status`, `headers`, `cert`).

| Helper | What it does |
|---|---|
| `croot` | `cd` to the root of the current git repository |
| `fcd` | pick a directory with `fd` + `fzf` and `cd` into it |
| `dns <name>` | A, AAAA and MX records (`dig`, else `resolvectl`) |
| `venv [dir]` | create and activate a project-local Python virtualenv |
| `serve [port] [dir]` | HTTP server on `127.0.0.1`, never on `0.0.0.0` |
| `killport <port>` | kill the process listening on a TCP port (`lsof`, else `fuser`) |
| `fkill` | pick a process with `fzf`, then `SIGTERM` it |
| `status <url>` | HTTP code, total time and size in one line |
| `headers <url>` | response headers, following redirects |
| `cert <host-or-url>` | TLS subject, issuer and validity dates |
| `json [file]` | colourised `jq`, falling back to `python -m json.tool` |
| `sha [files…]` | SHA-256 of files or stdin |
| `b64e` / `b64d` | base64 encode stdin on one line / decode |
| `urlenc` / `urldec` | percent-encode or decode a line (payloads, query strings) |
| `jwt [token]` | decode a JWT header and payload locally; never verifies |
| `now` / `epoch` | ISO-8601 timestamp / unix epoch for notes and logs |
| `extract <archive>` | unpack by extension: tar.{gz,xz,zst,bz2}, zip, 7z, rar, gz, xz, zst |

## Editing mode and keys

`conf.d/05-keymap.zsh` enables **vi mode** by default: Esc, `h/j/k/l`, `w/b/e`,
`u` to undo, `v` to open the current line in `$EDITOR`. The prompt marker is
the double chevron from the reference prompt, recoloured: `❯❯` green while
inserting, yellow in command mode, red after a failure. A literal `>>` was tried
and dropped, because it reads as shell append redirection. The cursor switches
between block and beam on terminals that support it.

The mode lives in the prompt symbol on purpose. An earlier version also painted
a `-- NORMAL --` line in the message area, but repainting it on every Esc/i ate
the output above the prompt when the keys were pressed repeatedly, so it was
removed.

Backspace deletes backwards in both modes. zsh binds it to `vi-backward-char`
in command mode, which only moves the cursor; Archway rebinds `^?` and `^H` to
`backward-delete-char` so Esc, then Backspace, actually erases.

zsh's vi insert mode leaves the usual terminal shortcuts unbound, so Archway
restores them in insert and emacs modes (command mode keeps vim semantics):

| Key | Action |
|---|---|
| Ctrl+A / Ctrl+E | beginning / end of line |
| Ctrl+K | kill to end of line |
| Ctrl+U | kill to beginning of line |
| Ctrl+Y | yank |
| Ctrl+L | clear screen |
| Ctrl+W | delete previous word |

The prompt is flat on purpose: every module paints only a foreground colour,
with no filled segment blocks, so it works over a transparent terminal or a
wallpaper. The working directory is red, the git segment is the nerd-font
branch glyph plus the branch name (`` `main`) and the usual status marks, and
the chevrons follow the last visible segment with a single space instead of a
floating gap.

```sh
keymap            # print the active mode
keymap emacs      # readline-style, remembered for the next session
keymap vi         # back to vi
```

Ctrl+R opens atuin's compact picker with the reference layout: `Search │ Inspect`
tabs, `GLOBAL` filter, duration and relative time per command, and a short
preview of the highlighted entry. Settings live in `~/.config/atuin/config.toml`
(`style`, `inline_height`, `show_tabs`, `show_preview`, `max_preview_height`).

Tab completion opens in an `fzf` pane when `fzf-tab` is installed (AUR
`fzf-tab-git`, already in `packages/aur-core.txt`): type part of a path or
option, press Tab, and filter the candidates with the theme's colours. Without
the plugin, Tab keeps zsh's built-in completion menu.

The arrow keys behave the same in both modes and in both keymaps:

| Key | Action |
|---|---|
| Up / Down | history search by the text already typed |
| Left / Right | move one character |
| Ctrl+Left / Ctrl+Right | move one word |
| Home / End | beginning / end of line |
| Ctrl+R | atuin fuzzy history (falls back to `history-incremental-search-backward`) |

## History and transcripts

History lives in `~/.local/state/zsh/history` for both zsh and atuin. A
`zshaddhistory` hook drops commands that carry credentials (`Authorization:`,
`--password`, `--token`, `export *_TOKEN=`, private-key headers) before they
reach disk; atuin applies the same patterns. This is a safety net, not a
substitute for a password manager.

`rec` starts a timestamped transcript under
`~/.local/state/archway/sessions/` in a nested login shell, and `rec-ls` lists
the recordings. Use it for audits, lab work or a debugging session you may need
to replay.

```sh
rec                 # start; type exit or Ctrl-D to stop
rec-ls              # list recordings
```

## Prompt indicators

Beyond the directory and git state, the prompt shows only context that changes
a decision: the exit code of a failed command, `user@host` for root or SSH, the
container name, the active virtualenv, and the `tun0`/`wg0` address when a lab
VPN is up. Everything else stays out of the way.

## Examples

```sh
# A quick local endpoint while testing an API client
serve 8080 ./public

# Which process owns 3000, and kill it
killport 3000

# Inspect a redirect chain and TLS expiry before trusting an endpoint
headers https://example.com
cert example.com

# Decode a token captured in an authorised assessment
jwt "$TOKEN"

# Check an artefact you downloaded
sha archway-v0.1.0.tar.gz
```

## Security notes

- `serve` binds to loopback; expose it deliberately with a tunnel if you need
  remote access.
- `jwt` only decodes; it does not check signatures, so never treat its output as
  proof that a token is valid.
- These helpers do not install tools. If a dependency is missing, the helper
  says so and exits non-zero instead of failing halfway.
