# SPDX-License-Identifier: GPL-3.0-or-later
# Interactive tools: history, navigation, fuzzy finding, prompt.
# Every integration is guarded so a missing binary never breaks the shell.

# History backend: atuin (SQLite, fuzzy Ctrl-R). Sensitive commands are filtered
# in ~/.config/atuin/config.toml, and sync is off unless you enable it.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

if (( $+commands[fzf] )); then
  [[ -r "$ARCHWAY_THEME_DIR/fzf.sh" ]] && source "$ARCHWAY_THEME_DIR/fzf.sh"
  source <(fzf --zsh)
fi

if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi

# sheldon manages plugins declaratively (~/.config/sheldon/plugins.toml).
# Only call it when that file exists: a bare sheldon binary prints a config
# lock error on every shell and would hide the distro fallback below.
if (( $+commands[sheldon] )) && [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/sheldon/plugins.toml" ]]; then
  eval "$(sheldon source)"
else
  # Fallback: distribution packages, loaded lazily enough to stay under 100 ms.
  [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Fast, prefix-aware history search on Ctrl-R when atuin is absent.
if (( ! $+commands[atuin] )); then
  bindkey '^R' history-incremental-search-backward
fi

# Edit the command line in Neovim.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
