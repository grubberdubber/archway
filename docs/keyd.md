# keyd — one-hand numpad layer

keyd turns **CapsLock** into a dual-role key: tapped it is Escape, held it is a
numpad under the right hand, so you can type numbers without leaving the home
row. It is kernel-level (evdev), which is why it works in X11, Wayland and the
TTY alike.

Archway ships the configuration as documentation, not as a managed file: it
lives in `/etc/keyd/default.conf`, and Archway never writes to `/etc` without a
package installation. Nothing is enabled by default, because a keyboard remap
can fight an existing one (or a game that reads evdev directly).

## 1. Install

```bash
sudo pacman -S keyd
```

The package is in `extra`; no AUR, no helper needed.

## 2. Configure the layer

Write `/etc/keyd/default.conf` (root owns it, mode 644):

```ini
# CapsLock: tap = Esc, hold = numpad under the right hand.
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

## 3. Enable and reload

```bash
sudo systemctl enable --now keyd    # once
sudo keyd reload                    # after every edit
```

`keyd reload` applies the change without restarting the service; a broken file
leaves the previous mapping in place.

## 4. Test it

1. **TTY** (the honest test, no compositor involved): switch with
   `Ctrl+Alt+F3`, log in, then
   - tap CapsLock → it should behave as Escape;
   - hold CapsLock and press `j k l` → `4 5 6`.
2. **In the session**: the same test in a terminal. Then check that a real
   Escape still works for Neovim (`tap`), and that Ctrl/CapsLock chords you use
   elsewhere still behave.
3. `sudo keyd monitor` prints every key event with the mapping applied — the
   fastest way to see whether a key is being remapped or swallowed.

## 5. Optional navigation layer

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

## 6. Known interactions

- **Games** that read `/dev/input` directly (some anti-cheat, some SDL builds)
  bypass keyd and see the raw key. If a game ignores the layer, that is the
  cause, not Archway.
- **Other remappers** (`kanata`, `interception-tools` + `caps2esc`, `xremap`,
  `kmonad`, `input-remapper`) must not run at the same time; they fight for the
  same devices.
- **Wayland debugging**: `sudo libinput debug-events --show-keycodes` shows what
  the compositor receives after keyd; `wev` shows the final keysym.
- **Laptop firmware keys** (brightness, volume, Fn) are untouched: the layer
  only adds an overload on CapsLock.

## 7. Remove

```bash
sudo systemctl disable --now keyd
sudo rm /etc/keyd/default.conf
```

Typing goes back to the firmware mapping immediately; nothing else was changed.
