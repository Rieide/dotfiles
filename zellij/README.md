# Zellij

This package keeps Zellij and tmux available side by side. Zellij is configured for
new sessions; existing sessions keep their current configuration until restarted.

## Install and ownership

Zellij is installed by `install.sh` through Cargo. The installer keeps the
version at or above the tracked minimum before applying this package from the
repository root:

```sh
./install.sh --install-only
./install.sh --stow-only
```

The active `~/.config/zellij/config.kdl` is the Stow link to this package. The
runtime wrapper writes only `~/.local/state/zellij/runtime-config.kdl`, which
adds the selected theme family and any detected desktop clipboard provider.

## Themes

The package includes two automatic light/dark pairs:

- `kanagawa`: `kanagawa-dark` and `kanagawa-light`
- `deepseek`: `deepseek-dark` and `deepseek-light`

Select the family for new sessions:

```sh
zellij-theme-family kanagawa
zellij-theme-family deepseek
```

The choice is stored in `~/.local/state/zellij/theme-family`. The terminal's
reported palette selects the dark or light member of the pair. Existing sessions
are intentionally unchanged.

The top tab bar uses `zjstatus` only for the tab list and displays plain numeric
labels such as `1 nvim` and `2 shell`. The bottom bar remains Zellij's native
`status-bar`, so its mode-specific which-key hints remain available without a
second manually maintained keybind list.

## Modes and bindings

New sessions start in Zellij's native Locked mode. Zellij's native modes remain
available through their normal bindings and which-key help. Press `Ctrl-a` in any
non-Prefix mode to enter the custom `tmux` Prefix mode; each Prefix action returns
to Locked mode unless it enters a native mode such as scroll mode.

| Prefix binding | Action |
| --- | --- |
| `Ctrl-a \\` | Split pane to the right |
| `Ctrl-a -` | Split pane below |
| `Ctrl-a c` | Create a tab |
| `Ctrl-a w` | Open the native session manager |
| `Ctrl-a space` | Cycle the pane layout |
| `Ctrl-a \"` / `%` | Legacy tmux split aliases |
| `Ctrl-a ,` | Rename the current tab using Zellij's native rename mode |
| `Ctrl-a h/j/k/l` | Focus the adjacent pane |
| `Ctrl-a o` | Focus the next pane |
| `Ctrl-a x` | Close the focused pane |
| `Ctrl-a &` | Close the current tab |
| `Ctrl-a d` | Detach from the session |
| `Ctrl-a H/J/K/L` | Resize the pane |
| `Ctrl-a n/p` | Next/previous tab |
| `Ctrl-a Tab` | Toggle between tabs |
| `Ctrl-a 1..9/0` | Jump to tab 1..10 |
| `Ctrl-a z` | Toggle fullscreen for the focused pane |
| `Ctrl-a S` | Toggle synchronized input for the active tab |
| `Ctrl-a [` | Enter Zellij scroll mode |
| `Ctrl-a g` | Open lazygit in a floating pane |
| `Ctrl-a Ctrl-p` | Open a temporary login shell in a floating pane |
| `Ctrl-a Ctrl-f` | Open the project/session picker |
| `Ctrl-a Ctrl-s` | Save session state immediately |
| `Ctrl-a Ctrl-a` | Send `Ctrl-a` to the focused pane |

The Zellij status bar, mode indicators, pane frames and visual bell provide the
state feedback instead of reproducing tmux's status strings exactly.

## Sessions and projects

Outside Zellij, running bare `zellij` reconnects to the session stored in
`~/.local/state/zellij/last-session`. If no remembered session exists, the
wrapper attaches to the only available session, creates a persistent `main`
session when none exist, or uses fzf to choose which of multiple sessions to
remember. Explicit local `attach`/named-session launches and selections made by
`zellij-session-picker` update the same state file. This also resurrects an
exited serialized session without automatically running its saved commands.
Switches made only through Zellij's native session manager cannot be observed by
the wrapper; use the `Ctrl-a Ctrl-f` picker when the remembered target must
follow a session switch exactly.

`zellij-session-picker` replaces sesh only in the Zellij workflow. It combines
active Zellij sessions, the current directory and directories known by zoxide,
then uses fzf for selection. Existing sessions are switched to directly. A
selected directory creates a detached session with a sanitized, path-derived
name before switching to it. The picker never evaluates selected text as shell
code and does not require hardcoded project paths.

The tmux sesh popup remains available as a separate fallback workflow.

## Clipboard

Mouse and scroll selections use Zellij's native OSC 52 path when no desktop
provider is available. For new sessions started in a desktop environment, the
wrapper configures `zellij-copy`, which chooses:

1. Wayland `wl-copy` when `$WAYLAND_DISPLAY` is set;
2. X11 `xclip -selection clipboard` when `$DISPLAY` is set;
3. native OSC 52 when neither provider is configured by the wrapper.

## Persistence

Session serialization and pane viewport serialization are enabled. Zellij keeps
50,000 scrollback lines and serializes up to 50,000 viewport lines every 600
seconds. The Prefix save binding requests an immediate serialization. Restored
sessions keep tabs, pane layout, working directories and supported commands;
process restoration remains subject to Zellij's own command discovery behavior.

## Neovim and proxy integration

The existing `<C-h/j/k/l>` mappings work in both multiplexers:

- inside tmux, `vim-tmux-navigator` and the zoom-aware tmux helper remain active;
- inside Zellij, Neovim moves through its own splits first, then calls
  `zellij action move-focus` at an edge.

Zsh synchronizes GNOME's manual system proxy into both tmux and Zellij panes.
Set `MULTIPLEXER_SYSTEM_PROXY_SYNC=0` in `~/.zshrc.local` to disable it. The
older `TMUX_SYSTEM_PROXY_SYNC` variable remains accepted for existing tmux-only
local overrides.

In Locked mode, `vim-zellij-navigator` handles `Ctrl-h/j/k/l` before the focused
application receives the key. It detects Neovim in the focused pane and forwards
the key so Neovim can move through its own windows; at an editor edge, Neovim's
mapping calls `zellij action move-focus`. For shell and Codex panes, the plugin
consumes the key and moves Zellij focus directly. This mirrors tmux's
process-aware `is_vim` bindings without switching Zellij modes on focus events.
In Normal-mode shell panes, the zsh widgets retain their existing empty-line
navigation behavior. Zellij's `Ctrl-g` Locked/Normal toggle is unchanged.
The navigator is preloaded in the background when a session starts, avoiding a
race on the first navigation key. A fresh installation opens Zellij's permission
prompt once; grant it before using the configured bindings.

## Differences from tmux

Zellij tabs replace tmux windows, while Zellij's native tab navigation remains
available alongside the Prefix number bindings. Zellij's own session manager,
serialization and mode UI replace tmux-resurrect/continuum status text and TPM
runtime behavior. tmux is not removed, and its existing configuration, plugins,
sesh popup and persistence remain independently usable.
