# ~/.zshrc - zsh configuration (stow package: zsh -> ~/.zshrc)
#
# Keep this file safe to publish. Machine-specific paths, private tokens,
# work setup, and generated init blocks belong in ~/.zshrc.local.

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
# install.sh writes generated completions (including sesh) here. Add the
# user-owned directory before compinit builds its function index.
[[ -d "${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions" ]] && \
  fpath=("${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions" $fpath)
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

# Tool compatibility
command -v batcat >/dev/null 2>&1 && alias bat="batcat"
command -v fdfind >/dev/null 2>&1 && alias fd="fdfind"

# Modern ls, if installed
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -al --group-directories-first --git"
  alias la="eza -a --group-directories-first"
  alias tree="eza --tree --group-directories-first"
fi

# fzf key bindings and completion
if [[ -t 0 && -t 1 ]]; then
  [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
  [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# Inline history suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Smarter directory jumping
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Per-project environment loading
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# Better shell history, if installed
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

# Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  PROMPT="%F{green}%n@%m%f:%F{blue}%~%f%# "
fi

# Local overrides, loaded last and never committed.
[[ -r "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
