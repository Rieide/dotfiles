# Dotfiles

Personal dotfiles managed with GNU Stow.

This repository is meant to be a portable description of my day-to-day Linux
development environment. It is not a distribution-neutral installer, a framework,
or a fully automated machine image. The goal is to keep common configuration in
Git, keep machine-specific state local, and make each part understandable enough
to change deliberately.

## Current Scope

The repository currently tracks the common parts of my daily Linux development
environment:

- `zsh` as the interactive shell
- `tmux` as the terminal multiplexer
- `starship` as the shell prompt
- `nvim` as an active Neovim configuration package, based on kickstart.nvim and
  grown through explicit plugin choices instead of carrying LazyVim wholesale
- shell-adjacent CLI tools such as `fzf`, `zoxide`, `eza`, `bat`, `ripgrep`,
  `direnv`, `delta`, and `gitleaks`
- reusable templates, currently including a personal `clang-format` style
- a best-effort bootstrap script for installing the current preferred toolset and
  stowing selected packages

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

starship/
└── .config/
    └── starship.toml

nvim/
├── README.md
└── .config/
    └── nvim/
        ├── init.lua
        ├── lazy-lock.json
        └── lua/
```

Shared configuration belongs in the stowed package. Local configuration belongs
outside the repository.

Not every top-level directory is a Stow package. `templates/` contains files
that are copied into a project only when needed, such as:

```text
templates/
├── clang-format/
│   └── personal.clang-format
└── editorconfig/
    └── project.editorconfig
```

The Neovim package has its own short notes in `nvim/README.md`.

## Shared vs Local Configuration

The main rule is:

- shared behavior goes into this repository
- machine identity, secrets, private paths, proxy settings, and temporary local
  experiments stay out of Git

For zsh, the shared file is stowed as `~/.zshrc`. It may source a local override
such as `~/.zshrc.local`, which is intentionally not committed.

For Git, the stowed `~/.gitconfig` contains a public fallback identity that is
safe to use in public repositories. It includes `~/.gitconfig.local` afterward,
so a machine can select a private identity conditionally without committing it.
For example, a development machine can keep the identity itself in
`~/.gitconfig.work` and route repositories under a dedicated work directory to
it from `~/.gitconfig.local`:

```gitconfig
[includeIf "gitdir:~/work/company/"]
	path = ~/.gitconfig.work
```

Because the condition matches every repository below that directory, any public
repository kept there needs an explicit repository-local public identity as an
exception. Private identity files and the exact work-directory rules remain
machine-local.

On first adoption, Stow will not overwrite an existing regular
`~/.gitconfig`. Back it up, move private or machine-specific values into local
files, and only then stow the `git` package. The bootstrap deliberately leaves
that conflict visible instead of guessing how to migrate private identity.

The Git package also stows a `prepare-commit-msg` hook and an identity checker.
Before Git creates a commit, the checker resolves both author and committer via
`git var`, selects the public or work profile from the repository path, and
rejects local config, command-line, or environment overrides that do not match.
The work root is recorded only in `~/.gitconfig.local` as `identity.workRoot`.
Private policy files must be regular files owned by the current user with mode
`0600`.

A separate global `pre-commit` hook runs
`gitleaks protect --staged --redact` before every commit. It scans only staged
content, fails closed if Gitleaks is unavailable, and leaves full-history scans
as an explicit manual or CI task. `git commit --no-verify` bypasses this standard
pre-commit hook, but it does not bypass the `prepare-commit-msg` identity check.

This is a guardrail, not a security boundary against the account owner. A user
or process with permission to change Git configuration can replace
`core.hooksPath`, modify the checker, or otherwise bypass local hooks. Review
configuration changes before use and enforce identity policy on the remote when
it must be non-bypassable.

Run the isolated regression suite after changing the identity policy or hook:

```sh
./scripts/test-git-identity-security.sh
```

It creates disposable public and work-profile repositories, confirms expected
commits, attempts common identity overrides, verifies private-file permissions,
and demonstrates the documented `core.hooksPath` local-bypass boundary.

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

### Keep the Installer Best-Effort and Auditable

The installer has a different job from the shell config.

Shell config is defensive. The installer is best-effort and auditable.

The installer should install the current preferred toolset in a best-effort way.
Failures should be loud and auditable in the log, but they should not abort later
steps that could still succeed. This keeps the bootstrap comfortable: one missing
package or temporary network failure should not prevent unrelated tools or Stow
links from being applied.

This repository follows a "current machines, current tools" model. The current
Linux target is Ubuntu 26.04; older releases such as Ubuntu 20.04 are out of
scope unless support is added deliberately later.

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
- record failures loudly, summarize them at the end, and keep going
- leave local/private configuration manual

It is not intended to be a compatibility layer for every Linux release. When a
step fails on a machine, the expected workflow is to inspect the log, fix the
machine or the script intentionally, and rerun the bootstrap. Successful earlier
and later steps should remain useful.

## Ubuntu 26.04 Package Expectations

The bootstrap script expects Ubuntu 26.04 apt sources to provide the base CLI
set directly:

```text
ca-certificates curl direnv fd-find fzf git gnupg neovim ripgrep stow tmux wget zsh
```

It also tries preferred apt packages when they are available:

```text
bat git-delta zsh-autosuggestions
```

Some tools are intentionally installed outside the default Ubuntu archive:

- `starship` uses the official install script.
- `zoxide` uses the upstream install script.
- `eza` uses the official eza Debian/Ubuntu repository.

Package names and command names are not always identical on Ubuntu. The script
verifies `fd-find` as `fdfind`, `bat` as `batcat`, and `git-delta` as `delta`.
When `--skip-remote` is used, remote-only tools are not installed or verified.

## Roadmap

`TODO.md` is the working roadmap. It tracks completed base shell work, deferred
tools, installer feedback, Git configuration plans, and the future Neovim
migration.

The roadmap should stay close to the current state of the repository. When a
tool is added, deferred, or moved out of scope, the roadmap should say so.
