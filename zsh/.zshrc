# ~/.zshrc - zsh configuration (stow package: zsh -> ~/.zshrc)
#
# Keep this file safe to publish. Machine-specific paths, private tokens,
# work setup, and generated init blocks belong in ~/.zsh.local.

# If not running interactively, do not do anything.
[[ -o interactive ]] || return

# History
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Completion
autoload -Uz compinit
compinit

# Useful shell behavior
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# PATH entries that are safe to share across machines.
[[ -d "${HOME}/bin" ]] && path=("${HOME}/bin" $path)
[[ -d "${HOME}/.local/bin" ]] && path=("${HOME}/.local/bin" $path)
typeset -U path

# Colors and common aliases
autoload -Uz colors
colors

if command -v dircolors >/dev/null 2>&1; then
  [[ -r "${HOME}/.dircolors" ]] && eval "$(dircolors -b "${HOME}/.dircolors")" || eval "$(dircolors -b)"
fi

alias ls="ls --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"

# Simple prompt until a cross-shell prompt such as starship is added.
PROMPT="%F{green}%n@%m%f:%F{blue}%~%f%# "

# Local overrides, loaded last and never committed.
[[ -r "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
