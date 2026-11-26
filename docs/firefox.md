# Firefox

Archway themes Firefox through the only mechanism Mozilla supports for it:
`chrome/userChrome.css` plus `user.js` in the profile. Both are rendered from
the active theme palette, so `archway theme set <id>` and a Firefox restart is
the whole update cycle.

```bash
archway applet firefox            # write chrome + prefs (backs up what it replaces)
archway applet firefox --dry-run  # show which files it would touch
archway applet firefox status     # profile, theme, whether the CSS is installed
archway applet firefox --theme ember
archway applet firefox --profile ~/.config/mozilla/firefox/xxxx.default-release
```

The profile is discovered from `installs.ini` (then `profiles.ini`) under
`~/.config/mozilla/firefox` — the XDG layout Firefox 160+ uses — and falls back
to `~/.mozilla/firefox`.

## What the theme does

- Square everything: tabs, address bar, popups, panels. The compositor already
  draws square windows, so rounded chrome inside them looked like a second
  frame.
- Monochrome UI: no gradients, no shadows, no blue accents. Colour is reserved
  for the page; the accent only appears as a 2px underline on the active tab and
  as 1px borders on focus.
- Dense toolbar: compact density, 28px tabs, close button only on hover,
  bookmarks toolbar hidden, no hover previews.
- `userContent.css` styles `about:` pages only. Web content is untouched on
  purpose: recolouring a page you did not design breaks its contrast.

## Palette

Every colour in the stylesheet is a palette token (`@bg@`…`@selection_bg@`),
substituted at render time, so switching themes repaints the browser with no
edits. Beyond the four surface colours it uses:

| Token | Used for |
|---|---|
| `primary` | focus hairline, active tab, selected row bar, progress |
| `selection_bg` | hovered rows, selected suggestions, menu highlight |
| `tertiary` | tab asking for attention |
| `secondary` | private browsing marker |
| `success` / `warning` / `error` | site identity state, infobars, not-secure field, close button hover |
| `overlay` | scrollbar thumb, progress track |

There are no literal hex values in `userChrome.css`; `archway applet firefox`
fails rather than leave an unresolved token behind.

## Selection in the file picker

The picker is GTK3, so its rows are drawn by the GTK theme, not by Firefox. The
stock theme only paints `:selected:focus`, and Ctrl+click builds a selection
while the list is not focused — the files were really selected (they uploaded),
but no row looked selected. `themes/_shared/gtk/gtk.css` now defines
`:selected`, `:selected:backdrop` and the unfocused variants for every view and
adds a 2px accent bar on the left of each selected row.

## Why the file picker pref is pinned

`widget.use-xdg-desktop-portal.file-picker` is set to `0`, which keeps Firefox's
own GTK3 picker instead of the portal one. That is not nostalgia:

1. Since Firefox 149 the portal picker is the default, and it opens as a
   separate top-level window. Tiled by Hyprland it lands in a half-screen tile
   behind the browser — visible, but not focused.
2. An unfocused dialog takes no keyboard shortcuts and no Ctrl+click: every
   selection shortcut appears broken.
3. The portal picker also drops double-click-to-open on several distros
   (Mozilla bug 2026210 and the support forum thread about it).

The in-process GTK3 picker is the dialog this desktop themes (`gtk-3.0/gtk.css`),
floats (`portal-file-chooser` window rule), and focuses like any other window.

`archway applet firefox` writes `user.js`, which Firefox re-applies at every
start, so the pref cannot silently flip back after an update.

### Ctrl+click still does nothing for some uploads

That is the website, not the desktop: a `<input type="file">` without the
`multiple` attribute asks for one file, and GTK disables multi-selection for
that dialog. Verify with a site that accepts multiple files, or for example
`zenity --file-selection --multiple`.

## Reverting

The applet backs up the previous `userChrome.css`, `userContent.css` and
`user.js` to
`~/.local/state/archway/backups/<timestamp>/firefox/`. Copy them back, or delete
`chrome/userChrome.css` and the `toolkit.legacyUserProfileCustomizations`
pref to return to the stock look.
