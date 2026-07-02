# Dotfiles

Personal dotfiles managed with GNU Stow.

This repository is meant to be a portable description of my day-to-day Linux
development environment. It is not a distribution-neutral installer, a framework,
or a fully automated machine image. The goal is to keep common configuration in
Git, keep machine-specific state local, and make each part understandable enough
to change deliberately.

## Current Scope

The repository currently focuses on a small base environment:

- `zsh` as the interactive shell
- `tmux` as the terminal multiplexer
- shell-adjacent CLI tools such as `fzf`, `zoxide`, `eza`, `bat`, `ripgrep`,
  `direnv`, `starship`, `gh`, and `delta`
- a first-pass bootstrap script for installing the current preferred toolset and
  stowing selected packages

The Neovim configuration is intentionally tracked as a future migration project.
The plan is to move from an existing LazyVim setup toward a personal
kickstart.nvim-based configuration by choosing plugins through actual use instead
of copying a black-box distribution wholesale.

## Repository Shape

Each top-level package is arranged as a tree rooted at `$HOME`, following the
normal Stow model.

For example:

```text
zsh/
└── .zshrc

tmux/
└── .config/
    └── tmux/
        └── tmux.conf
```

Shared configuration belongs in the stowed package. Local configuration belongs
outside the repository.

## Shared vs Local Configuration

The main rule is:

- shared behavior goes into this repository
- machine identity, secrets, private paths, proxy settings, and temporary local
  experiments stay out of Git

For zsh, the shared file is stowed as `~/.zshrc`. It may source a local override
such as `~/.zshrc.local`, which is intentionally not committed.

This split should stay boring and explicit. A new machine should be able to use
the shared config immediately, while still leaving room for host-specific fixes
without branching the repository.

## Design Principles

### Prefer Understandable Configuration

Configuration should be readable without knowing a large framework. Small
helpers, explicit conditionals, and standard tool conventions are preferred over
heavy shell frameworks or hidden plugin behavior.

### Keep Shell Startup Defensive

Shell configuration should not assume every optional tool exists. If a command is
missing, the shell should still start cleanly.

This means shared shell config should generally use guarded initialization:

```sh
command -v tool >/dev/null 2>&1 && ...
```

The config can take advantage of modern tools, but it should not make login or
interactive shell startup fragile.

### Keep the Installer Assertive

The installer has a different job from the shell config.

Shell config is defensive. The installer is assertive.

The installer should install the current preferred toolset, fail loudly when that
cannot be done, and write logs that make the failure easy to inspect. It should
not silently downgrade tools, hide errors, or try to support every old
distribution release.

This repository follows a "current machines, current tools" model. Older systems
may require manual repair after reading the installer log.

### Do Not Automate Private State

The bootstrap process should not create secrets, tokens, SSH keys, or
machine-local override files. Those are manual responsibilities.

The installer may install tools and run Stow. It should not guess private
identity or environment-specific policy.

### Avoid Long-Lived Machine Branches

Different machines should not normally be represented by long-lived Git branches.
Branches are for development. Machine differences should be represented by local
override files or, if they grow large enough, optional Stow packages.

This keeps common improvements flowing through one main history.

## Bootstrap Philosophy

`install.sh` is intended to be a pragmatic bootstrap helper:

- install the current preferred tools
- run Stow for selected packages
- log what happened
- fail loudly on errors
- leave local/private configuration manual

It is not intended to be a compatibility layer for every Linux release. When it
fails on a machine, the expected workflow is to inspect the log, fix the machine
or the script intentionally, and record the lesson in the roadmap.

## Roadmap

`TODO.md` is the working roadmap. It tracks completed base shell work, deferred
tools, installer feedback, Git configuration plans, and the future Neovim
migration.

The roadmap should stay close to the current state of the repository. When a
tool is added, deferred, or moved out of scope, the roadmap should say so.
