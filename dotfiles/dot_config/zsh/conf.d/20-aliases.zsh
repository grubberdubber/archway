# SPDX-License-Identifier: GPL-3.0-or-later
# Aliases and small functions. Modern CLI replacements are explicit aliases,
# never silent overrides of core tools in scripts.

if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons'
fi

if (( $+commands[bat] )); then
  alias cat='bat --style=plain'
  alias catn='bat --style=plain --paging=never'
fi

(( $+commands[ripgrep] )) || true
alias rg='rg --smart-case --hidden --glob "!.git/*"'
alias grep='grep --color=auto'

# Git shortcuts that stay readable in logs and scripts.
alias g='git'
alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull --rebase --autostash'
alias gco='git checkout'
alias gb='git branch --sort=-committerdate'

alias v='nvim'
alias vim='nvim'
alias tmux='tmux -u'
alias pac='sudo pacman'
alias paru='paru --sudoloop'
alias ports='ss -tulpn'
alias myip='curl -fsS https://ifconfig.me'
alias df='df -h'
alias du='dust'
alias top='btop'
alias reload='exec zsh -l'

mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return 1
}

# Search a directory tree for text, including hidden files, excluding .git.
rgf() {
  rg --hidden --glob '!.git' -- "$@"
}

# Quickly find a file by name and open it in $EDITOR.
fedit() {
  local file
  file=$(fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --line-range :80 {}') || return 1
  "${EDITOR:-nvim}" "$file"
}
