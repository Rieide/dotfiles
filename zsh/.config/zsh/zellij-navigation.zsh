if [[ -n "${ZELLIJ:-}" ]] && command -v zellij >/dev/null 2>&1; then
  _zellij_navigate_or_widget() {
    local widget="$1"
    local direction="$2"
    if [[ -z "${BUFFER}" && ${CURSOR} -eq 0 ]]; then
      zellij action move-focus "${direction}" >/dev/null 2>&1
      zle reset-prompt
    else
      zle "${widget}"
    fi
  }

  _zellij_navigate_left() { _zellij_navigate_or_widget .backward-delete-char left; }
  _zellij_navigate_down() { _zellij_navigate_or_widget .accept-line down; }
  _zellij_navigate_up() { _zellij_navigate_or_widget .up-line-or-history up; }
  _zellij_navigate_right() { _zellij_navigate_or_widget .forward-char right; }

  zle -N _zellij_navigate_left
  zle -N _zellij_navigate_down
  zle -N _zellij_navigate_up
  zle -N _zellij_navigate_right
  for keymap in emacs viins; do
    bindkey -M "${keymap}" '^h' _zellij_navigate_left
    bindkey -M "${keymap}" '^j' _zellij_navigate_down
    bindkey -M "${keymap}" '^k' _zellij_navigate_up
    bindkey -M "${keymap}" '^l' _zellij_navigate_right
  done
fi
