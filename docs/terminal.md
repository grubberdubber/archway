# Terminal workflow helpers

`~/.config/zsh/conf.d/40-workflow.zsh` adds small, dependency-guarded helpers.
They are conveniences, not wrappers that hide the real tool: every one either
prints what it runs or runs a single standard command. Nothing performs
offensive automation, and no helper talks to the network unless its name says
so (`status`, `headers`, `cert`).

| Helper | What it does |
|---|---|
| `croot` | `cd` to the root of the current git repository |
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
