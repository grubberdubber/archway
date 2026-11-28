# SPDX-License-Identifier: GPL-3.0-or-later
# Interactive tools: fuzzy finding, history, navigation, prompt.
# Every integration is guarded so a missing binary never breaks the shell.

if (( $+commands[fzf] )); then
  [[ -r "$ARCHWAY_THEME_DIR/fzf.sh" ]] && source "$ARCHWAY_THEME_DIR/fzf.sh"
  source <(fzf --zsh)

  # fzf-tab: Tab completion in the fzf picker, loaded after compinit
  # (10-completion) and after fzf so the theme's colours apply. `menu no` stops
  # zsh from painting its own menu behind the picker.
  _archway_fzf_tab_loaded=0
  for _archway_fzf_tab in \
    /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.zsh \
    /usr/share/zsh/plugins/fzf-tab/fzf-tab.zsh; do
    if [[ -r $_archway_fzf_tab ]]; then
      source "$_archway_fzf_tab"
      zstyle ':completion:*' menu no
      _archway_fzf_tab_loaded=1
      break
    fi
  done
  unset _archway_fzf_tab

  if (( _archway_fzf_tab_loaded )); then
    # Three panes (Search / Results / Preview) with the reference's borders and
    # pointer. Colours are ANSI names, so the active theme decides the hue.
    zstyle ':fzf-tab:*' fzf-flags --style=full --height=90% --pointer '>' --gutter ' ' \
      --color 'pointer:green:bold,bg+:-1:,fg+:green:bold,info:blue:bold,marker:yellow:bold,hl:gray:bold,hl+:gray:bold' \
      --input-label ' Search ' --color 'input-border:blue,input-label:blue:bold' \
      --list-label ' Results ' --color 'list-border:green,list-label:green:bold' \
      --preview-label ' Preview ' --preview-label-pos '27:bottom' --color 'preview-border:magenta,preview-label:magenta:bold'
    if (( $+commands[eza] )); then
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
      zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
    fi
    if (( $+commands[bat] )); then
      zstyle ':fzf-tab:complete:bat:*' fzf-preview 'bat --color=always $realpath'
    fi
    zstyle ':fzf-tab:*' fzf-bindings 'space:accept'
    zstyle ':fzf-tab:*' accept-line enter
  fi
  unset _archway_fzf_tab_loaded
fi

# History backend: atuin (SQLite, fuzzy Ctrl-R). Loaded after fzf on purpose:
# `fzf --zsh` binds Ctrl-R, and atuin must own that key. Sync is off unless you
# enable it; sensitive commands are filtered in ~/.config/atuin/config.toml.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
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
