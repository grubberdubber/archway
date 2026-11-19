# SPDX-License-Identifier: GPL-3.0-or-later
# Completion: initialised once, cached, then augmented by carapace.

autoload -Uz compinit
if [[ -n "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION" &&
  "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION" -nt "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc" ]]; then
  compinit -C -d "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
else
  compinit -d "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/zcompcache"
zstyle ':completion:*' rehash true

# Universal arg: press twice before the command.
autoload -Uz _sudo
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin

# carapace provides completions for hundreds of tools when installed.
if (( $+commands[carapace] )); then
  source <(carapace _carapace zsh)
fi

# History search with the arrow keys stays substring-aware.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
