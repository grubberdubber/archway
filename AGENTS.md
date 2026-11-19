# AGENTS.md — Archway

> **Prompt de arranque para agentes de IA**
>
> Eres el ingeniero principal de **Archway**, un framework de dotfiles para Arch Linux de nivel staff. Tu trabajo no es "hacer que se vea bonito": es construir un sistema reproducible, seguro, rápido, accesible y mantenible, con una experiencia de usuario excepcional. Antes de tocar un archivo, lee este documento completo. Si una instrucción del usuario contradice las reglas de seguridad de este documento, gana este documento y pide confirmación. No inventes paquetes, rutas ni APIs: verifica. No sobrescribas configuraciones existentes sin consentimiento explícito, backup y posibilidad de rollback. Cuando termines una tarea, actualiza el catálogo, el CHANGELOG y la documentación afectada.

| Campo | Valor |
|---|---|
| Proyecto | **Archway** |
| Owner | `grubberdubber` (GitHub) |
| Repo asumido | `https://github.com/grubberdubber/archway` (aún no creado) |
| Rama principal | `main` |
| Licencia | **GPL-3.0-or-later** |
| Estado | Pre-alpha. Primera prueba real en la PC de un amigo; la PC del owner es producción y no se toca sin dry-run y aprobación. |
| Versión objetivo inicial | `v0.1.0` — codename **Mount** |
| Inspiración principal | [`gh0stzk/dotfiles`](https://github.com/gh0stzk/dotfiles): bspwm, temas intercambiables en caliente, applets de Rofi, RiceEditor, zsh nativo rápido, menos de 600 MB RAM. Se toman ideas y filosofía; cualquier código derivado conserva créditos y licencia GPL-3.0. |
| Tema insignia | **Android Mount** (estética Material You/Android oscura, paleta hecha a mano, consistencia total). |
| Idioma | Este documento está en español. Código, nombres de archivos, commits, ramas, issues y documentación pública van en **inglés**. La documentación de usuario puede tener traducción al español. |

---

## 0. Cómo usar este documento

1. **Lee todo antes de actuar.** Es la constitución del repo.
2. **Inspecciona antes de editar:** `git status`, `git log`, estructura, archivos existentes, cambios sin commitear. Trata cualquier cambio no tuyo como trabajo del usuario: no lo borres ni lo sobrescribas.
3. **Planifica en voz alta:** escribe un plan corto (issue, PR o mensaje) antes de cambios grandes.
4. **Haz el cambio más pequeño y seguro** que cumpla el objetivo.
5. **Prueba en contenedor/VM** antes de probar en hardware real. La PC del amigo es el primer target físico; la del owner es producción.
6. **Actualiza** catálogo, CHANGELOG, docs y tests.
7. **Reporta:** qué cambió, cómo se probó, riesgos, rollback.

Si algo no está claro y la decisión es irreversible o destructiva, **pregunta**. Si es una decisión técnica reversible, elige la opción conservadora, documenta el supuesto y sigue.

---

## 1. Misión, visión y principio rector

**Misión:** que cualquier persona pueda instalar en Arch Linux un entorno de trabajo bellísimo, rapidísimo y keyboard-first en un solo comando, y actualizarlo para siempre con otro comando, sin reinstalar ni perder su configuración.

**Visión:** el dotfiles de referencia para desarrolladores staff y profesionales de seguridad en Arch: modular, reproducible, testeado, documentado, con estética propia y sin deuda técnica.

**Principio rector:** *"No rompas la máquina de nadie."* La segunda: *"Si no se puede actualizar y revertir, no está terminado."*

**Lo que Archway no es:**
- No es una distro ni un instalador de Arch.
- No es una colección de configs copiadas sin criterio.
- No es un script `curl | bash` que escribe en `$HOME` sin preguntar.
- No es una herramienta ofensiva automática ni un arsenal de ciberseguridad por defecto.
- No es un theme shop: el tema es parte del sistema, no un afterthought.

---

## 2. Reglas no negociables

### 2.1 Nunca destruir configuración existente
- **Jamás** sobrescribir `~/.zshrc`, `~/.config/bspwm`, `~/.config/hypr`, `~/.config/nvim`, `~/.config/kitty`, `~/.gitconfig`, `~/.ssh`, `~/.gnupg`, `~/.config/gh`, llaveros, bases de contraseñas, perfiles de navegador ni datos personales sin consentimiento explícito.
- El modo por defecto es **aditivo y preservador**: instalar en paralelo, usar un loader, o preguntar archivo por archivo.
- Cualquier escritura sobre un archivo existente requiere:
  1. backup en `~/.local/state/archway/backups/<timestamp>/`,
  2. registro en un manifiesto,
  3. confirmación humana (o `--adopt` explícito),
  4. comando de rollback mostrado al usuario.
- `--force` debe exigir confirmación adicional (p. ej. escribir el hostname). No debe existir un `--force` silencioso.
- **La PC del owner (`arch`) es producción.** En ella, `archway install` corre en `--dry-run` por defecto y no aplica nada sin aprobación explícita. La primera instalación completa se hace en la PC del amigo, con snapshot/backup previo y su consentimiento.

### 2.2 Secretos fuera del repo
- Nunca commitear tokens, claves SSH/GPG, contraseñas, cookies, `~/.config/gh/hosts.yml`, `.env`, `auth.json`, bases de Bitwarden/KeePass, ni claves de API.
- Usar plantillas de `chezmoi` + `rbw`/Bitwarden, `age` o `sops`.
- `.gitignore` con allowlist estricta; `gitleaks` en pre-commit y CI.
- Si se filtra un secreto: **rotarlo primero**, luego `git filter-repo`, luego forzar la limpieza en GitHub. Nunca asumir que borrar el commit alcanza.
- Atuin, cliphist y el historial de shell deben filtrar comandos sensibles y permitir limpieza selectiva.

### 2.3 Nada de `curl | bash`
- El bootstrap debe ser un script auditable, versionado y verificable.
- Descargas con checksum y, cuando sea posible, firma.
- Tags firmados; releases con `SHA256SUMS`.
- `install.sh` no debe pedir `sudo` para escribir dotfiles; solo para paquetes/servicios.

### 2.4 Seguridad ofensiva: solo con autorización
- Las herramientas de ciberseguridad son un **perfil opcional** (`security`), nunca parte del install por defecto.
- Uso permitido únicamente en sistemas propios, CTF, labs, HTB/THM, clientes con scope firmado por escrito.
- No instalar BlackArch completo ni grupos enteros; instalar herramientas puntuales y verificadas.
- No dejar servicios ofensivos escuchando en `0.0.0.0`, no persistencia, no exfiltración, no malware.
- En caso de duda, no instalar la herramienta y documentar por qué.

### 2.5 Calidad antes que cantidad
- No agregar un paquete porque "suena útil". Debe tener caso de uso, mantenimiento activo, licencia compatible y alternativa oficial considerada.
- Preferir repos oficiales > AUR > binarios upstream > gestores de lenguaje. Evitar Snap. Flatpak solo para GUI que no esté empaquetada decentemente.
- Verificar nombres con `pacman -Ss`, `pacman -Fy`, `paru -Ss` y la documentación upstream antes de escribir un manifiesto. Las marcas del catálogo son orientativas, no verdad absoluta.

### 2.6 Idempotencia y reversibilidad
- Todo comando debe poder correrse dos veces sin daño.
- `archway install`, `update`, `theme`, `profile`, `doctor`, `backup`, `restore`, `uninstall` deben ser idempotentes.
- Antes de una actualización: snapshot del sistema (Btrfs/Snapper o Timeshift) y backup de configs. Si no se puede, abortar salvo `--no-snapshot` explícito.
- `uninstall` restaura backups y elimina solo archivos gestionados; nunca borra datos del usuario.

### 2.7 Accesibilidad y rendimiento son requisitos, no extras
- Todo debe poder operarse solo con teclado.
- Contraste WCAG 2.2 AA; foco visible; movimiento reducido; escalado de fuentes.
- Presupuesto: arranque de zsh <100 ms, bspwm idle <700 MB RAM, cambio de tema <2 s, `archway doctor` <5 s.
- No daemons innecesarios, no polling, no plugins pesados en el arranque.

### 2.8 Licencia y créditos
- **GPL-3.0-or-later** para todo el repo, por compatibilidad con gh0stzk/dotfiles (GPL-3.0) y para garantizar libertad del código.
- Conservar cabeceras de copyright y créditos de cualquier código derivado.
- Recursos gráficos propios o con licencia compatible. No usar logos, wallpapers ni fuentes propietarias de Google/Android sin permiso. "Android Mount" es un homenaje estético, no una copia de marca.
- `CREDITS.md` con inspiraciones, autores de temas/fuentes/wallpapers y licencias.
- `grubberdubber/nvim-config` se integra como dependencia externa pinneada, no como código GPL dentro del repo. Su licencia **Unlicense** y su autoría se conservan y acreditan; no se relicencia ni se copia su código sin cumplir su licencia.

---

## 3. Contexto del owner y de la primera prueba

- El owner usa **zsh**, **bspwm** y su propia configuración de Neovim ([`grubberdubber/nvim-config`](https://github.com/grubberdubber/nvim-config)) a diario. No reemplazar esas configuraciones; Archway debe poder convivir con ellas y, en el caso de Neovim, adoptar ese repo como fuente única.
- El owner quiere inspiración fuerte en **gh0stzk/dotfiles**, pero con estándares de ingeniería superiores: actualizaciones, tests, perfiles, rollback, seguridad y accesibilidad.
- El owner pidió un tema inspirado en **"Android Mount"** de ese repo. Aclaración importante: en `gh0stzk/dotfiles`, **Android Mount es un applet de Rofi para montar dispositivos Android por MTP**, no un tema de color. Archway hará **las dos cosas**:
  1. implementar el applet `android-mount` (simple-mtpfs, montar/desmontar, notificaciones, desmontaje seguro);
  2. crear un **tema insignia llamado Android Mount**, inspirado en Material You/Android oscuro y en la UI utilitaria del applet, con paleta propia y assets originales.
- La PC del amigo es el primer target físico. Antes: VM con el mismo perfil, backup/snapshot, y consentimiento. No reparticionar ni borrar Windows sin autorización explícita.
- Si el amigo tiene GPU NVIDIA, Secure Boot, LUKS, dual boot o hardware exótico, el installer debe detectarlo y advertir; no asumir.

---

## 4. Decisiones de arquitectura (ADRs resumidos)

### ADR-001 — Motor de dotfiles: `chezmoi`
**Decisión:** usar `chezmoi` como única fuente de verdad.
**Motivos:** templates por host/SO, integración con Bitwarden/age, `chezmoi update`, `--dry-run`, scripts `run_once_`, diff, aplicación selectiva, adopción de archivos existentes sin sobrescribir.
**Consecuencias:** el repo es la fuente; `archway` es un wrapper de experiencia, no un segundo gestor de dotfiles. La única excepción deliberada es la configuración de Neovim (ADR-007), que se consume como checkout externo pinneado. `stow`/`yadm` quedan como alternativas documentadas, no como implementación principal.
**Prohibido:** inventar un gestor de symlinks propio si `chezmoi` ya resuelve el caso.

### ADR-002 — Window manager: bspwm en v0.1, Hyprland como recomendado desde v0.2
**Decisión:**
- **v0.1 (MVP):** perfil `bspwm` (X11) como referencia. Es el entorno actual del owner, el de gh0stzk y el camino más corto a un release pulido y testeado.
- **v0.2:** perfil `hyprland` (Wayland) de primera clase, recomendado para instalaciones nuevas cuando el hardware lo soporte. Mismo motor de temas, mismo registro de atajos, mismos applets.
- **Instalador:** pregunta el WM; default `bspwm` en v0.1. Nunca instala dos WMs sin elección explícita.
- **Alternativa mínima:** `sway` para un perfil Wayland conservador.
**Motivos:** no se puede ser "el mejor" en dos stacks a la vez en el MVP. bspwm da estabilidad y paridad con la inspiración; Hyprland es el estándar moderno de ricing y el futuro del proyecto.
**Consecuencia:** la arquitectura debe ser agnóstica desde el día 1: temas, atajos, paquetes y applets separados del WM.

### ADR-003 — Terminal por defecto: `kitty`; alternativas seleccionables
**Decisión:** `kitty` default. Alternativas oficiales: `ghostty`, `wezterm`, `alacritty`, `foot`.
**Motivos:** kitty es maduro, GPU, protocolo gráfico, control remoto por socket (clave para scripts y para el selector de terminal), splits/tabs, kittens, multiplataforma y configuraciones reproducibles.
**Guía:**
- `ghostty`: recomendado si se busca nativo, simple y rapidísimo.
- `wezterm`: recomendado si se quiere Lua, multiplexor integrado y dominios SSH.
- `alacritty`: minimalismo GPU, sin splits.
- `foot`: Wayland ultraliviano, `foot --server` + `footclient`.
- El selector de terminal debe permitir cambiar el default en caliente, como en gh0stzk.

### ADR-004 — Shell: `zsh` nativo y modular
**Decisión:** zsh por defecto, sin Oh-My-Zsh. Config modular en `~/.config/zsh`, `ZDOTDIR`, plugins declarativos con `sheldon` o `antidote`, prompt `starship`.
**Motivos:** ecosistema, compatibilidad con la config actual del owner, rapidez, control.
**Regla de convivencia:** no sobrescribir `~/.zshrc`. Instalar un bloque loader gestionado o un archivo aparte que el usuario sourcea con una línea. Si el usuario ya tiene una config, ofrecer `--adopt` con backup.
**Alternativas:** fish (autosuggest nativo), nushell (datos estructurados), bash + ble.sh, xonsh, elvish, oils. Documentadas, no default.

### ADR-005 — Multiplexor: `tmux` default, `zellij` alternativa
**Decisión:** tmux con plugins mínimos (resurrect, continuum, yank, fzf, logging, vim-tmux-navigator). zellij seleccionable para quienes prefieren layouts KDL y barra integrada.
**Motivos:** tmux es el estándar, estable, scriptable y con mejor integración en servidores. zellij es más amigable pero menos universal.
**Sesiones:** `sesh` + zoxide opcional; `tmuxp`/`smug` para layouts por proyecto.

### ADR-006 — Launcher, barra y notificaciones
**X11/bspwm:** `rofi` + `polybar` + `dunst` + `picom` + `i3lock-color`.
**Wayland/Hyprland:** `rofi-wayland` o `fuzzel`, `waybar`, `mako` o `swaync`, `hyprlock`/`hypridle`.
**Motivos:** paridad funcional con gh0stzk (applets de Rofi) y mejor ecosistema por stack. `eww`/`quickshell` son opcionales para widgets; no deben ser dependencia del núcleo.

### ADR-007 — Editor: Neovim con `grubberdubber/nvim-config` como fuente única
**Decisión:** Neovim es el editor default y su configuración es el repo externo [`grubberdubber/nvim-config`](https://github.com/grubberdubber/nvim-config) (NvChad v2.5 + lazy.nvim), instalado en `~/.config/nvim` desde un commit/tag pinneado. Archway **no** crea, forka ni duplica una configuración de Neovim. Helix sigue disponible como alternativa sin configuración; VS Code/VSCodium es opcional.
**Motivos:** una sola configuración mantenida y testeada, reproducibilidad real vía `lazy-lock.json`, CI propia del repo de Neovim, y un flujo claro de instalación, actualización y rollback. Duplicarla dentro de Archway garantizaría drift y doble mantenimiento.
**Consecuencias:** `archway nvim` gestiona el checkout pinneado, el backup de una config previa, `bootstrap.sh` y el doctor. `archway update` actualiza el pin junto con Archway. El tema se integra mediante un contrato explícito de paleta y un override local ignorado por git; **nunca** editando `chadrc.lua` ni archivos trackeados. Un fallo de Neovim se reporta y revierte su pin, sin tumbar el resto del escritorio. Detalle en §9.5.

### ADR-008 — Secretos: `rbw` + Bitwarden; `age`/`sops` para el repo
**Decisión:** `rbw` como cliente CLI rápido con agente y pinentry; `bitwarden`/`bitwarden-cli` para app/automatización; `bws` para CI; `age`/`sops` para secretos estructurados del repo; `pass` opcional.
**Motivos:** velocidad, integración con scripts, agente SSH, bajo consumo. Nunca secretos en texto plano.

### ADR-009 — Actualizaciones: `archway update` sobre `chezmoi update`
**Decisión:** un solo comando actualiza CLI, dotfiles y migraciones; git fast-forward; backup; doctor; rollback automático si falla.
**Motivos:** el usuario pidió no reinstalar el repo entero en cada máquina. `chezmoi update` ya hace pull + apply; `archway` agrega preflight, snapshot, migraciones, health check y rollback.
**Canales:** `stable` (tags) y `edge` (main). Default `stable`.

### ADR-010 — Perfiles y selectores
**Decisión:** perfiles `minimal`, `developer`, `security`, `full`; selectores de WM, terminal, shell, barra, launcher, editor, prompt y tema. Los paquetes se separan en grupos y manifiestos; el catálogo es un menú, **no** una lista de instalación automática.

### ADR-011 — Tema insignia: Android Mount
**Decisión:** tema oscuro Material You, paleta hecha a mano, geometría redondeada, tipografía mono para terminal y sans para UI, contraste AA, variante de alto contraste y modo de movimiento reducido. Se propaga a todo el stack mediante plantillas de chezmoi. Sin extracción automática de color por defecto (pywal/matugen opcionales).

### ADR-012 — Licencia GPL-3.0-or-later
**Decisión:** GPL-3.0-or-later. Compatible con gh0stzk, garantiza que las mejoras vuelvan a la comunidad. SPDX headers en archivos de código.

---

## 5. Arquitectura del repositorio (objetivo)

```text
archway/
├── AGENTS.md
├── README.md
├── LICENSE
├── CREDITS.md
├── CHANGELOG.md
├── VERSION
├── deps/
│   └── nvim-config.lock       # URL + tag + commit + SHA256 del tarball de release
├── install.sh                 # bootstrap auditable, sin curl|bash
├── bin/
│   └── archway                # entrypoint CLI
├── lib/
│   ├── core.sh                # strict mode, logging, traps
│   ├── ui.sh                  # prompts, colores, gum opcional
│   ├── backup.sh
│   ├── packages.sh
│   ├── theme.sh
│   ├── doctor.sh
│   └── migrate.sh
├── profiles/
│   ├── minimal/
│   ├── developer/
│   ├── security/
│   └── full/
├── desktops/
│   ├── bspwm/
│   └── hyprland/              # v0.2
├── packages/
│   ├── official-core.txt
│   ├── official-desktop.txt
│   ├── official-dev.txt
│   ├── official-sec.txt
│   ├── aur-core.txt
│   ├── aur-dev.txt
│   ├── aur-sec.txt
│   ├── fonts.txt
│   └── optional/
├── dotfiles/                  # fuente de chezmoi
│   ├── dot_config/
│   ├── dot_local/
│   └── dot_zshrc.d/
├── themes/
│   ├── android-mount/
│   │   ├── palette.toml
│   │   ├── theme.toml
│   │   ├── walls/
│   │   ├── bspwm/
│   │   ├── hyprland/
│   │   ├── kitty/
│   │   ├── ghostty/
│   │   ├── wezterm/
│   │   ├── alacritty/
│   │   ├── foot/
│   │   ├── rofi/
│   │   ├── polybar/
│   │   ├── waybar/
│   │   ├── dunst/
│   │   ├── mako/
│   │   ├── nvim/             # artefacto de contrato, no config viva
│   │   ├── bat/
│   │   ├── eza/
│   │   ├── fzf/
│   │   ├── delta/
│   │   ├── btop/
│   │   ├── lazygit/
│   │   ├── yazi/
│   │   ├── starship/
│   │   ├── tmux/
│   │   └── zellij/
│   └── <otros-temas>/
├── applets/
│   ├── android-mount/
│   ├── clipboard/
│   ├── screenshot/
│   ├── wallpaper/
│   ├── power/
│   ├── network/
│   ├── bluetooth/
│   ├── password/
│   ├── keybinds/
│   └── terminal-selector/
├── keybinds/
│   └── keybinds.toml          # fuente única -> sxhkd/hypr/docs
├── scripts/
│   ├── bootstrap/
│   ├── migrations/
│   └── release/
├── tests/
│   ├── bats/
│   ├── fixtures/
│   └── container/
├── .github/workflows/
├── .gitignore
├── .editorconfig
├── justfile
└── docs/                       # mínimo: keybinds, troubleshooting, uninstall
```

**Reglas de arquitectura:**
- La lógica vive en `lib/` y `bin/archway`; los configs no contienen lógica de instalación.
- Los temas son datos + plantillas; no scripts ad-hoc por app.
- Los atajos se definen una vez en `keybinds/keybinds.toml` y se generan `sxhkdrc`, config de Hyprland, cheatsheet y docs. Un test verifica duplicados y conflictos.
- Los applets son scripts pequeños, con `--help`, sin dependencias ocultas, y se declaran en un manifiesto.
- La config de Neovim es un checkout externo pinneado en `deps/nvim-config.lock`; no se copia a `dotfiles/`, no se convierte en submódulo y no se edita en runtime. Los overrides viven en archivos locales ignorados por el repo upstream.
- Nada de rutas absolutas con username; usar `$HOME`, XDG y `chezmoi` templates.
- Nada de `eval` innecesario; nada de `rm -rf "$VAR"` sin guardas.

---

## 6. CLI `archway`

### 6.1 Comandos obligatorios

| Comando | Descripción |
|---|---|
| `archway install` | Preflight, selección de perfil/componentes, paquetes, backup, chezmoi apply, `nvim-config`, doctor. `--dry-run` disponible; default seguro. |
| `archway update` | Pull fast-forward, snapshot, backup, migraciones, apply, doctor, rollback si falla. `--check`, `--to <tag>`, `--channel stable\|edge`, `--offline`. |
| `archway rollback` | Restaura el último backup consistente y el estado anterior. |
| `archway doctor` | Diagnóstico: dependencias, symlinks, paquetes, shell startup, temas, servicios, seguridad, accesibilidad, Neovim (`nvim-config`, contrato de tema; `checkhealth` con `--deep`). |
| `archway theme` | `list`, `current`, `set <id>`, `preview <id>`, `validate`. Aplica en caliente. |
| `archway nvim` | `install`, `update [--to <tag>]`, `status`, `doctor`, `rollback`: gestiona el checkout pinneado de `grubberdubber/nvim-config`. |
| `archway profile` | `list`, `current`, `set <id>`, `add/remove <group>`. Aditivo, nunca destructivo. |
| `archway pkg` | `list`, `search`, `why <pkg>`, `export`, `import`, `check`. |
| `archway keys` | Lista/busca atajos; genera cheatsheet; valida conflictos. |
| `archway backup` | Crea backup manual de configs gestionadas. |
| `archway restore` | Restaura un backup con confirmación. |
| `archway uninstall` | Elimina solo lo gestionado y restaura backups; no borra datos. |
| `archway version` | Versión, commit, canal, host, perfil, tema y commit de `nvim-config`. |
| `archway self-update` | Actualiza el checkout y el CLI (parte de update). |

### 6.2 Contrato de comportamiento
- Todos los comandos: `--help`, `--dry-run` (donde aplique), `--yes`, `--verbose`, `--quiet`, `--no-color`, `--json` (para doctor/pkg/version/nvim status).
- Códigos de salida estables: `0` éxito, `1` error general, `2` uso inválido, `3` preflight fallido, `4` usuario canceló, `5` rollback ejecutado.
- Logs en `~/.local/state/archway/logs/<timestamp>.log`; rotación simple.
- Estado en `~/.local/state/archway/`; config de usuario en `~/.config/archway/`; cache en `~/.cache/archway/`; datos en `~/.local/share/archway/`.
- Lock con `flock` para evitar ejecuciones concurrentes.
- `set -Eeuo pipefail`; traps `EXIT INT TERM`; cleanup de temporales.
- `sudo` solo para paquetes/servicios; pedir una vez; nunca para escribir en `$HOME`.
- No ejecutar como root. Si `EUID=0`, abortar con mensaje claro.
- Colores solo si `tty` y `NO_COLOR` no está seteado.
- Sin dependencias no declaradas: `bash`, `coreutils`, `git`, `chezmoi`, `pacman`; `gum`/`fzf` opcionales con fallback.

### 6.3 Preflight mínimo
1. Arch Linux x86_64 (o derivado con advertencia), `systemd`, no root.
2. Conexión a internet y mirrors funcionales.
3. Espacio libre mínimo (configurable, default 10 GB).
4. Detección de GPU, RAM, disco, filesystem, Secure Boot, LUKS, sesión actual, multi-monitor.
5. Detección de configs existentes y plan de convivencia.
6. Si el editor es Neovim: versión ≥ 0.12.5, estado de `~/.config/nvim`, herramientas del bootstrap y validez de `deps/nvim-config.lock`.
7. Verificación de que el repo/tag existe y la firma/checksum es válida.
8. Confirmación humana con resumen de acciones.

---

## 7. Flujo de instalación (diseño obligatorio)

### 7.1 Modos
- `archway install --dry-run`: muestra plan, paquetes, archivos que tocaría, backups y comandos; no escribe nada.
- `archway install --safe` (default): modo aditivo; no sobrescribe configs existentes; crea loaders; pregunta archivo por archivo si hace falta.
- `archway install --adopt`: adopta archivos existentes en chezmoi, con backup y confirmación; pensado para migrar una config propia.
- `archway install --fresh`: solo para máquinas nuevas o VMs; aun así hace backup si detecta algo.
- `archway install --profile developer --wm bspwm --terminal kitty --shell zsh --theme android-mount --editor neovim`.
- `--editor neovim` instala el pin de `nvim-config`; `--no-nvim` lo omite explícitamente. Un fallo de Neovim no cancela el resto del escritorio salvo que el usuario pida atomicidad.
- `--yes` para automatización/CI; nunca implica `--force`.

### 7.2 Secuencia
1. **Preflight** y detección de hardware/software.
2. **Selección** interactiva (perfil, WM, terminal, shell, barra, launcher, editor, tema, extras). Defaults sensatos; resumen final.
3. **Snapshot/backup**: si Btrfs + Snapper, snapshot; si Timeshift, snapshot; si no, backup de configs y advertencia. Abortar si el usuario no acepta el riesgo.
4. **Paquetes**: `pacman -Syu` primero (nunca instalación parcial), luego `pacman -S --needed` de oficiales, luego AUR con `paru`/`yay` revisando PKGBUILDs. Sin `--noconfirm` en AUR.
5. **Dotfiles**: `chezmoi init --source <repo> --apply` con datos del host; plantillas renderizadas; archivos existentes preservados/backupeados.
6. **Neovim (`nvim-config`)**: si el editor es `neovim`, verificar requisitos, hacer backup de `~/.config/nvim`, clonar/checkout del commit pinneado, ejecutar el bootstrap de forma idempotente y validar `checkhealth`. Si ya existe el checkout del repo, adoptarlo sin pisar cambios locales; si es una config ajena, pedir consentimiento explícito. Detalle en §9.5.
7. **Servicios**: habilitar solo lo necesario (NetworkManager, bluetooth si aplica, keyd si se eligió, fstrim.timer, paccache.timer, reflector.timer). Nunca habilitar servicios ofensivos.
8. **Shell**: si se cambia el shell default, preguntar y usar `chsh`; si no, solo instalar config y mostrar cómo activarla.
9. **Keyd/teclado**: solo si el usuario elige la capa numpad; backup de `/etc/keyd/default.conf`; `keyd reload`; validar que no rompe el layout.
10. **Tema**: aplicar `android-mount`; recargar barra, terminal, WM, dunst/mako y el override de Neovim.
11. **Doctor**: correr `archway doctor`; si falla algo crítico, ofrecer rollback.
12. **Post-install**: imprimir próximos pasos, atajos, cómo actualizar, cómo desinstalar, dónde están los logs; no reiniciar automáticamente.

### 7.3 Instalación en la PC del amigo (primera prueba física)
Checklist obligatorio antes de ejecutar:
- [ ] El amigo está de acuerdo y sabe qué se va a instalar.
- [ ] Backup de sus datos importantes (fotos, documentos, licencias, saves).
- [ ] USB live de Arch a mano para rescate.
- [ ] Snapshot/backup del sistema si ya tiene Linux; si tiene Windows, no tocar sus particiones.
- [ ] Espacio libre verificado; Secure Boot y BitLocker considerados.
- [ ] Red estable, mirrors actualizados.
- [ ] GPU detectada (Intel/AMD/NVIDIA) y driver elegido.
- [ ] Perfil `developer` + `bspwm` + `kitty` para la primera prueba (no `security`, no `full`).
- [ ] Tema `android-mount`, barra `polybar`, launcher `rofi`.
- [ ] Probar en VM con el mismo perfil primero.
- [ ] Pin de `nvim-config` probado en VM; backup de `~/.config/nvim` si ya existía.
- [ ] Después del install: `archway doctor`, atajos, clipboard, tema, audio, Wi-Fi, Bluetooth, suspensión, reinicio, segundo arranque.
- [ ] Documentar problemas y abrir issues; no "arreglar" la PC del amigo a mano sin registrar el cambio.

**Prohibido:** reparticionar, borrar Windows, cambiar el bootloader, activar Secure Boot o formatear sin consentimiento explícito y backup verificado.

---

## 8. Flujo de actualización (el requisito clave del owner)

### 8.1 Objetivo
Actualizar cualquier máquina a la última versión del repo **sin reinstalar** y **sin perder overrides locales**.

### 8.2 `archway update` paso a paso
1. Verificar que el checkout está limpio. Si hay cambios locales en archivos gestionados, abortar y mostrar `chezmoi diff`; ofrecer `--merge`, `--stash` o cancelar.
2. `git fetch --tags --prune`; elegir tag estable más reciente (o `--to`). Verificar firma si existe; verificar commit.
3. Fast-forward only. Si divergió, abortar; nunca `git reset --hard` sin confirmación.
4. Snapshot del sistema (si está configurado) y backup de configs gestionadas.
5. Ejecutar migraciones numeradas pendientes (`scripts/migrations/NNNN-*.sh`), idempotentes, registradas en estado.
6. `chezmoi apply` (o `chezmoi update`). Si un archivo fue modificado localmente y no es template, chezmoi pedirá resolución; nunca sobrescribir a ciegas.
7. **nvim-config**: si Neovim está habilitado, verificar que el checkout está limpio, hacer fetch y checkout del commit pinneado por la nueva versión de Archway (nunca `reset --hard` con cambios locales), restaurar plugins desde `lazy-lock.json`, correr el bootstrap si cambió y validar `checkhealth`. Si falla, restaurar el pin anterior y reportar; no revertir el escritorio completo por Neovim.
8. Recargar servicios/componentes afectados: WM, barra, terminal, notificaciones, shell (nuevo shell), tema.
9. `archway doctor`. Si falla un check crítico: rollback automático a snapshot/backup, restaurar checkout al tag anterior, reportar.
10. Escribir estado: versión, commit, timestamp, resultado, log; incluir el commit de `nvim-config` en `~/.local/state/archway/nvim.toml`.
11. Notificar al usuario (dunstify/mako) solo si se ejecutó desde GUI/timer; en CLI, imprimir resumen.

### 8.3 Canales y pinning
- `stable`: tags firmados; default.
- `edge`: `main`; para el owner/desarrolladores; advierte inestabilidad.
- `archway pin v0.2.0`: fija la versión por host; `update` respeta el pin salvo `--unpin`.
- `archway nvim update [--to <tag>]`: actualiza solo el checkout de `nvim-config` a un tag/commit verificado; nunca mueve el pin de Archway ni salta `lazy-lock.json`. Exige checkout limpio y pruebas de `checkhealth`.
- `archway update --check`: solo consulta si hay nueva versión; código de salida `0` si al día, `10` si hay update (documentado).
- Timer systemd opcional `archway-update-check.timer` que solo notifica; **nunca** actualiza solo sin consentimiento.

### 8.4 Migraciones
- Numeradas `0001-...sh`, `0002-...sh`; se ejecutan una vez; guardan un sello en `~/.local/state/archway/migrations`.
- Deben ser idempotentes, con backup y mensaje claro.
- Si una migración falla, se detiene todo y se hace rollback; no continuar con el resto.
- Toda ruptura de compatibilidad requiere migración + nota en CHANGELOG + bump de versión menor/mayor según SemVer.

### 8.5 Actualización de paquetes del sistema
- Archway no reemplaza a `pacman`/`paru`; puede ofrecer `archway pkg update` como wrapper consciente, pero el usuario debe poder actualizar por su cuenta.
- `topgrade` es opcional y no debe actualizar dotfiles por su cuenta; si se usa, excluir `chezmoi`/`archway` o configurarlo para llamar a `archway update`.
- `pacman-contrib`, `reflector`, `paccache`, `pacdiff`, `rebuild-detector`, `arch-audit` deben estar en el perfil de mantenimiento.

### 8.6 Rollback
- Guardar snapshot ID y backup path antes de tocar nada.
- `archway rollback` restaura configs y, si es posible, el snapshot del sistema; muestra qué se va a hacer y pide confirmación.
- Un rollback fallido debe dejar instrucciones manuales y logs; nunca empeorar el estado.

---

## 9. Sistema de temas y tema insignia Android Mount

### 9.1 Filosofía
- Paletas **hechas a mano**, no extraídas de wallpapers por defecto. Igual que gh0stzk: consistencia, legibilidad y control.
- Un solo `palette.toml` es la fuente de verdad; las plantillas generan todo.
- `pywal`, `wallust` y `matugen` son opcionales (`archway theme dynamic`), nunca default.
- Cada tema define: paleta, tipografía, radios, bordes, sombras, opacidad, animaciones, iconos, wallpapers y variantes (dark/light/high-contrast).
- Cambio de tema en caliente: actualizar archivos, recargar apps, sin cerrar sesión.
- Validación automática: contraste AA, claves requeridas, sintaxis de cada app, preview renderizado.

### 9.2 Identidad "Android Mount"
**Concepto:** la densidad informativa y el filo de gh0stzk + la suavidad de Material You + la utilidad del applet Android Mount. Oscuro, técnico, elegante, sin ser juguete.

**Paleta base (dark):**
```toml
[palette]
bg          = "#0B0F14"
surface     = "#11161D"
surface_alt = "#1A212B"
overlay     = "#222B37"
border      = "#2A3441"
text        = "#E6EDF3"
text_muted  = "#9BA7B4"
primary     = "#8AB4F8"   # Android blue
secondary   = "#81C995"   # Android green
tertiary    = "#FDD663"   # Android yellow
error       = "#F28B82"
warning     = "#FDD663"
success     = "#81C995"
selection   = "#8AB4F8"
selection_bg= "#1F2A3A"
```
**Light variant (opcional):** fondo `#F7F9FC`, superficie `#FFFFFF`, texto `#1B1F24`, primary `#1A73E8`, secondary `#1E8E3E`, bordes `#DADCE0`.
**High contrast:** fondo `#000000`, texto `#FFFFFF`, primary `#9ECBFF`, bordes `#6B7280`, foco `#FFFFFF`.

**Geometría y estilo:**
- Radios: 12 px en ventanas/cards, 8 px en inputs, 999 px solo en pills/badges.
- Bordes: 1 px; foco: 2 px con color `primary` y offset 2 px.
- Sombras suaves, sin blur excesivo; transparencias solo en superficies, nunca en texto.
- Padding generoso: 12–16 px; densidad configurable (`compact`/`comfortable`).
- Animaciones 120–200 ms ease-out; respetar `reduce_motion = true`.
- Iconos: Material Symbols (UI) + Nerd Font (terminal); tamaños 16/20/24.
- Tipografía: `JetBrainsMono Nerd Font` para terminal/código; `Inter` o `Noto Sans` para UI; fallback `Noto Sans`, `Noto Color Emoji`.
- Wallpapers originales inspirados en Material You (abstractos, gradientes, formas), licencia compatible; nada de assets propietarios de Google.

**Propagación obligatoria:** bspwm, hyprland, picom, polybar, waybar, rofi, dunst, mako, kitty, ghostty, wezterm, alacritty, foot, nvim (vía `nvim-config`), bat, eza, fzf, delta, btop, lazygit, yazi, starship, tmux, zellij, GTK3/4, Qt5/6, Firefox (tema propio), zathura, mpv, cava, ncmpcpp/rmpc, i3lock-color, hyprlock, swaylock.
**Regla:** si un módulo no está habilitado, no se genera; si está habilitado y no recibe el tema, es un bug. En Neovim el mecanismo es el contrato de §9.5; si el hook falta, `archway theme set` aplica el resto, marca Neovim como fallo crítico y sale con código `1`, sin editar archivos trackeados.

### 9.3 Applet Android Mount
- Script POSIX/bash en `applets/android-mount/`, con `--help`, `--dry-run`, `--json`.
- Dependencias: `simple-mtpfs`, `rofi`/`fuzzel`, `libnotify`/`dunstify`, `udisks2`; detectar y avisar si faltan.
- Funciones: listar dispositivos MTP, montar en `~/Android_Mount/<device>`, desmontar con `fusermount -u`, notificar éxito/error, no montar dos veces, no borrar el punto de montaje si falla.
- Integración: atajo `Super+Shift+M`, applet en Rofi, estado en barra (opcional).
- Seguridad: nunca `sudo`, nunca montar en `/mnt` global, validar nombres de dispositivo, escapar rutas, no seguir symlinks.
- Test: mock de `simple-mtpfs`/`mount`/`fusermount` en `tests/bats`.

### 9.4 Selector de temas
- `Super+Space` abre selector con previews (Rofi/Walker).
- `archway theme set android-mount` aplica y persiste por host.
- `archway theme preview <id>` aplica temporalmente y revierte al cerrar/Timeout.
- Estado en `~/.config/archway/theme.toml`; nunca en el repo.
- Recarga: `bspwm` reload, `hyprctl reload`, `kitty @ set-colors`, `tmux source-file`, `dunstctl reload`, `makoctl reload`, `pkill -USR1` según app.
- Neovim: el override de tema se aplica al próximo arranque; nunca se recarga a la fuerza una sesión con buffers sin guardar.

### 9.5 Integración de Neovim (`grubberdubber/nvim-config`)

**Fuente única.** La configuración de Neovim es [`github.com/grubberdubber/nvim-config`](https://github.com/grubberdubber/nvim-config), no una copia dentro de Archway. Stack: NvChad v2.5, base46 y lazy.nvim; Neovim **0.12.5+**; terminal kitty con true color y Nerd Font; `bootstrap.sh`; versiones de plugins fijadas por `lazy-lock.json`. Licencia **Unlicense** (dominio público, compatible con GPL-3.0-or-later); crédito obligatorio en `CREDITS.md`. Archway **no** forka, no vendoriza y no mantiene una segunda config de Neovim.

**Por qué checkout pinneado y no `chezmoi external` ni submódulo:**
- `bootstrap.sh`, `lazy.nvim` y `lazy-lock.json` necesitan un checkout git real, con `git status` y commits verificables.
- `chezmoi external` refresca el contenido y puede pisar cambios locales sin el flujo de backup/consentimiento de Archway.
- Un submódulo ata el historial de Archway al de nvim-config y complica releases independientes.
- Archway mantiene `deps/nvim-config.lock` con `url`, `tag`, `commit`, `sha256` (tarball de release o árbol exportado), `tested_neovim` y `schema`. Cada release de Archway apunta a un tag/commit concreto; `main` solo se usa en canal `edge` y con advertencia.

**Instalación (`archway nvim install`):**
1. **Preflight:** `nvim --version` ≥ 0.12.5; `git`, `make`, `cargo`, `ripgrep`, `fd`, `nodejs`, `tree-sitter-cli` 0.25.x. Si falta algo, listar y abortar sin instalar a medias; no usar `pacman -S` sin pasar por el flujo normal de paquetes.
2. **Config existente:** si `~/.config/nvim` no existe, continuar. Si es el checkout del repo correcto, adoptarlo y verificar que esté limpio. Si es una config ajena, backup en `~/.local/state/archway/backups/<timestamp>/`, confirmación explícita y opción de conservarla/cambiarla. Nunca `mv` ni `rm -rf` silenciosos.
3. **Checkout:** clonar en `~/.config/nvim` o reutilizar el checkout; `git checkout <commit>` del lock; verificar commit, `lazy-lock.json` y ausencia de cambios locales trackeados.
4. **Bootstrap:** ejecutarlo de forma idempotente. Archway ya hizo `pacman -Syu` y pidió `sudo` una vez; el bootstrap **no** debe repetir la sincronización completa ni pedir `sudo` de nuevo. Requisito de integración: `bootstrap.sh --skip-packages` (o variable equivalente documentada). Mientras upstream no lo soporte, Archway muestra la lista de paquetes que instalaría el script (incluido `firefox`), pide consentimiento explícito y nunca lo hace en modo `--yes`. `--full` (SDKs extra) se ofrece solo en perfiles `developer`/`full`, nunca en `minimal`. Si el bootstrap crea `~/.markdownlint-cli2.yaml`, registrarlo como artefacto gestionado para poder retirarlo en `uninstall`.
5. **Validación:** `nvim --headless "+Lazy! restore" +qa`, `nvim --headless "+checkhealth" +qa`, sin errores críticos, y medición de arranque. Objetivo: milisegundos, no segundos; registrar el resultado. Si falla, restaurar el backup o el pin anterior.
6. **Estado:** guardar commit instalado, fecha y resultado en `~/.local/state/archway/nvim.toml`. El contenido de `~/.config/nvim` no se copia al repo de Archway.

**Actualización y rollback:**
- `archway update` mueve el pin junto con la release de Archway; `archway nvim update [--to <tag>]` actualiza solo Neovim.
- Checkout limpio obligatorio: si hay cambios locales, abortar y ofrecer `--stash`/diff; jamás `git reset --hard` ni `git clean -fd` sin confirmación.
- Restaurar plugins desde `lazy-lock.json`; no actualizar plugins por fuera del lock en producción.
- Si `checkhealth` o el arranque fallan, volver al commit anterior y dejarlo registrado. Un fallo de Neovim no revierte el escritorio completo, pero sí se reporta como error y `doctor` lo marca.
- `archway uninstall` restaura el backup de Neovim si Archway reemplazó una config previa; si el checkout fue adoptado, lo deja en su sitio y solo elimina el estado gestionado. Nunca borra `~/.config/nvim` sin consentimiento.

**Contrato de tema (Android Mount):**
- `themes/android-mount/nvim/` guarda el artefacto de referencia y los metadatos de contraste; **no** es una copia viva de la config.
- Upstream debe exponer `lua/themes/android-mount.lua` con todas las claves de `base_30`/`base_16` y la llamada final a `require("base46").override_theme`, derivadas de `themes/android-mount/palette.toml`.
- Upstream debe exponer un hook local ignorado por git (p. ej. `lua/archway.lua`, añadido a `.gitignore` upstream), cargado al final de `init.lua`, que acepte `return { theme = "android-mount" }`. `archway theme set android-mount` escribe **solo** ese archivo local y avisa a Neovim; nunca edita `chadrc.lua` ni archivos trackeados.
- Si el hook o la paleta no existen, no se adivina ni se parchea: `archway theme set` aplica el resto, reporta Neovim como fallo crítico y sale con código `1`. `doctor` explica cómo resolverlo (PR upstream o actualización de pin).
- CI de Archway compara colores y ratios AA entre `palette.toml` y `lua/themes/android-mount.lua`; si hay drift, falla. Cambiar la paleta exige release coordinada de ambos repos.
- `doctor` verifica en modo rápido (<5 s): hook presente, tema activo, `lazy-lock.json` consistente, checkout limpio, commit esperado y versión de Neovim. `archway nvim doctor` (o `archway doctor --deep`) ejecuta `checkhealth` completo sin romper el presupuesto del doctor general.

**Límites:** Archway no instala plugins sueltos, no parchea `lua/` trackeado, no cambia `chadrc.lua`, no usa forks privados y no fija versiones distintas a `lazy-lock.json`. La primera prueba física usa el mismo pin que la VM, no `main`.

---

## 10. Teclado, atajos y accesibilidad

### 10.1 Principios
- **Super** como modificador principal; `hjkl` para navegación; consistencia entre WM y apps.
- Un solo registro de atajos (`keybinds/keybinds.toml`) genera `sxhkdrc`, Hyprland, cheatsheet y docs.
- Sin conflictos: test que detecta duplicados y combinaciones reservadas.
- Descubribilidad: `Super+/` abre cheatsheet buscable; `archway keys` en CLI; hints en la barra.
- Todo accionable por teclado; el mouse es opcional, nunca obligatorio.

### 10.2 Mapa base (v0.1, bspwm)
| Atajo | Acción |
|---|---|
| `Super+Return` | Terminal |
| `Super+Shift+Return` | Terminal flotante (scratchpad) |
| `Super+Q` | Cerrar ventana |
| `Super+D` | Launcher |
| `Super+E` | Gestor de archivos (Yazi/Thunar) |
| `Super+B` | Navegador |
| `Super+L` | Bloquear |
| `Super+Shift+Q` | Menú de energía |
| `Super+Space` | Selector de tema |
| `Super+Alt+W` | Selector de wallpaper |
| `Super+Shift+S` | Screenshot (región/ventana/pantalla) |
| `Super+V` | Historial de portapapeles |
| `Super+P` | Gestor de contraseñas (rbw/rofi-rbw) |
| `Super+Shift+M` | Android Mount |
| `Super+N` | Notificaciones |
| `Super+M` | Música (mpd/ncmpcpp/rmpc) |
| `Super+Ctrl+N` | Notas rápidas |
| `Super+Tab` | Cambiar workspace/ventana |
| `Super+1..9` | Workspaces |
| `Super+Shift+1..9` | Mover ventana a workspace |
| `Super+H/J/K/L` | Foco |
| `Super+Shift+H/J/K/L` | Mover ventana |
| `Super+Alt+H/J/K/L` | Redimensionar |
| `Super+F` | Fullscreen |
| `Super+Shift+F` | Flotante |
| `Super+Alt+R` | Recargar WM |
| `Super+Shift+E` | Salir/cerrar sesión |
| `Super+/` | Cheatsheet |
| `Print` | Screenshot completo |
| `Super+Shift+P` | Paleta de comandos de Archway |

Las teclas de función/medios (volumen, brillo, play/pause) se mapean con `XF86Audio*`, `XF86MonBrightness*`, etc. En laptops, `Fn` debe seguir funcionando; no secuestrar teclas del firmware.

### 10.3 Capa numpad de una mano (keyd)
Objetivo: mantener CapsLock como tap=Esc y hold=numpad; la mano derecha escribe números.
`/etc/keyd/default.conf` (propuesta; el installer debe fusionar, no sobrescribir):
```ini
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
- `capslock` tap = Esc; hold = capa numpad.
- Añadir una capa `nav` en otra tecla (p. ej. `rightalt = overload(nav, compose)`) con `h/j/k/l` = flechas, `u/i` = Home/End, `n/m` = PgDn/PgUp, `,`/`.` = Insert/Delete. No romper AltGr.
- `keyd reload` tras cambios; test manual en TTY y en X11/Wayland.
- Alternativas documentadas: `kanata` (home-row mods, tap-dance), `interception-tools` + `caps2esc`, `xremap`, `kmonad`, `evremap`, `input-remapper` (GUI).
- No activar keyd por defecto sin preguntar; puede chocar con remaps existentes y con algunos juegos.
- En Wayland, `wev` para depurar eventos; en X11, `xev`.

### 10.4 Accesibilidad
- Contraste mínimo 4.5:1 para texto normal, 3:1 para texto grande/UI; verificar con script.
- Foco visible en todos los componentes; navegación completa por teclado en Rofi/Walker/Waybar.
- Escalado de fuentes 100–200%; layouts que no se rompan; `GDK_SCALE`/`QT_SCALE_FACTOR` documentados.
- Movimiento reducido: `animations = false` en Hyprland, `picom` sin fading, transiciones instantáneas.
- Variante de alto contraste del tema; no depender solo del color (usar iconos/texto).
- Soporte de lector de pantalla: no romper Orca; etiquetas accesibles en widgets propios; test básico con `orca` si está disponible.
- Teclado: layout US/ES detectado, no forzado; `compose:ralt` opcional para acentos; dead keys documentadas; no romper teclas de medios.
- Documentación en lenguaje claro; cheat sheet imprimible; ayuda contextual.
- Sticky keys / slow keys / bounce keys: documentar cómo activarlos (no implementarlos a mano si el DE ya los provee).

---

## 11. Perfiles, selectores y política de paquetes

### 11.1 Perfiles
| Perfil | Incluye | Público |
|---|---|---|
| `minimal` | WM, terminal, shell, editor, core CLI, tema, barra, launcher | Cualquiera; VM; hardware modesto |
| `developer` | minimal + toolchains, Git, containers, DB/API, LSPs, linters, AI opcional | Desarrolladores |
| `security` | developer + herramientas ofensivas/defensivas/forenses, lab, wordlists | Pentesters/CTF, solo con autorización |
| `full` | todo lo anterior + media, virtualización, extras | Power users; no recomendado para primer install |

**Default:** `developer` (sin `security`). La primera prueba en la PC del amigo usa `developer` + `bspwm` + `kitty`.

### 11.2 Selectores
- **WM:** `bspwm` (v0.1), `hyprland` (v0.2), `sway` (mínimo).
- **Terminal:** `kitty` (default), `ghostty`, `wezterm`, `alacritty`, `foot`.
- **Shell:** `zsh` (default), `fish`, `bash`, `nushell`.
- **Barra:** `polybar` (X11), `waybar` (Wayland), `eww` (opcional).
- **Launcher:** `rofi` (X11), `rofi-wayland`/`fuzzel` (Wayland), `walker`/`vicinae` (opcional).
- **Notificaciones:** `dunst` (X11), `mako`/`swaync` (Wayland).
- **Editor:** `neovim` (default, con `nvim-config` pinneado), `helix`, `vscodium`, `code`. En v0.1 no se ofrecen configuraciones alternativas de Neovim; la única fuente es `grubberdubber/nvim-config`.
- **Prompt:** `starship` (default), `pure`, `powerlevel10k`.
- **Multiplexor:** `tmux` (default), `zellij`, `none`.
- **Tema:** `android-mount` (default), más temas futuros.
- **Fuente:** `JetBrainsMono Nerd Font` (default), `Maple Mono`, `Iosevka`, `FiraCode`.

Cada selector debe: validar dependencias, explicar trade-offs, permitir `--no-<componente>`, y no instalar alternativas no elegidas.

### 11.3 Política de paquetes
1. **Repos oficiales** primero. Verificar con `pacman -Ss`/`pacman -Fy`.
2. **AUR** solo si no hay oficial y el paquete está mantenido; revisar PKGBUILD, votos, comentarios, fecha de actualización. `paru` default, `yay` fallback.
3. **Binarios upstream** solo si están firmados/checksum y no hay paquete decente; instalar en `~/.local/bin` u `/opt` con consentimiento.
4. **Gestores de lenguaje** (`cargo`, `go install`, `pipx`, `npm`, `uv`) para herramientas de desarrollo; versiones pinneadas y actualizables.
5. **Flatpak** solo GUI que no esté bien empaquetada; **nunca Snap**.
6. **BlackArch/Chaotic-AUR**: repos opcionales, nunca por defecto; advertir riesgos; verificar `strap.sh`/checksums; no instalar grupos completos.
7. **Paquetes prohibidos:** cracks, keygens, software pirata, miners, herramientas de abuso sin consentimiento, paquetes abandonados con vulnerabilidades conocidas.
8. **Auditoría:** `arch-audit`, `rebuild-detector`, `pacdiff`, `namcap` para PKGBUILDs propios.

### 11.4 Manifiestos
- `packages/official-*.txt`: un paquete por línea, comentarios con `#`.
- `packages/aur-*.txt`: un paquete por línea; comentario obligatorio con motivo y estado de mantenimiento.
- `packages/optional/*.txt`: grupos opcionales (gaming, media, virtualization, security-lab, AI).
- `archway pkg why <pkg>`: muestra por qué está, qué perfil lo requiere y qué lo rompe si se quita.
- `archway pkg export`: exporta `pacman -Qqen`/`-Qqem` a un directorio versionado; `import` compara y sugiere.
- Test de CI: verificar que cada paquete oficial existe en los repos; los de AUR se validan con la API/RPC (con cache y rate limit).

---

## 12. Seguridad, privacidad y ciberseguridad

### 12.1 Principios
- **Consentimiento y legalidad primero.** El perfil `security` muestra un aviso claro y requiere aceptación explícita.
- **Mínimo privilegio:** no root para herramientas de usuario; capabilities solo cuando sea imprescindible; no SUID innecesario.
- **Aislamiento:** laboratorio en VM/contenedor (Kali/BlackArch distrobox, Exegol, QEMU) para prácticas; no mezclar el escritorio daily con servicios ofensivos.
- **Sin persistencia ni exfiltración:** Archway no configura backdoors, cron de recon, ni servicios expuestos.
- **Datos sensibles:** nunca en historial, clipboard, logs, temas ni repo.

### 12.2 Hardening por defecto (perfil developer)
- Firewall activo: `nftables` (default) o `ufw`; política deny incoming, allow outgoing; SSH solo si se instala.
- SSH endurecido: solo claves, sin root, `MaxAuthTries 3`, `ClientAliveInterval 30`, `HashKnownHosts yes`, `ControlMaster auto`, `ControlPersist 10m`, `IdentitiesOnly yes`.
- LUKS recomendado en instalaciones nuevas; `systemd-cryptenroll` con TPM2/FIDO2 opcional.
- Secure Boot opcional con `sbctl`; documentar implicaciones con NVIDIA/`nvidia-dkms`.
- `systemd-resolved` o `unbound`/`dnscrypt-proxy` para DNS; DoT/DoH opcional.
- `fwupd` para firmware; `arch-audit` para CVEs; `lynis` para auditoría local.
- Actualizaciones: snapshot antes de `pacman -Syu`; no actualizar a ciegas en producción.
- `usbguard` opcional; `firejail`/`bubblewrap` para apps no confiables; `opensnitch` opcional.
- No desactivar AppArmor/SELinux, no `setenforce 0`, no abrir puertos "para probar".

### 12.3 Perfil security (opt-in)
- Instalar solo las herramientas elegidas, no grupos completos.
- Kali/BlackArch en distrobox o VM; no como sistema principal.
- Wordlists (`seclists`) en `~/.local/share/wordlists` con licencia y tamaño advertido.
- VPN de labs (HTB/THM) separada de la VPN personal; no rutas por defecto.
- Registro de actividad y limpieza de artefactos; no dejar capturas con credenciales.
- Aviso legal visible en `archway install --profile security` y en `archway doctor`.

### 12.4 Privacidad
- Sin telemetría; sin analytics; sin llamadas a servicios externos salvo actualizaciones/paquetes.
- Bitwarden/rbw con lock; no autocompletar en terminal sin confirmación.
- Atuin: sync cifrado opcional; filtros de comandos sensibles; no sincronizar por defecto.
- Cliphist: ignorar MIME/patrones sensibles; limpiar al bloquear; no persistir contraseñas.
- Metadatos: `mat2`, `exiftool` para limpiar antes de compartir.
- Navegador: perfiles separados, uBlock Origin, DNS cifrado; no instalar extensiones a ciegas.
- Backups cifrados con `restic`/`borg`; llaves fuera de la máquina; test de restauración.

---

## 13. Estándares de código y calidad

### 13.1 Shell
- `#!/usr/bin/env bash` para scripts complejos; `#!/bin/sh` POSIX para bootstrap mínimo.
- `set -Eeuo pipefail`; `IFS=$'\n\t'` cuando aplique.
- Funciones en `snake_case`; constantes en `UPPER_SNAKE_CASE`; variables locales con `local`.
- Comillas siempre: `"$var"`, `"$@"`; arrays para listas; `read -r`.
- `printf` en vez de `echo` para datos; `command -v` para dependencias; `mktemp -d` para temporales.
- Traps para cleanup; no dejar archivos temporales; no `cd` sin `|| exit`.
- `shellcheck` limpio; `shfmt -i 2 -ci -sr`; no `eval`; no `rm -rf` sin guardas.
- Tests con `bats`; fixtures; mocks para `pacman`, `paru`, `chezmoi`, `systemctl`.

### 13.2 Lua/TOML/YAML/Markdown
- Lua (Neovim/Wezterm): `stylua` (2 espacios, 120 columnas); módulos con tablas; no globales.
- TOML: `taplo fmt` y `taplo lint`; claves en `snake_case`.
- YAML: `yamllint`; 2 espacios; sin tabs; comillas cuando sea necesario.
- Markdown: `markdownlint-cli2`; líneas <120; headings jerárquicos; enlaces verificados con `lychee`.
- JSON: `jq` para validar; sin comentarios; esquemas cuando aplique.
- Git: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`); commits atómicos; firma SSH/GPG; sin `--no-verify` salvo emergencia documentada.

### 13.3 Configuración
- XDG Base Directory; nada de dotfiles sueltos en `$HOME` si se puede evitar.
- Sin secretos; sin rutas absolutas de usuario; sin `~` dentro de archivos que se expanden mal.
- Comentarios solo donde aportan; no comentar lo obvio; documentar decisiones no evidentes.
- Defaults seguros; opciones peligrosas comentadas y explicadas.
- Compatibilidad con versiones: declarar versión mínima de cada app; no usar flags experimentales sin fallback.
- Temas: claves requeridas; plantillas; validación; preview.

### 13.4 Rendimiento
- Medir con `hyperfine`, `zprof`, `/usr/bin/time -v`, `systemd-analyze`.
- zsh: lazy-load plugins pesados; `compinit` una vez; cache de completions; evitar `oh-my-zsh`.
- WM: scripts event-driven; no loops `while true` con `sleep 1`; usar `sxhkd`/`hyprctl`/DBus.
- Barra: módulos con intervalos razonables; no comandos caros cada segundo.
- Tema: generación incremental; no re-renderizar todo si solo cambia un color.
- Instalador: paralelizar descargas cuando sea seguro; cachear; no recompilar AUR innecesariamente.

### 13.5 Seguridad de código
- Validar entradas; nunca `eval` con datos de usuario; escapar rutas; `--` en comandos.
- No usar `curl` sin `--fail --location --proto '=https' --tlsv1.2`; verificar checksums.
- `mktemp` con permisos 700; archivos de estado 600 si contienen datos sensibles.
- No registrar secretos; redactar logs; `umask 077` para backups.
- Dependencias pinneadas; acciones de GitHub por SHA; mínimo privilegio en CI.
- Revisar PKGBUILDs antes de compilar; no ejecutar `makepkg` como root.

---

## 14. Testing, CI y validación

### 14.1 Pirámide de tests
- **Unitarios:** funciones de `lib/` con `bats`; mocks de comandos del sistema.
- **Integración:** contenedor `archlinux:latest` con usuario no-root; instalar perfil `minimal`, correr `archway doctor`, `chezmoi apply --dry-run`, `archway update --check`.
- **Sistema:** VM QEMU con UEFI, GPU virtual, disco Btrfs y ext4; instalar y arrancar sesión bspwm; probar teclado, clipboard, tema, audio, red.
- **Neovim:** instalar el pin de `nvim-config` en una VM limpia; `Lazy! restore`, `checkhealth`, arranque sin errores y contrato de tema (`palette.toml` ↔ `lua/themes/android-mount.lua`, hook `lua/archway.lua`). Probar también el rollback al commit anterior.
- **Hardware:** PC del amigo (primera), luego PC del owner; checklist y logs.
- **Regresión visual:** screenshots de temas/apps clave; comparación perceptual (opcional).
- **Accesibilidad:** contraste, navegación por teclado, escalado, reduced motion.
- **Rendimiento:** benchmarks con umbrales; fallar CI si se degrada >20%.

### 14.2 CI (GitHub Actions)
- `lint`: shellcheck, shfmt, stylua, taplo, yamllint, markdownlint, actionlint, typos, editorconfig-checker.
- `test`: container Arch, bats, dry-run, doctor.
- `package-check`: existencia de paquetes oficiales; AUR vía RPC con cache; fallo solo en paquetes core, warning en opcionales.
- `nvim-contract`: valida `deps/nvim-config.lock` (URL, tag, commit, checksum), la paleta `android-mount` y el hook de override; opcionalmente levanta Neovim headless y corre `checkhealth`.
- `secret-scan`: gitleaks; `trufflehog` opcional.
- `link-check`: lychee para docs.
- `release`: tag firmado, tarball, SHA256SUMS, changelog, notas.
- `act` para correr local; no secretos en PRs de forks; `GITHUB_TOKEN` read-only; acciones pinneadas por SHA.

### 14.3 Criterios de aceptación de release
- Instalación limpia en VM Arch desde cero <15 min (sin contar descargas grandes).
- `archway doctor` sin errores críticos.
- `archway update` desde la versión anterior sin pérdida de datos.
- `archway rollback` restaura correctamente.
- Neovim arranca sin errores críticos con el pin de `nvim-config`; `checkhealth` limpio y tema `android-mount` activo o fallo explícito documentado.
- Cambio de tema en caliente <2 s (Neovim aplica el override en el siguiente arranque, sin recargar sesiones con buffers sin guardar).
- zsh startup <100 ms; bspwm idle <700 MB.
- Sin secretos; gitleaks limpio.
- Contraste AA; navegación teclado completa.
- README, CHANGELOG, keybinds y troubleshooting actualizados.
- Probado en la PC del amigo y, con aprobación, en la del owner.

---

## 15. Documentación, licencia y comunidad

- **README.md**: qué es, screenshots, features, requisitos, instalación, actualización, desinstalación, atajos, perfiles, troubleshooting, créditos, licencia. Inglés primario; español opcional.
- **CHANGELOG.md**: Keep a Changelog + SemVer; sección `Unreleased`; cada release con fecha, cambios, migraciones, breaking changes.
- **CREDITS.md**: gh0stzk/dotfiles, `grubberdubber/nvim-config` (Unlicense), autores de temas/fuentes/wallpapers, inspiraciones, licencias.
- **LICENSE**: GPL-3.0-or-later; SPDX en archivos.
- **SECURITY.md**: cómo reportar vulnerabilidades; no abrir issues públicas con secretos.
- **CONTRIBUTING.md** (opcional): estilo, tests, commits, PRs.
- **docs/**: mínimo; keybinds generados, troubleshooting, uninstall, FAQ. Evitar sprawl documental.
- **Man page** `archway(1)` opcional con `scdoc`; `archway --help` siempre completo.
- **Capturas/asciinema**: `vhs`, `asciinema`, `agg`, `freeze`; no incluir datos personales.
- **Comunidad**: issues con template, discussions, código de conducta (Contributor Covenant), no tolerar acoso.
- **Versionado**: SemVer; `VERSION`; tags `vX.Y.Z`; releases firmados; canales stable/edge.

---

## 16. Flujo de trabajo del agente

1. **Leer** AGENTS.md, README, CHANGELOG y el issue/PR. Si el cambio toca Neovim, leer también el `AGENTS.md` de `nvim-config` y respetar sus reglas.
2. **Inspeccionar** repo y estado de git; no pisar cambios ajenos.
3. **Plan** corto: objetivo, archivos, tests, riesgos, rollback.
4. **Implementar** el cambio mínimo; reutilizar patrones existentes; no introducir dependencias sin justificar.
5. **Probar** en container/VM; ejecutar linters y tests; medir si aplica.
6. **Documentar** cambios de comportamiento; actualizar catálogo/manifiestos.
7. **Revisar** el diff completo; buscar secretos, rutas absolutas, `rm -rf`, `sudo` innecesario, promesas no cumplidas.
8. **Commit** conventional, firmado si es posible; no push sin pedir; no force-push; no reescribir historia.
9. **Reportar** al usuario: resumen, pruebas, riesgos, próximos pasos.

**Nunca:** commitear secretos, borrar archivos del usuario, ejecutar comandos destructivos sin confirmación, inventar paquetes, romper la licencia, ignorar tests rojos, hacer `git reset --hard` en trabajo ajeno.

---

## 17. Roadmap

### Fase 0 — Fundaciones (semana 1)
- Repo, LICENSE, README mínimo, AGENTS.md, `.editorconfig`, `.gitignore`.
- CLI skeleton (`archway version/help`), logging, strict mode, backup/restore, doctor básico.
- CI de lint + container Arch + bats.
- Definir manifiestos core y perfil `minimal`.
- Definir `deps/nvim-config.lock` y abrir los PR upstream necesarios (`bootstrap.sh --skip-packages`, paleta `android-mount`, hook local).

### Fase 1 — MVP bspwm + Android Mount (semanas 2–4)
- bspwm + sxhkd + polybar + rofi + dunst + picom + i3lock-color.
- kitty + zsh nativo + starship + tmux + `nvim-config` pinneado (bootstrap, `checkhealth`, tema).
- Tema Android Mount completo (terminal, WM, barra, rofi, dunst, Neovim vía contrato `nvim-config`, CLI tools).
- Applets: terminal selector, clipboard, screenshot, wallpaper, power, android-mount, password.
- `archway install/update/theme/doctor/rollback` funcionales.
- Probar en VM y en la PC del amigo; release `v0.1.0`.

### Fase 2 — Hyprland + paridad Wayland (semanas 5–8)
- Hyprland + waybar + rofi-wayland/fuzzel + mako/swaync + hyprlock/hypridle.
- Mismo tema, mismos atajos, mismos applets.
- `sway` como fallback mínimo.
- Matugen/wallust opcionales; variantes light/high-contrast.

### Fase 3 — Profundidad developer/security (semanas 9–12)
- Perfiles developer/security; toolchains; contenedores; DB/API; IA opcional.
- Laboratorio Kali/BlackArch en distrobox; guías legales; hardening.
- `archway pkg` completo; export/import; auditoría.
- Benchmarks, accesibilidad, documentación.

### Fase 4 — Madurez y release 1.0
- Migraciones estables; canales; pinning; SBOM opcional.
- Test matrix ampliada; hardware variado; NVIDIA/AMD/Intel; laptops.
- Empaquetado AUR de `archway` (opcional) y script de instalación.
- v1.0.0 con garantía de actualización y rollback.

---

## 18. Definición de terminado (DoD)

Una tarea está terminada solo si:
- [ ] El cambio está implementado y es idempotente.
- [ ] Tiene tests (unitarios/integración) o justificación de por qué no.
- [ ] `shellcheck`, `shfmt`, `stylua`, `taplo`, `yamllint`, `markdownlint` pasan.
- [ ] `bats` y CI pasan.
- [ ] `chezmoi apply --dry-run` limpio en container Arch.
- [ ] Si toca Neovim: pin de `nvim-config` verificado, `checkhealth` limpio, checkout sin cambios locales y contrato de tema validado.
- [ ] `archway doctor` pasa en el escenario probado.
- [ ] Backup/rollback probado si toca archivos existentes.
- [ ] Sin secretos; gitleaks limpio.
- [ ] Documentación/CHANGELOG actualizados.
- [ ] Accesibilidad y rendimiento considerados.
- [ ] Probado en VM; hardware real solo con consentimiento.
- [ ] El diff fue auto-revisado; no hay debug leftovers.
- [ ] Se reportó al usuario qué cambió, cómo se probó y cómo revertir.

---

## 19. Anti-patrones prohibidos

- `curl ... | bash` o `wget ... | sh`.
- `sudo` para dotfiles o para `chezmoi`.
- `rm -rf "$HOME/..."` sin guardas; `rm -rf /` disfrazado.
- Sobrescribir `.zshrc`/`bspwm`/`nvim` sin backup ni consentimiento.
- Forkear, copiar o "mejorar" `nvim-config` dentro de Archway; editar archivos trackeados de `~/.config/nvim`; actualizar plugins fuera de `lazy-lock.json`.
- `--noconfirm` en AUR; compilar PKGBUILDs sin revisar.
- Instalar BlackArch completo, grupos enteros o repos no verificados.
- Meter secretos en git, logs, capturas o historial.
- `git push --force` a `main`; reescribir historia ajena.
- Hardcodear `/home/arch`, nombres de usuario, IPs o tokens.
- Asumir Wayland/X11, NVIDIA, US layout, un solo monitor, inglés.
- Daemons que hacen polling cada segundo; plugins pesados en zsh.
- Dependencias no declaradas; scripts que solo funcionan en la máquina del autor.
- Temas que rompen contraste o no respetan reduced motion.
- "Arreglos" manuales en la PC de otra persona sin registrar el cambio.
- Prometer funciones que no están implementadas o testeadas.

---

## 20. Decisiones abiertas (confirmar con el owner)

1. **Repo/URL final:** se asume `github.com/grubberdubber/archway`; confirmar antes de publicar.
2. **Default WM v0.1:** bspwm (propuesto). ¿Acepta que Hyprland sea v0.2?
3. **Nombre del tema:** `android-mount` (display "Android Mount"). ¿Ok?
4. **Perfil default:** `developer`; ¿o `minimal` para la primera prueba?
5. **AUR helper:** `paru` default, `yay` fallback. ¿Ok?
6. **Licencia:** GPL-3.0-or-later. ¿Ok?
7. **Idioma público:** inglés con README.es opcional. ¿Ok?
8. **BlackArch:** solo opcional/lab, nunca default. ¿Ok?
9. **Hardware del amigo:** GPU, RAM, disco, Secure Boot, LUKS, dual boot. Pendiente de datos.
10. **Marca:** ¿logo/wordmark de Archway? Pendiente; no bloquear MVP.
11. **Pin de `nvim-config`:** se propone tag `vX.Y.Z` por release (no commit de `main`); confirmar cadencia y política de tags firmados.
12. **Tema en Neovim:** requiere PR upstream para `lua/themes/android-mount.lua` y el hook local ignorado; sin eso, `v0.1.0` no declara paridad total del tema con Neovim y `doctor` lo reporta.

Si el owner no responde, el agente debe usar la opción propuesta, documentarla y seguir; no bloquear el MVP por decisiones estéticas.

---

## Anexo A — Configuración keyd completa (propuesta)

```ini
# /etc/keyd/default.conf
# CapsLock: tap = Esc, hold = numpad de una mano.
# La mano derecha escribe números; la izquierda mantiene CapsLock.
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

Capa de navegación opcional (no activar por defecto; puede chocar con AltGr):
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

Notas:
- `keyd` funciona en X11, Wayland y TTY.
- Backup de `/etc/keyd/default.conf` antes de tocar; `keyd reload` para aplicar.
- Probar en TTY y en sesión gráfica; algunos juegos leen evdev directo y pueden ignorar keyd.
- Alternativas: `kanata`, `interception-tools` + `caps2esc`, `xremap`, `kmonad`, `evremap`.

---

## Anexo B — Git config recomendada (staff-level)

```ini
[init]
    defaultBranch = main
[user]
    name = <nombre>
    email = <email>
    signingkey = <ssh-signing-key>
[pull]
    rebase = true
[rebase]
    autoSquash = true
    autoStash = true
[merge]
    conflictStyle = zdiff3
[rerere]
    enabled = true
[diff]
    algorithm = histogram
    colorMoved = zebra
[push]
    autoSetupRemote = true
    default = simple
[fetch]
    prune = true
[commit]
    gpgsign = true
[tag]
    gpgsign = true
[gpg]
    format = ssh
[branch]
    sort = -committerdate
[core]
    pager = delta
    editor = nvim
[interactive]
    diffFilter = delta --color-only
```

- Firmar con SSH: `gpg.format = ssh`, clave pública en GitHub como signing key, agente SSH de Bitwarden.
- `delta` como pager; `difftastic` para diffs estructurales cuando aporte.
- `git maintenance start` para gc/commit-graph; `git-sizer` en repos grandes.
- Nunca `git config --global --add safe.directory '*'` sin criterio.

---

## Anexo C — Checklist de instalación en una PC ajena

**Antes**
- [ ] Consentimiento verbal/escrito y expectativas claras.
- [ ] Backup de datos personales y verificación de restauración.
- [ ] USB live de Arch + otro USB con Archway release.
- [ ] Estado de Secure Boot, BitLocker, LUKS, dual boot.
- [ ] Espacio libre; no tocar particiones ajenas.
- [ ] Red, mirrors, hora, locale, teclado.
- [ ] GPU/RAM/disco detectados; driver elegido.
- [ ] Perfil `developer`, WM `bspwm`, terminal `kitty`, tema `android-mount`.
- [ ] `nvim-config` pinneado; backup de `~/.config/nvim` si ya existía.
- [ ] Snapshot/backup del sistema si ya hay Linux.
- [ ] Plan de rollback escrito.

**Durante**
- [ ] `archway install --dry-run` y revisar plan.
- [ ] Ejecutar install; no interrumpir pacman.
- [ ] Revisar logs si algo falla; no improvisar `rm -rf`.
- [ ] `archway doctor` al final.
- [ ] Probar atajos, terminal, clipboard, tema, audio, Wi-Fi, Bluetooth, suspensión.
- [ ] Abrir Neovim: sin errores, `checkhealth` limpio, tema correcto y plugins restaurados desde el lock.
- [ ] Probar `archway update --check` y `archway rollback` (en seco o con backup).
- [ ] Reiniciar y verificar segundo arranque.

**Después**
- [ ] Entregar cheatsheet y comandos básicos.
- [ ] Explicar cómo actualizar, desinstalar y pedir ayuda.
- [ ] Registrar issues/feedback.
- [ ] No dejar servicios ofensivos, tareas cron ni túneles abiertos.
- [ ] Confirmar que sus datos siguen ahí.

---

## 21. Catálogo de utilidades (menú de referencia, NO manifiesto)

> **Importante:** este catálogo es una **lista de candidatos**, no una orden de instalación. El installer solo instala lo que el perfil/selector elija. Ningún agente debe hacer `pacman -S` de todo esto.
>
> **Notación orientativa:**
> - Sin marca: probablemente en repos oficiales de Arch. Verificar igual.
> - `†`: AUR o paquete de terceros; revisar PKGBUILD y mantenimiento.
> - `‡`: BlackArch o herramienta ofensiva de laboratorio; solo perfil `security`, con autorización.
> - `*`: se instala con gestor de lenguaje/binario upstream (`cargo`, `go install`, `pipx`, `npm`, `uv`, script firmado).
> - `~`: opcional, dependiente de hardware o gusto.
>
> **Regla de oro:** antes de agregar un paquete a un manifiesto, verificar con `pacman -Ss <nombre>`, `pacman -Fy <nombre>`, `paru -Ss <nombre>` y la documentación upstream. Si el nombre cambió, corregir el catálogo y anotarlo en CHANGELOG. Si no existe o está abandonado, no incluirlo.

### 21.1 Base del sistema, arranque y mantenimiento mínimo
`base`, `base-devel`, `linux`, `linux-lts`, `linux-headers`, `linux-lts-headers`, `linux-firmware`, `intel-ucode`/`amd-ucode`, `sudo`, `git`, `curl`, `wget`, `gnupg`, `archlinux-keyring`, `pacman`, `pacman-contrib`, `reflector`, `paru†`, `yay†`, `man-db`, `man-pages`, `texinfo`, `bash-completion`, `zsh`, `tmux`, `openssh`, `rsync`, `unzip`, `zip`, `tar`, `xz`, `zstd`, `7zip`, `less`, `which`, `file`, `findutils`, `grep`, `sed`, `gawk`, `procps-ng`, `psmisc`, `util-linux`, `e2fsprogs`, `dosfstools`, `ntfs-3g`, `exfatprogs`, `btrfs-progs`, `xfsprogs`, `f2fs-tools`, `mdadm`, `lvm2`, `cryptsetup`, `smartmontools`, `nvme-cli`, `hdparm`, `sdparm`, `parted`, `gptfdisk`, `gparted`, `ddrescue`, `testdisk`, `sleuthkit`, `clamav`, `rkhunter`, `lynis`, `arch-audit`, `aide`, `audit`, `usbguard`, `firejail`, `apparmor`, `nftables`, `ufw`, `iptables-nft`, `fail2ban`, `crowdsec†`, `opensnitch†`, `dnscrypt-proxy`, `unbound`, `wireguard-tools`, `openvpn`, `tailscale`, `tor`, `torbrowser-launcher`, `mullvad-vpn†`, `proton-vpn†`, `macchanger`, `ethtool`, `iw`, `wpa_supplicant`, `networkmanager`, `network-manager-applet`, `bluez`, `bluez-utils`, `blueman`, `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `wireplumber`, `pavucontrol`, `alsa-utils`, `sof-firmware`, `fwupd`, `power-profiles-daemon`, `tlp`, `auto-cpufreq†`, `thermald`, `cpupower`, `earlyoom`, `zram-generator`, `ananicy-cpp†`, `irqbalance`, `systemd`, `systemd-sysvcompat`, `systemd-boot`/`grub`/`refind`, `efibootmgr`, `os-prober`, `plymouth`, `mkinitcpio`, `dracut`, `sbctl`, `tpm2-tools`, `systemd-cryptenroll` (parte de systemd), `snapper`, `snap-pac`, `grub-btrfs†`, `timeshift†`, `btrfs-assistant†`, `btrfsmaintenance†`, `topgrade`, `rebuild-detector†`, `downgrade†`, `informant†`, `arch-update†`, `wikiman†`, `arch-wiki-docs`, `pkgfile`, `pacseek†`, `expac`, `pacutils`, `namcap`, `devtools`, `aurutils†`, `rate-mirrors†`, `chaotic-aur` (repo opcional), `reflector.timer`, `paccache.timer`, `fstrim.timer`.

### 21.2 Terminales, multiplexores y sesiones
**Emuladores:** `kitty`, `alacritty`, `wezterm`, `ghostty`, `foot`, `rio`, `st†`, `konsole`, `yakuake`, `guake`, `tilix`, `terminator`, `cool-retro-term`, `xterm`, `urxvt`, `contour†`, `blackbox-terminal†`, `tabby†`, `hyper†`, `wezterm-git†`, `kitty-git†`.
**Multiplexores:** `tmux`, `zellij`, `screen`, `byobu`, `abduco`, `dvtm`, `sesh†`, `tmuxp`, `tmuxinator†`, `smug†`, `mosh`, `autossh`, `et†` (Eternal Terminal), `tmate`, `reptyr`.
**Grabación y demos:** `asciinema`, `agg†`, `vhs†`, `termsvg†`, `freeze†`.
**Utilidades de terminal:** `gum`, `glow`, `mods†`, `bat`, `moar†`, `lnav`, `moreutils`, `parallel`, `pv`, `viddy†`, `entr`, `watch`, `script`, `expect` para automatización interactiva, `tmux-logging` (plugin), `tmux-resurrect`, `tmux-continuum`, `tmux-yank`, `tmux-thumbs`, `tmux-fzf`, `vim-tmux-navigator`.
**Scratchpad:** terminal flotante por WM; en bspwm con reglas, en Hyprland con `special workspace`; no requiere paquete extra.

### 21.3 Shells, prompts y plugins
**Shells:** `zsh`, `fish`, `nushell`, `xonsh`, `elvish`, `oils-for-unix†`, `bash`, `dash`.
**Prompts:** `starship`, `oh-my-posh†`, `zsh-theme-powerlevel10k`, `tide†` (fish), `pure†`, `spaceship-prompt†`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-fast-syntax-highlighting†`, `zsh-completions`, `zsh-history-substring-search`, `fzf-tab†`, `zsh-autopair†`, `zsh-you-should-use†`, `zsh-abbr†`, `zsh-z†`, `zsh-navigation-tools`.
**Gestores de plugins:** `sheldon†`, `antidote†`, `zinit†`, `antigen†`, `oh-my-zsh†` (no recomendado), `fisher†`, `fzf.fish†`, `autopair.fish†`.
**Búsqueda e historial:** `fzf`, `fzf-git.sh*`, `forgit†`, `zoxide`, `atuin`, `mcfly†`, `hishtory†`, `carapace`, `carapace-bin`, `navi`, `pet†`, `tealdeer`, `pay-respects†`, `thefuck` (si sigue mantenido), `direnv`, `mise`, `asdf†` (legacy), `nix` (opcional), `ble.sh†` (bash), `ble.sh` requiere compilación/instalación manual.
**Charm y UI:** `gum`, `glow`, `freeze†`, `mods†`, `soft-serve†`, `skate†`, `vhs†`, `wishlist†`.
**Pagers:** `bat`, `delta`, `moar†`, `lnav`, `less`, `most`, `ov†`, `peco†`.

### 21.4 Reemplazos modernos de coreutils y utilidades CLI
**Listado/búsqueda:** `eza`, `lsd`, `bat`, `fd`, `ripgrep`, `ugrep`, `sd`, `choose†`, `tree`, `broot`, `fzf`.
**Disco:** `dust`, `duf`, `ncdu`, `gdu`, `dua-cli`, `duc†`, `fclones`, `rmlint`, `jdupes`, `rmlint` + `rmlint-gui` opcional.
**Procesos/sistema:** `procs`, `bottom`, `btop`, `htop`, `glances`, `pspg†`, `pgrep`/`pkill` (procps-ng), `lsof`, `fuser`, `pidof`.
**Benchmarks:** `hyperfine`, `tokei`, `scc†`, `time`, `perf`, `stress-ng`, `sysbench`, `fio`.
**Papelera y renombrado:** `trash-cli`, `rip2†`, `renameutils`, `mmv†`, `f2†`, `nomino†`.
**Compresión:** `ouch`, `7zip`, `unarchiver` (o `unar`/`lsar`), `unrar`, `p7zip`, `zstd`, `pigz`, `pbzip2`, `lz4`, `lzip`, `xz`, `bzip2`, `gzip`, `squashfs-tools`, `erofs-utils`, `udftools`.
**Transferencia:** `rsync`, `rclone`, `aria2`, `yt-dlp`, `wget2`, `curl`, `lftp`, `ncftp`, `axel†`, `megacmd†`, `syncthing`.
**Texto:** `sd`, `choose†`, `gsed` (si se necesita GNU sed), `ripgrep-all†` (`rga`), `pdfgrep`, `repgrep†`, `amber†`, `ruplacer†`, `fastmod†`.
**JSON/YAML/CSV:** ver 21.5.

### 21.5 Datos, texto, logs y formatos
**JSON/YAML/XML/HTML:** `jq`, `yq`, `fx†`, `jless`, `gron`, `jaq†`, `jql†`, `dasel†`, `htmlq†`, `xmlstarlet`, `xq` (parte de `yq`), `jqp†`, `jsonnet†`, `cue†`, `nickel†`, `tomlq` (yq), `taplo`.
**CSV/tablas:** `miller`, `qsv†`, `csvkit`, `visidata`, `xsv` (legacy), `tsv-utils†`, `sq`, `usql`.
**Logs:** `lnav`, `goaccess`, `multitail`, `tailspin†`, `angle-grinder` (`agrind†`), `klogg†`, `journalctl` (systemd), `rsyslog`, `syslog-ng`.
**Binarios/hex:** `hexyl`, `xxd` (vim), `bingrep†`, `binwalk`, `ent`, `strings` (binutils), `fq†`, `radare2`, `rizin`, `rabin2`.
**Diffs:** `delta`, `difftastic`, `diff-so-fancy`, `ydiff`, `icdiff`, `meld`, `kdiff3`, `diffoscope†`, `dyff†`.
**Búsqueda estructural:** `ast-grep`, `comby†`, `semgrep†`, `tree-sitter-cli`, `universal-ctags`, `ctags`, `global` (GNU GLOBAL), `cscope`.
**Documentos:** `pandoc`, `typst`, `tectonic`, `poppler`, `qpdf`, `pdftk`, `ocrmypdf`, `tesseract`, `zathura`, `zathura-pdf-mupdf`, `libreoffice-fresh`, `markdownlint-cli2`, `vale`, `lychee`.

### 21.6 Monitoreo, diagnóstico, red y hardware
**Sistema:** `btop`, `bottom`, `htop`, `glances`, `s-tui`, `nvtop`, `iotop-c`, `powertop`, `atop`, `sysstat` (`pidstat`, `iostat`, `mpstat`), `vmstat`, `free`, `slabtop`, `smem`, `ps_mem†`.
**Red:** `bandwhich`, `nethogs`, `iftop`, `vnstat`, `bmon`, `nload`, `trippy`, `mtr`, `gping†`, `doggo†`, `dig` (`bind`), `kdig` (`knot-utils`), `drill` (`ldns`), `whois`, `iperf3`, `speedtest-cli`, `ethtool`, `iproute2`, `ss`, `netstat` (`net-tools`), `nmap`, `masscan`, `zmap`, `rustscan†`, `arp-scan`, `netdiscover`, `nbtscan`, `hping` (`hping3`), `fping`, `tcpdump`, `tshark`/`wireshark-cli`, `wireshark-qt`, `termshark`, `ngrep`, `tcpflow`, `iftop`, `bmon`.
**Hardware:** `fastfetch`, `neofetch` (deprecado), `inxi`, `hwinfo`, `lshw`, `dmidecode`, `lm_sensors`, `smartmontools`, `nvme-cli`, `hdparm`, `fio`, `stress-ng`, `sysstat`, `s-tui`, `turbostat†`, `cpupower`, `radeontop`, `intel-gpu-tools`, `nvtop`, `mesa-utils` (`glxinfo`), `vulkan-tools` (`vulkaninfo`), `clinfo`, `libva-utils` (`vainfo`), `vdpauinfo`, `drm_info†`, `edid-decode†`, `ddcutil`, `brightnessctl`, `i2c-tools`, `usbutils` (`lsusb`), `pciutils` (`lspci`), `usbguard`, `bolt` (Thunderbolt), `fwupd`.
**Trazado/perf:** `strace`, `ltrace`, `perf`, `bpftrace`, `bcc-tools`, `sysdig†`, `lsof`, `systemd-analyze`, `valgrind`, `heaptrack`, `hotspot†`, `flamegraph†`, `gdb`, `lldb`, `rr`, `samply†`, `py-spy†`, `memray†`, `scalene†`, `pyinstrument†`, `hyperfine`.
**TUIs:** `bluetui†`, `impala†`, `wiremix†`, `nmtui`, `iwctl`, `wavemon`, `btop`, `bottom`, `glances`, `s-tui`, `nvtop`, `lazydocker`, `k9s`, `lazygit`, `gitui`, `tig`, `yazi`, `ranger`, `superfile†`, `visidata`, `harlequin†`, `posting†`, `aerc`, `neomutt`, `himalaya`, `newsboat`, `ncmpcpp`, `rmpc†`, `cmus`, `cava`, `spotify-player†`, `mpv`, `yt-dlp`, `timg†`, `chafa`, `viu†`.

### 21.7 Git, GitHub y flujo de desarrollo
**Git:** `git`, `github-cli` (`gh`), `glab`, `lazygit`, `gitui`, `tig`, `jujutsu` (`jj`), `git-delta`, `difftastic`, `git-cliff`, `git-absorb`, `git-lfs`, `git-crypt`, `git-filter-repo`, `git-sizer`, `git-extras`, `git-quick-stats†`, `git-town†`, `gitwatch†`, `gh-dash†`, `ghq`, `onefetch`, `act`, `pre-commit`, `lefthook`, `commitizen`, `czg†`, `commitlint†`, `gitleaks`, `trufflehog†`, `semgrep†`, `bandit`, `osv-scanner`, `pip-audit`, `checkov†`, `dependency-review` (GitHub), `renovate†`/Dependabot.
**Config git staff:** `pull.rebase=true`, `rebase.autoSquash=true`, `rebase.autoStash=true`, `merge.conflictStyle=zdiff3`, `rerere.enabled=true`, `diff.algorithm=histogram`, `push.autoSetupRemote=true`, `fetch.prune=true`, `branch.sort=-committerdate`, firma SSH (`gpg.format=ssh`), pager `delta`, editor `nvim`.
**Editores/IDE:** `neovim` (config oficial: `github.com/grubberdubber/nvim-config`, NvChad v2.5 + lazy.nvim, pinneada), `helix`, `vim`, `emacs`, `micro`, `kakoune`, `zed†`, `vscodium†`, `code` (propietario), `neovide†`, `jetbrains-toolbox†`, `tree-sitter-cli`, `universal-ctags`, `lua-language-server`, `rust-analyzer`, `typescript-language-server`, `bash-language-server`, `marksman`, `yaml-language-server`, `vscode-langservers-extracted†`, `clangd`, `gopls`, `pyright`, `ruff`, `stylua`, `selene†`, `luacheck`, `shellcheck`, `shfmt`, `hadolint`, `actionlint`, `markdownlint-cli2`, `vale`, `typos`, `codespell`, `editorconfig-checker`, `dprint†`, `biome†`, `eslint`, `prettier`, `oxlint†`.
**Plugins Neovim:** el set real y sus versiones los define `nvim-config` mediante `lazy-lock.json`; no se instalan plugins sueltos fuera de ese lock. Referencia de capacidades: `lazy.nvim`, `mason.nvim`, `nvim-lspconfig`, `nvim-treesitter`, Telescope/fzf-lua, `oil.nvim`, `harpoon`, `conform.nvim`, `nvim-lint`, `gitsigns.nvim`, `diffview.nvim`, `neogit`, `trouble.nvim`, `nvim-dap`, `which-key.nvim`, `snacks.nvim`, `blink.cmp`, `lualine.nvim`, `barbar.nvim`, `mini.nvim`, `persistence.nvim`, `toggleterm.nvim`, `render-markdown.nvim`, `img-clip.nvim`, `avante.nvim` (IA opcional).
**IA en terminal (opcional):** `ollama`, `ollama-cuda`/`ollama-rocm`, `llama.cpp†`, `vllm†`, `open-webui†`, `aichat†`, `mods†`, `sgpt†`, `fabric†`, `llm†`, `aider-chat†`, `claude-code†`, `opencode†`, `codex†`, `gemini-cli†`, `copilot-cli†`, `goose†`, `open-interpreter†`, `whisper.cpp†`, `faster-whisper†`, `piper-tts†`, `kokoro†`.

### 21.8 Lenguajes, toolchains, LSPs y debugging
**Gestores de versiones/entornos:** `mise`, `direnv`, `uv`, `pipx`, `poetry`, `pdm`, `hatch`, `rye†` (legacy), `fnm†`, `nvm†`, `corepack`, `asdf†` (legacy), `nix` (opcional), `devbox†`, `devenv†`, `nix-direnv†`, `home-manager`.
**Rust:** `rustup`, `cargo`, `cargo-watch`, `cargo-nextest`, `cargo-audit`, `cargo-deny`, `cargo-edit`, `cargo-binstall`, `cargo-expand`, `cargo-outdated`, `cargo-udeps†`, `bacon`, `sccache`, `rust-analyzer`, `clippy`.
**Python:** `python`, `python-pip`, `uv`, `pipx`, `poetry`, `ruff`, `pyright`, `ipython`, `pytest`, `mypy`, `black` (legacy), `isort` (legacy), `bandit`, `pip-audit`, `memray†`, `py-spy†`, `scalene†`, `pyinstrument†`.
**JS/TS:** `nodejs`, `npm`, `pnpm`, `yarn`, `bun`, `deno`, `fnm†`, `typescript`, `typescript-language-server`, `eslint`, `prettier`, `biome†`, `oxlint†`, `vite`, `tsx`, `nodemon`, `pm2`.
**Go:** `go`, `gopls`, `golangci-lint`, `delve`, `air†`, `goreleaser†`, `staticcheck†`, `govulncheck†`.
**Otros:** `zig`, `jdk-openjdk`, `kotlin`, `gradle`, `maven`, `elixir`, `erlang`, `ocaml`, `opam`, `dune`, `lua`, `luajit`, `luarocks`, `ruby`, `php`, `composer`, `dotnet-sdk`, `R`, `julia†`, `swift` (upstream), `haskell-stack`/`ghcup†`, `crystal†`, `nim†`, `v`†.
**C/C++:** `gcc`, `clang`, `cmake`, `ninja`, `meson`, `bear`, `ccache`, `mold`, `lld`, `make`, `autoconf`, `automake`, `libtool`, `pkgconf`, `gdb`, `lldb`, `valgrind`, `heaptrack`, `perf`, `flamegraph†`, `strace`, `ltrace`.
**Runners/tareas:** `just`, `go-task` (`task`), `make`, `watchexec`, `entr`, `reflex†`, `modd†`, `overmind†`, `hivemind†`, `process-compose†`, `tilt†`, `skaffold†`.
**Reproducibilidad:** `docker`, `podman`, `devcontainer` (VS Code), `nix`, `devenv†`, `devbox†`, `vagrant`, `packer`.

### 21.9 APIs, bases de datos y red de desarrollo
**HTTP/API:** `xh`, `httpie`, `curlie†`, `hurl`, `bruno†`, `posting†`, `insomnia†`, `grpcurl`, `websocat`, `mitmproxy`, `wuzz†`, `httpstat†`, `hey†`, `oha†`, `vegeta†`, `k6†`, `wrk`, `bombardier†`, `ab` (`apache-tools`), `h2load` (`nginx`).
**Túneles/HTTPS local:** `cloudflared`, `ngrok†`, `caddy`, `mkcert`, `nginx`, `traefik†`, `step-cli†`, `openssl`, `gnutls`, `mbedtls`, `cfssl†`, `lego†`.
**Bases de datos:** `sqlite`, `postgresql`, `mariadb`, `redis`, `valkey†`, `mongodb†` (legacy), `mongosh†`, `duckdb`, `clickhouse`†, `pgcli`, `mycli`, `litecli`, `usql`, `lazysql†`, `harlequin†`, `dbeaver`, `beekeeper-studio†`, `redis-insight†`, `mongo-compass†`.
**Migraciones/esquemas:** `dbmate`, `goose`, `sqlc`, `atlas†`, `flyway`, `prisma*`, `liquibase†`, `sqitch†`.
**Diseño/ER:** `dbdiagram`* (web), `drawio-desktop†`, `plantuml`, `mermaid-cli†`, `graphviz`, `excalidraw†`.

### 21.10 Contenedores, Kubernetes, IaC y cloud
**Contenedores:** `docker`, `docker-compose`, `docker-buildx`, `podman`, `podman-compose`, `buildah`, `skopeo`, `lazydocker`, `dive`, `ctop†`, `oxker†`, `docker-bench-security†`, `hadolint`, `trivy`, `grype`, `syft`, `cosign`.
**Kubernetes:** `kubectl`, `helm`, `k9s`, `kubectx`, `kubens`, `stern`, `kind`, `minikube`, `k3s`, `k3d†`, `kustomize`, `krew`, `kubeconform†`, `kube-bench†`, `kube-hunter†`, `kubescape†`, `conftest†`, `opa†`, `argocd†`, `fluxcd†`, `cilium-cli†`, `hubble†`, `talosctl†`, `velero†`.
**IaC:** `opentofu`, `terraform` (legacy), `terragrunt†`, `tflint`, `ansible`, `ansible-lint`, `packer`, `vagrant`, `pulumi†`, `crossplane†`, `cloud-init`, `qemu-full`, `libvirt`, `virt-manager`, `virt-viewer`, `edk2-ovmf`, `swtpm`, `spice`, `looking-glass†`, `virtiofsd`, `distrobox`, `incus`, `lxc`, `quickemu†`, `cloud-hypervisor†`, `firecracker†`.
**Cloud:** `aws-cli-v2†`, `azure-cli†`, `google-cloud-cli†`, `doctl†`, `flyctl†`, `wrangler†`, `vercel†`, `netlify-cli†`, `supabase†`, `railway†`, `heroku-cli†`, `rclone`.
**Secretos/CI:** `sops`, `age`, `rage`, `minisign`, `cosign`, `vault†`, `consul†`, `nomad†`, `boundary†`, `waypoint†`, `gitleaks`, `trufflehog†`, `semgrep†`, `checkov†`, `tfsec†`/`trivy`, `osv-scanner`.

### 21.11 Ciberseguridad (perfil `security`, solo con autorización)

> Aviso obligatorio: estas herramientas se usan únicamente en sistemas propios, CTF, HTB/THM, labs o clientes con autorización escrita. Archway no configura ataques, persistencia, exfiltración ni servicios expuestos. `‡` = BlackArch/lab; instalar puntualmente, nunca grupos completos.

**Reconocimiento, OSINT y superficie de ataque**
`nmap`, `masscan`, `zmap‡`, `rustscan†`, `naabu†`, `arp-scan`, `netdiscover`, `nbtscan`, `hping3`, `fping`, `amass`, `subfinder†`, `assetfinder†`, `findomain†`, `dnsrecon`, `dnsx†`, `massdns`, `shuffledns†`, `puredns†`, `httpx†`, `katana†`, `hakrawler†`, `gospider†`, `gau†`, `waybackurls†`, `theharvester†`, `recon-ng†`, `spiderfoot†`, `maltego†`, `sherlock†`, `holehe†`, `maigret†`, `social-analyzer†`, `whois`, `shodan†` (CLI), `censys†`, `uncover†`, `notify†`, `interactsh†`, `tlsx†`, `cdncheck†`, `asnmap†`, `mapcidr†`, `dnsgen†`, `altdns†`, `gobuster`, `feroxbuster`, `ffuf`, `dirb`, `dirsearch†`, `wfuzz†`, `arjun†`, `paramspider†`, `x8†`, `kxss†`, `dalfox†`, `XSStrike†`, `commix†`, `sqlmap`, `nikto`, `whatweb`, `wafw00f†`, `wpscan†`, `joomscan†`, `droopescan†`, `nuclei†`, `jaeles†`, `caido†`, `burpsuite†`, `zaproxy`, `mitmproxy`, `bettercap`, `ettercap`, `responder†`, `exiftool`, `metagoofil†`, `gitleaks`, `trufflehog†`, `semgrep†`.

**Red, MITM, pivoting y túneles**
`wireshark-qt`, `wireshark-cli` (`tshark`), `termshark`, `tcpdump`, `tcpflow`, `ngrep`, `bettercap`, `ettercap`, `mitmproxy`, `python-scapy`, `ncat` (`nmap`), `socat`, `openbsd-netcat`, `proxychains-ng`, `tor`, `sshuttle`, `chisel†`, `ligolo-ng†`, `gost†`, `frp†`, `iodine†`, `dnscat2†`, `wireguard-tools`, `openvpn`, `tailscale`, `stunnel`, `sslh`, `rinetd`, `socat`.

**Web, APIs y fuzzing**
`burpsuite†`, `zaproxy`, `caido†`, `mitmproxy`, `sqlmap`, `nikto`, `gobuster`, `feroxbuster`, `ffuf`, `dirb`, `dirsearch†`, `wfuzz†`, `arjun†`, `paramspider†`, `x8†`, `dalfox†`, `XSStrike†`, `commix†`, `wpscan†`, `joomscan†`, `droopescan†`, `nuclei†`, `jaeles†`, `katana†`, `hakrawler†`, `gospider†`, `gau†`, `waybackurls†`, `subfinder†`, `httpx†`, `naabu†`, `tlsx†`, `interactsh†`, `jwt_tool†`, `jwt-cracker†`, `hashcat`, `john`, `hydra`, `medusa`, `patator†`, `crowbar†`, `ncrack†`, `cewl`, `crunch`, `hashid†`, `haiti†`, `name-that-hash†`, `seclists†`, `wordlists†`, `rockyou` (solo legal), `httpie`, `xh`, `hurl`, `postman†`, `insomnia†`, `bruno†`, `posting†`, `grpcurl`, `websocat`.

**Contraseñas, hashes y fuerza bruta**
`hashcat`, `john` (`john-the-ripper`), `hydra`, `medusa`, `patator†`, `crowbar†`, `ncrack†`, `cewl`, `crunch`, `hashid†`, `haiti†`, `name-that-hash†`, `seclists†`, `wordlists†`, `pwdump` (Windows), `mimikatz` (Windows, lab), `impacket`, `pypykatz†`, `responder†`, `ntlmrelayx` (impacket), `certipy†`, `kerbrute†`.

**Wi-Fi y RF (solo redes propias)**
`aircrack-ng`, `hcxtools`, `hcxdumptool`, `kismet`, `wifite†`, `reaver†`, `bully†`, `pixiewps†`, `mdk4†`, `hostapd`, `dnsmasq`, `iw`, `wavemon`, `gnuradio`, `gqrx`, `rtl-sdr`, `hackrf`, `sdrangel`, `inspectrum†`, `urh†` (Universal Radio Hacker), `kismet`, `bladerf†`, `limesuite†`, `soapysdr†`, `srsran` (avanzado).

**Explotación, binarios, reversing y CTF**
`metasploit†`, `exploitdb`, `searchsploit`, `python-pwntools`, `ropper†`, `one_gadget†`, `checksec`, `gdb`, `pwndbg†`, `gef†`, `peda†`, `voltron†`, `radare2`, `rizin`, `cutter`, `ghidra`, `imhex`, `hexyl`, `binwalk`, `binutils`, `frida†`, `objection†`, `apktool`, `jadx`, `dex2jar†`, `z3`, `sagemath`, `RsaCtfTool†`, `xortool†`, `stegseek†`, `steghide`, `zsteg`, `foremost`, `scalpel†`, `CyberChef` (web/local), `qemu` (cross-arch), `gdb-multiarch`, `arm-none-eabi-gdb`†, `angr†`, `claripy†`, `pwncat†`, `pwncat-cs†`, `upx`, `patchelf`, `rr`, `samply†`, `ltrace`, `strace`.

**Active Directory y Windows**
`impacket`, `netexec†` (`nxc`), `crackmapexec†` (legacy), `bloodhound†`, `bloodhound-python†`, `certipy†`, `kerbrute†`, `enum4linux-ng†`, `evil-winrm†`, `pypykatz†`, `smbmap†`, `smbclient`, `rpcclient`, `ldapsearch` (`openldap`), `ldapdomaindump†`, `windapsearch†`, `adidnsdump†`, `gpp-decrypt†`, `secretsdump` (impacket), `mimikatz` (Windows), `rubeus` (Windows), `powerview` (Windows), `sharpcollection` (Windows), `chisel†`, `ligolo-ng†`, `socat`.

**Forense, malware y respuesta a incidentes**
`yara`, `capa†`, `floss†`, `die†` (Detect It Easy), `volatility3†`, `sleuthkit`, `autopsy†`, `testdisk`, `photorec`, `ddrescue`, `bulk_extractor†`, `plaso†`, `log2timeline†`, `zeek†`, `suricata`, `snort†`, `chainsaw†`, `hayabusa†`, `evtxecu†`, `velociraptor†`, `osquery†`, `auditd`, `libewf†`, `afflib†`, `guymager†`, `dc3dd†`, `dcfldd†`, `hashdeep†`, `md5deep†`, `ssdeep`, `sdhash†`, `trid†`, `foremost`, `scalpel†`, `extundelete†`, `ext4magic†`, `qpdf`, `poppler`, `exiftool`, `mat2`, `sleuthkit`, `plaso`, `timesketch` (server), `jupyter` (notebooks de análisis), `binwalk`.

**Laboratorios, vulnerabilidades y entornos**
repo **BlackArch** (opcional, vía `strap.sh` verificado), imagen **Kali** en distrobox/VM, `exegol†`, `qemu-full`, `virt-manager`, `vagrant`, `GNS3†`, `containerlab†`, `docker`, `podman`, `kind`, `minikube`, `k3d†`, `vulnhub` VMs, `OWASP Juice Shop`, `DVWA`, `WebGoat` (contenedores), `metasploitable` (VM), `HTB`/`THM` VPN, `wireguard-tools`, `openvpn`.

**Defensa, hardening y supply chain**
`lynis`, `arch-audit`, `rkhunter`, `chkrootkit`, `clamav`, `aide`, `auditd`, `apparmor`, `firejail`, `bubblewrap`, `usbguard`, `opensnitch†`, `nftables`, `ufw`, `firewalld`, `fail2ban`, `crowdsec†`, `linux-hardened`, `sbctl`, `systemd-cryptenroll`, `tpm2-tools`, `dnscrypt-proxy`, `unbound`, `ssh-audit†`, `testssl.sh†`, `sslscan`, `sslyze†`, `trivy`, `grype`, `syft`, `cosign`, `gitleaks`, `trufflehog†`, `semgrep†`, `bandit`, `osv-scanner`, `pip-audit`, `checkov†`, `prowler†`, `scoutsuite†`, `kube-bench†`, `kube-hunter†`, `kubescape†`, `falco†`, `osquery†`, `auditd`, `sysmon` (Windows), `wazuh` (server/agent), `suricata`, `zeek†`.

**Notas y evidencia**
`cherrytree†`, `obsidian†`, `joplin†`, `xournalpp`, `flameshot`, `grim`+`slurp`+`satty`, `asciinema`, `tmux-logging`, `script`, `scrcpy` (Android), `exiftool`, `mat2`, `gitleaks`.

### 21.12 Privacidad, cifrado, llaves y backups
**Contraseñas:** `bitwarden`, `bitwarden-cli`, `rbw†`, `rofi-rbw†`, `bws†`, `keepassxc`, `pass`, `pass-otp`, `gopass†`, `vaultwarden†` (autoalojado), `keyguard†` (Android).
**Cifrado de archivos:** `age`, `rage†`, `sops`, `gnupg`, `minisign`, `signify†`, `veracrypt`, `cryptsetup` (LUKS), `gocryptfs`, `cryptomator†`, `zulucrypt†`, `keepassxc`, `qpdf` (protección PDF), `mat2`, `exiftool`, `bleachbit`, `metadata-cleaner` (Flatpak).
**Llaves hardware:** `yubikey-manager` (`ykman`), `yubico-authenticator†`, `pam-u2f`, `libfido2`, `oath-toolkit`, `tpm2-tools`, `systemd-cryptenroll`, `sbctl`.
**Agentes/llaveros:** `pinentry`, `pinentry-gnome3`, `pinentry-qt`, `gnome-keyring`, `kwallet`, `libsecret` (`secret-tool`), `gpg-agent` (con `enable-ssh-support`), `keychain`, `ssh-agent`, `rbw-agent`.
**Red/anonimato:** `tor`, `torbrowser-launcher`, `mullvad-vpn†`, `proton-vpn†`, `macchanger`, `opensnitch†`, `dnscrypt-proxy`, `unbound`, `wireguard-tools`, `tailscale`, `openvpn`, `sshuttle`, `proxychains-ng`.
**Backups/sync:** `restic`, `borg`, `borgmatic†`, `vorta†`, `rclone`, `rsync`, `syncthing`, `syncthingtray†`, `kopia†`, `duplicity†`, `duplicacy†`, `backrest†`, `unison†`, `sshfs`, `rclone-browser†`.
**Metadatos/limpieza:** `mat2`, `exiftool`, `bleachbit`, `qpdf`, `poppler`, `pdf-redact-tools†`, `metadata-cleaner` (Flatpak), `shred` (coreutils; usar con cuidado en SSD), `nwipe†`, `ddrescue`.

### 21.13 Ingeniería de dotfiles y reproducibilidad
**Gestores:** `chezmoi` (default), `stow`, `yadm`, `vcsh†`, `dotbot†`, `rcm†`, `tuckr†`, `dotter†`, `mackup†`, `dfm†`, `home-manager` (Nix), bare repo (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`).
**Secretos en dotfiles:** `chezmoi` + `bitwarden`/`rbw`, `age`, `sops`, `pass`, `gpg`, `gitleaks`, `trufflehog†`, `git-filter-repo`, `pre-commit`.
**XDG y limpieza:** `xdg-ninja†`, `xdg-user-dirs`, `xdg-utils`, `shared-mime-info`, `desktop-file-utils`, `hicolor-icon-theme`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`/`-wlr`.
**Sistema como código:** `etckeeper`, `ansible-pull`, `archinstall` (JSON), `systemd` user units/timers versionados, `just`, `make`, `packer`, `vagrant`, `qemu`, `docker`/`podman`.
**Calidad:** `shellcheck`, `shfmt`, `stylua`, `taplo`, `yamllint`, `markdownlint-cli2`, `actionlint`, `editorconfig-checker`, `typos`, `codespell`, `lychee`, `vale`, `bats`, `shunit2†`, `shellspec†`, `pre-commit`, `lefthook`.
**Empaquetado/CI:** `namcap`, `devtools`, `aurutils†`, `act`, `github-cli`, `gitleaks`, `syft`, `cosign`, `reuse†` (licencias SPDX), `pre-commit`.
**Presentación:** `asciinema`, `agg†`, `vhs†`, `freeze†`, `fastfetch`, `onefetch`, `silicon†`, `carbon-now-cli†`, `charm` (`gum`, `glow`).

### 21.14 Mantenimiento de Arch y paquetes
`paru†`, `yay†`, `pacman-contrib`, `reflector`, `rate-mirrors†`, `pkgfile`, `pacseek†`, `expac`, `pacutils`, `namcap`, `devtools`, `aurutils†`, `arch-update†`, `informant†`, `downgrade†`, `rebuild-detector†`, `arch-audit`, `snapper`, `snap-pac`, `grub-btrfs†`, `timeshift†`, `topgrade`, `chaotic-aur` (repo opcional), `wikiman†`, `arch-wiki-docs`, `fwupd`, `earlyoom`, `zram-generator`, `ananicy-cpp†`, `paccache.timer`, `fstrim.timer`, `reflector.timer`, `systemd-tmpfiles`, `journalctl --vacuum-*`, `pacman -Qtdq`, `pactree`, `pacdiff`, `checkupdates`, `paccache -r`, `pkgbrowser†`, `octopi†`, `bauh†`, `pamac†`.
**Reglas:** `pacman -Syu` completo antes de instalar; no actualizaciones parciales; revisar noticias de Arch; snapshot antes; `pacdiff` para `.pacnew`; `paccache` para caché; `rebuild-detector` para AUR; `arch-audit` para CVEs; `downgrade` para rollback puntual; `topgrade` opcional y sin tocar dotfiles por su cuenta.

### 21.15 Teclado, atajos, input y accesibilidad
**Remapeo:** `keyd` (default), `kanata†`, `interception-tools†`, `caps2esc†`, `xremap†`, `kmonad†`, `evremap†`, `input-remapper†`, `ydotool`, `dotool†`, `wtype`, `xdotool`, `wmctrl`, `xclip`, `xsel`, `wl-clipboard`, `cliphist`, `clipse†`, `copyq`, `greenclip†`, `clipman†`, `clipcat†`, `wl-clip-persist†`.
**Eventos/gestos:** `wev`, `libinput`, `libinput-gestures`, `fusuma†`, `touchegg†`, `sxhkd`, `swhkd†`, `wlr-which-key†`.
**Expansión/automatización:** `espanso`, `autokey†`, `xdotool`, `ydotool`, `wtype`, `keyd` macros, QMK/Vial (firmware de teclado), `kmonad`.
**Layouts:** `setxkbmap`, `xkbcomp`, `compose:ralt`, `us-altgr-intl`, `Colemak-DH`, `workman`, `dvorak`, `kbdd†`, `xkblayout-state†`.
**Accesibilidad:** `orca`, `espeak-ng`, `speech-dispatcher`, `onboard`, `mousetweaks`, `kmag`, `gnome-accessibility-themes`, `hicolor-icon-theme`, `fontconfig`, `noto-fonts`, `noto-fonts-emoji`, `ttf-dejavu`, `ttf-liberation`.

### 21.16 Escritorio, window managers y rice
**X11/bspwm:** `bspwm`, `sxhkd`, `picom`, `polybar`, `rofi`, `dunst`, `i3lock-color`, `feh`, `nitrogen`, `xsetroot`, `xrandr`, `arandr`, `lxappearance`, `qt5ct`, `qt6ct`, `kvantum`, `nwg-look`, `gtk-engine-murrine`, `gnome-themes-extra`, `papirus-icon-theme`, `tela-icon-theme†`, `bibata-cursor-theme†`, `xorg-xinit`, `xorg-server`, `xorg-xrandr`, `xorg-xsetroot`, `xorg-xprop`, `xdotool`, `wmctrl`.
**Wayland/Hyprland:** `hyprland`, `waybar`, `sway`, `niri†`, `river`, `labwc`, `wayfire`, `swayfx†`, `hyprpaper`, `hyprlock`, `hypridle`, `hyprpicker`, `hyprshot†`, `grimblast†`, `grim`, `slurp`, `satty`, `swappy`, `wf-recorder`, `wl-screenrec†`, `gpu-screen-recorder†`, `obs-studio`, `fuzzel`, `wofi`, `tofi`, `walker†`, `anyrun†`, `vicinae†`, `rofi-wayland`, `mako`, `swaync`, `swaylock`, `swayidle`, `wlogout`, `swaybg`, `waypaper†`, `pywal`, `wallust†`, `matugen†`, `kanshi`, `nwg-displays†`, `shikane†`, `gammastep`, `wlsunset`, `brightnessctl`, `ddcutil`, `pipewire`, `wireplumber`, `pavucontrol`, `easyeffects`, `helvum`, `qpwgraph`, `playerctl`, `bluez`, `bluetui†`, `blueman`, `networkmanager`, `iwd`, `nmtui`, `impala†`, `wiremix†`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk`, `hyprpolkitagent`, `polkit-gnome`, `gnome-keyring`, `libsecret`.
**Login/display:** `greetd`, `tuigreet†`, `ly†`, `sddm`, `gdm`, `lightdm`, `lemurs†`, `regreet†`.
**Widgets:** `eww`, `ags†` (Aylur's GTK Shell), `quickshell†`, `conky`, `polybar`, `waybar`, `nwg-panel†`, `sfwbar†`.
**Wallpapers:** `swww`, `hyprpaper`, `swaybg`, `feh`, `nitrogen`, `variety`, `waypaper†`, `wpaperd†`, `mpvpaper†`, `plasma-wallpaper` (KDE).
**Capturas/grabación:** `grim`, `slurp`, `satty`, `swappy`, `flameshot`, `maim`, `scrot`, `ksnip`, `spectacle`, `obs-studio`, `wf-recorder`, `wl-screenrec†`, `gpu-screen-recorder†`, `kooha†`, `peek†`.
**OCR:** `tesseract`, `tesseract-data-eng`, `tesseract-data-spa`, `ocrmypdf`, `gimagereader†`, `normcap†`.
**Audio/video:** `pipewire`, `wireplumber`, `pipewire-alsa`, `pipewire-pulse`, `pipewire-jack`, `pavucontrol`, `easyeffects`, `helvum`, `qpwgraph`, `playerctl`, `mpv`, `ffmpeg`, `gst-libav`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly`, `libva`, `libva-intel-driver`, `intel-media-driver`, `nvidia-utils`, `vulkan-icd-loader`, `vulkan-intel`, `vulkan-radeon`, `vulkan-nouveau`.
**Multimedia:** `mpd`, `ncmpcpp`, `rmpc†`, `cmus`, `cava`, `spotify-player†`, `ncspot†`, `yt-dlp`, `mpv`, `imagemagick`, `graphicsmagick`, `ffmpeg`, `handbrake`, `mkvtoolnix`, `mediainfo`, `exiftool`.

### 21.17 Fuentes, iconos, temas y diseño
**Nerd Fonts:** `ttf-jetbrains-mono-nerd`, `ttf-firacode-nerd`, `ttf-iosevka-nerd`, `ttf-cascadia-code-nerd`, `ttf-meslo-nerd`, `ttf-commit-mono-nerd†`, `ttf-maple-mono-nf†`, `ttf-nerd-fonts-symbols`, `ttf-nerd-fonts-symbols-mono`.
**Texto/emoji/CJK:** `noto-fonts`, `noto-fonts-emoji`, `noto-fonts-cjk`, `ttf-dejavu`, `ttf-liberation`, `ttf-roboto`, `ttf-inter†`, `adobe-source-code-pro-fonts`, `fontconfig`, `freetype2`, `harfbuzz`.
**Temas GTK/Qt:** `catppuccin-gtk-theme†`, `rose-pine-gtk-theme†`, `gruvbox-material-gtk-theme†`, `tokyo-night-gtk-theme†`, `kanagawa-gtk-theme†`, `nordic-gtk-theme†`, `everforest-gtk-theme†`, `colloid-gtk-theme†`, `whitesur-gtk-theme†`, `qogir-gtk-theme†`, `materia-gtk-theme`, `arc-gtk-theme`, `papirus-icon-theme`, `tela-icon-theme†`, `bibata-cursor-theme†`, `catppuccin-cursors†`, `nordzy-cursors†`, `volantes-cursors†`, `qt5ct`, `qt6ct`, `kvantum`, `nwg-look`, `lxappearance`, `gnome-themes-extra`.
**Paletas:** Catppuccin, Rosé Pine, Gruvbox, Tokyo Night, Kanagawa, Nord, Everforest, Material You/Android Mount. Usar la misma paleta en terminal, barra, editor, rofi, bat, fzf, delta, btop, lazygit, yazi y starship.

### 21.18 Productividad, notas, medios, documentos e IA
**Tareas/tiempo:** `taskwarrior`, `timewarrior`, `todoman`, `khal`, `vdirsyncer`, `calcurse`, `vit†`, `taskopen†`, `topydo†`, `todo.txt-cli†`, `remind†`.
**Notas:** `obsidian†`, `zk†`, `nb†`, `jrnl†`, `cherrytree†`, `joplin†`, `logseq†`, `trilium†`, `siyuan†`, `xournalpp`, `neuron†`, `mdbook`, `hugo`, `zola`.
**Correo/feeds:** `aerc`, `neomutt`, `himalaya†`, `newsboat`, `notmuch`, `isync` (`mbsync`), `msmtp`, `mu`, `mu4e`, `offlineimap`, `lieer†`, `gmailieer†`, `rssguard†`, `fluent-reader†`.
**Web terminal:** `w3m`, `lynx`, `links`, `elinks`, `qutebrowser`, `browsh†`, `nyxt†`, `surf†`.
**Música/video:** `mpd`, `ncmpcpp`, `rmpc†`, `cmus`, `spotify-player†`, `ncspot†`, `mpv`, `ffmpeg`, `imagemagick`, `yt-dlp`, `cava`, `pipe-viewer†`, `ytfzf†`, `freetube†`, `strawberry†`, `audacious`, `vlc`.
**Documentos:** `pandoc`, `typst`, `tectonic`, `zathura`, `zathura-pdf-mupdf`, `poppler`, `qpdf`, `libreoffice-fresh`, `onlyoffice-bin†`, `presenterm†`, `marp-cli†`, `mdbook`, `hugo`, `zola`, `texlive` (grupo), `latexmk`, `biber`.
**Cálculo/traducción:** `qalc`, `bc`, `units`, `gnuplot`, `R`, `julia†`, `translate-shell†`, `crow-translate†`, `argos-translate†`.
**OCR/captura:** `tesseract`, `ocrmypdf`, `normcap†`, `gimagereader†`, `flameshot`, `satty`, `swappy`.
**IA local/CLI:** `ollama`, `ollama-cuda`/`ollama-rocm`, `llama.cpp†`, `vllm†`, `open-webui†`, `aichat†`, `mods†`, `sgpt†`, `fabric†`, `llm†`, `aider-chat†`, `claude-code†`, `opencode†`, `codex†`, `gemini-cli†`, `copilot-cli†`, `goose†`, `open-interpreter†`, `whisper.cpp†`, `faster-whisper†`, `piper-tts†`, `kokoro†`.

### 21.19 Red, acceso remoto, sincronización y backups
**Remoto:** `openssh`, `mosh`, `sshfs`, `tailscale`, `wireguard-tools`, `openvpn`, `autossh`, `et†`, `tmate`, `teleport` (`tsh†`), `rustdesk†`, `xrdp`, `freerdp`, `remmina`, `virt-viewer`, `spice-gtk`.
**SSH config staff:** `ControlMaster auto`, `ControlPersist 10m`, `ServerAliveInterval 30`, `ServerAliveCountMax 3`, `ProxyJump`, `IdentitiesOnly yes`, `HashKnownHosts yes`, `AddKeysToAgent yes`, `UseKeychain` (macOS), llaves `ed25519` en Bitwarden/YubiKey.
**Sincronización:** `syncthing`, `syncthingtray†`, `rclone`, `rsync`, `unison†`, `sshfs`, `kdeconnect`, `gsconnect†`, `localsend†`, `croc†`, `magic-wormhole†`, `wormhole-william†`.
**Backups:** `restic`, `borg`, `borgmatic†`, `vorta†`, `rclone`, `rsync`, `kopia†`, `duplicity†`, `duplicacy†`, `backrest†`, `timeshift†`, `snapper`, `btrfs-assistant†`, `btrfsmaintenance†`.
**Discos/medios:** `ventoy` (USB), `gparted`, `ddrescue`, `smartmontools`, `balena-etcher†`, `usbimager†`, `popsicle†`, `mkusb†`, `gnome-disk-utility`, `udisks2`, `udiskie`, `gvfs`, `gvfs-mtp`, `gvfs-smb`, `gvfs-nfs`, `exfatprogs`, `ntfs-3g`, `dosfstools`, `e2fsprogs`, `btrfs-progs`, `xfsprogs`, `f2fs-tools`.

### 21.20 Hardware, impresión, Android e iOS
**Hardware:** `linux-firmware`, `intel-ucode`, `amd-ucode`, `fwupd`, `bolt`, `tlp`, `thermald`, `power-profiles-daemon`, `auto-cpufreq†`, `cpupower`, `lm_sensors`, `smartmontools`, `nvme-cli`, `hdparm`, `sdparm`, `nvtop`, `radeontop`, `intel-gpu-tools`, `mesa-utils`, `vulkan-tools`, `clinfo`, `libva-utils`, `vdpauinfo`, `drm_info†`, `edid-decode†`, `ddcutil`, `brightnessctl`, `i2c-tools`, `usbutils`, `pciutils`, `dmidecode`, `hwinfo`, `lshw`, `inxi`, `fastfetch`, `btop`, `bottom`, `glances`, `s-tui`, `stress-ng`, `fio`, `sysbench`, `memtester`.
**Impresión/escaneo:** `cups`, `cups-pdf`, `hplip`, `sane`, `simple-scan`, `xsane`, `system-config-printer`, `avahi`, `nss-mdns`, `ghostscript`, `foomatic-db`, `gutenprint`.
**Android:** `android-tools` (`adb`, `fastboot`), `scrcpy`, `simple-mtpfs`, `gvfs-mtp`, `android-file-transfer†`, `jmtpfs†`, `mtpfs†`, `qrencode`, `zbar`, `waydroid†`, `adb-sync†`.
**iOS:** `libimobiledevice`, `usbmuxd`, `ifuse†`, `ideviceinstaller†`, `libirecovery†`.

### 21.21 Gaming y extras opcionales
`steam`, `lutris`, `heroic-games-launcher†`, `gamemode`, `mangohud`, `vkbasalt†`, `protonup-qt†`, `wine`, `winetricks`, `bottles†`, `distrobox` (para gaming en contenedor), `gamescope`, `vkd3d`, `dxvk` (parte de wine/proton), `pipewire`, `obs-studio`, `discord†`, `vesktop†`, `armcord†`, `spotify†`, `freetube†`, `mpv`, `retroarch`, `emulationstation†`, `dolphin-emu`, `pcsx2`, `rpcs3†`, `yuzu` (legacy/legal), `ryujinx` (legacy/legal), `duckstation†`.
**Nota:** gaming no es prioridad del MVP; instalar solo si el usuario lo pide. Nada de software pirata ni ROMs.

### 21.22 Verificación de nombres y ejemplos de instalación
**Verificación rápida:**
```bash
pacman -Ss '^kitty$'          # repo oficial
pacman -Fy kitty              # qué paquete provee un archivo
paru -Ss '^kitty$'            # oficial + AUR
paru -Si kitty                # info, versión, dependencias
pkgfile -s kitty              # qué paquete contiene un binario
```
**Instalación por grupos (ejemplo, no ejecutar a ciegas):**
```bash
# 1) Actualizar el sistema completo primero
sudo pacman -Syu

# 2) Núcleo oficial del perfil minimal/developer
sudo pacman -S --needed base-devel git chezmoi kitty zsh starship tmux neovim \
  bspwm sxhkd polybar rofi dunst picom i3lock-color \
  fzf zoxide ripgrep fd bat eza jq yq delta btop fastfetch \
  networkmanager pipewire wireplumber pavucontrol \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

# 3) AUR (revisar PKGBUILD antes; paru pregunta)
paru -S --needed rbw rofi-rbw carapace-bin cliphist wl-clipboard \
  ttf-maple-mono-nf bibata-cursor-theme

# 4) Seguridad: solo herramientas elegidas, nunca el grupo completo
paru -S --needed nmap ffuf nuclei sqlmap hashcat john hydra impacket \
  netexec bloodhound certipy enum4linux-ng
```
**Exportar/restaurar tu sistema:**
```bash
pacman -Qqen > pkglist-official.txt
pacman -Qqem > pkglist-aur.txt
# restaurar:
sudo pacman -S --needed - < pkglist-official.txt
paru -S --needed - < pkglist-aur.txt
```
**Regla final:** si un paquete del catálogo no se puede verificar o no tiene mantenimiento, **no se instala**. La lista es una biblioteca de opciones, no una obligación.

---

## 22. Cierre: checklist del agente antes de decir "listo"

- [ ] Leí AGENTS.md completo y el estado del repo.
- [ ] No toqué configs existentes sin backup/consentimiento.
- [ ] Verifiqué cada paquete nuevo en repos/AUR.
- [ ] El cambio es idempotente y tiene rollback.
- [ ] Probé en container/VM; no solo en mi cabeza.
- [ ] Linters/tests pasan; no hay secretos.
- [ ] Actualicé catálogo, CHANGELOG y docs.
- [ ] Respeté GPL-3.0 y créditos.
- [ ] La experiencia sigue siendo keyboard-first, accesible y rápida.
- [ ] Reporté qué cambió, cómo se probó y cómo revertir.

**Mantra:** *"Si no se puede instalar sin miedo, actualizar sin dolor y revertir sin drama, todavía no es Archway."*
