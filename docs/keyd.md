# keyd — one-hand numpad layer

keyd turns **CapsLock** into a dual-role key: tapped it is Escape, held it is a
numpad under the right hand, so you can type numbers without leaving the home
row. It is kernel-level (evdev), which is why it works in X11, Wayland and the
TTY alike.

Archway owns the whole lifecycle from one applet, so you never hand-edit `/etc`:

| What you want | Command |
|---|---|
| Turn it on | `Super + Alt + N` (toggle) or `archway applet keyd on` |
| Turn it off | `Super + Alt + N` again, or `archway applet keyd off` |
| See the state | `archway applet keyd status [--json]` |
| Write the layer | `archway applet keyd install` (add `--replace` to reset an edit) |
| Apply an edit | `archway applet keyd reload` |
| Stop asking for a password | `archway applet keyd grant` (once, from a terminal) |
| Undo that | `archway applet keyd revoke` |

`on`/`off` only touch the systemd service. Turning it off restores the firmware
mapping immediately and leaves `/etc/keyd/default.conf` alone.

Both need root, and a keybind has no terminal to type a password into. Run
`archway applet keyd grant` once: it installs
`/etc/polkit-1/rules.d/49-archway-keyd.rules`, a rule that lets members of
`wheel` start, stop, restart and reload `keyd.service` — nothing else — without
authentication. After that `Super+Alt+N` just works, with no dialog and no
polkit agent involved.

## Why not SUID, or a passwordless sudo rule

A root-owned binary with the setuid bit is a permanent privilege-escalation
surface: anyone who finds an argument-parsing bug, an inherited `PATH`, or a
writable file it reads gets root, and no amount of care in the applet makes that
go away. The kernel ignores setuid on scripts anyway, so shipping one would need
a compiled helper — more code, more surface, for a keyboard toggle.

A `NOPASSWD` sudoers line is not much better. `sudo` matches on the command
path, so a wrapper that calls `systemctl` becomes a wrapper that can be pointed
at any unit, and the rule says nothing about *who* or *where*.

polkit can express exactly what this needs, which is why the rule is written
that way:

- **one action** — `org.freedesktop.systemd1.manage-units`, nothing else;
- **one unit** — `keyd.service`; a rule for another unit does not match;
- **four verbs** — start, stop, restart, reload; `mask`, `disable`, `link` and
  friends stay behind authentication;
- **one kind of caller** — a local, active session of a `wheel` member, so a
  remote or background context still gets the normal policy.

The rule is a file in `/etc/polkit-1/rules.d/`, readable and removable with
`archway applet keyd revoke`; it grants no shell, no file access and no other
service. If you would rather keep the password prompt, never run `grant` and the
toggle keeps asking.

Without the rule the applet falls back to cached `sudo -n` credentials or
`pkexec`. `pkexec` needs a running agent (`hyprpolkitagent`, which Archway
starts with the session); with none running it fails with
`Error creating textual authentication agent` and the applet exits `3` telling
you to run `grant`.

## 1. Install the package

```bash
sudo pacman -S keyd
```

`keyd` is in `extra` and is part of the desktop manifest, so a normal
`archway install` already provides it. The service is **not** enabled by the
installer: a keyboard remap can fight an existing one (or a game that reads
evdev directly), so it stays off until you ask for it. The installer does not
install the polkit rule either — `archway applet keyd grant` is a deliberate
one-time choice, not something a dotfiles install grants on your behalf.

Why `Super+Alt+N` and not a `Ctrl` chord: a keybind only works once Hyprland
has reloaded it. If the session is running an older config, the chord is
forwarded to the focused window instead — and `Ctrl+K` is readline's kill-line,
so it silently eats the line you were typing in a terminal. `N` is the numpad
mnemonic, and `archway doctor` reports binds that the running session never
loaded (`keybinds.loaded`) so the failure is visible instead of mysterious.

## 2. Turn it on

```bash
archway applet keyd on
```

That is it: the applet writes the packaged layer when
`/etc/keyd/default.conf` does not exist yet, then enables and starts the
service. Root is requested once, through the `grant` rule if installed, `sudo -n`
if the credentials are already cached (a terminal), or `pkexec` otherwise.

An existing `default.conf` that Archway did not write is **not** replaced. The
applet reports it and leaves it in charge, so your own mapping keeps working:

```bash
archway applet keyd status
# keyd: on
#   installed  true
#   active     true
#   enabled    true
#   config     foreign (/etc/keyd/default.conf)
```

To make Archway's layer current again:

```bash
archway applet keyd install --replace   # keeps default.conf.bak.<timestamp>
```

## 3. The layer

`/etc/keyd/default.conf` (packaged at `applets/keyd/default.conf`):

```ini
# Managed by Archway (applet: keyd).
[ids]
*

[main]
capslock = overload(numpad, esc)

[numpad]
u = 7
i = 8
o = 9
j = 4
k = 5
l = 6
m = 1
, = 2
. = 3
n = 0
; = .
p = -
[ = +
y = *
h = /
```

`[ids] *` applies to every keyboard. If you have a laptop with an external
keyboard and want different behaviour, list the devices from
`sudo keyd monitor` instead of `*`.

## 4. Editing and reloading

Change `applets/keyd/default.conf` in the checkout, then:

```bash
archway applet keyd install --replace   # backups, then writes the new layer
archway applet keyd reload              # apply it without a restart
```

`keyd reload` talks to the running daemon, so a syntax error leaves the previous
mapping in place — a broken edit cannot lock you out of your keyboard. If you
prefer to edit `/etc/keyd/default.conf` directly, the same `reload` applies it:
the applet reports the file as `modified` and never overwrites changes it did
not make.

## 5. Test it

1. **TTY** (the honest test, no compositor involved): switch with
   `Ctrl+Alt+F3`, log in, then
   - tap CapsLock → it should behave as Escape;
   - hold CapsLock and press `j k l` → `4 5 6`.
2. **In the session**: the same test in a terminal. Then check that a real
   Escape still works for Neovim (`tap`), and that Ctrl/CapsLock chords you use
   elsewhere still behave.
3. `sudo keyd monitor` prints every key event with the mapping applied — the
   fastest way to see whether a key is being remapped or swallowed.

## 6. Optional navigation layer

The same file can hold a second layer; until you add it, `rightalt` keeps
working as AltGr (needed for `@`, `#`, `{` on many layouts):

```ini
[main]
rightalt = overload(nav, compose)

[nav]
h = left
j = down
k = up
l = right
u = home
i = end
n = pagedown
m = pageup
, = insert
. = delete
```

Note `compose` as the fallback: it keeps the Compose behaviour Archway already
sets in `hyprland.lua` (`kb_options = "compose:ralt"`). Do not map `rightalt` to
`overload(nav, rightalt)`: that removes AltGr and breaks `@` on a US layout.

Add it to the packaged file if you want it in every install (mark it in the
CHANGELOG: it changes the default keyboard for everyone), or keep it local and
let the applet report the config as `modified`.

## 7. Known interactions

- **Games** that read `/dev/input` directly (some anti-cheat, some SDL builds)
  bypass keyd and see the raw key. If a game ignores the layer, that is the
  cause, not Archway. `archway applet keyd off` before launching is the honest
  workaround, and it is one keybind.
- **Other remappers** (`kanata`, `interception-tools` + `caps2esc`, `xremap`,
  `kmonad`, `input-remapper`) must not run at the same time; they fight for the
  same devices.
- **Wayland debugging**: `sudo libinput debug-events --show-keycodes` shows what
  the compositor receives after keyd; `wev` shows the final keysym.
- **Laptop firmware keys** (brightness, volume, Fn) are untouched: the layer
  only adds an overload on CapsLock.
- **A forgotten Escape**: CapsLock is only a numpad *while held*; tapping it is
  always Escape, so a stuck layer is not possible.

## 8. Remove

```bash
archway applet keyd off           # service disabled, typing back to normal
archway applet keyd revoke        # optional: drop the polkit rule
sudo pacman -Rns keyd             # optional: drop the package
sudo rm /etc/keyd/default.conf    # optional: drop the layer file
```

If the shortcut ever stops responding while the layer is on, the terminal is
always the escape hatch: `sudo systemctl disable --now keyd` restores the
firmware mapping with nothing else touched.

Turning it off is enough to get the old keyboard back; removing the package and
the file only cleans up. Nothing else on the system was changed.
