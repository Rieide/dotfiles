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
- `git` as a shared public configuration with Delta, identity enforcement, and
  staged secret scanning
- `lazygit` as the terminal Git UI used directly, through tmux, and from Neovim
- shell-adjacent CLI tools such as `fzf`, `zoxide`, `sesh`, `eza`, `bat`,
  `ripgrep`, `direnv`, `delta`, and `gitleaks`
- reusable templates, currently including a personal `clang-format` style
- a best-effort bootstrap script for installing the current preferred toolset and
  stowing selected packages

## Repository Shape

Each top-level package is arranged as a tree rooted at `$HOME`, following the
normal Stow model.

For example:

```text
git/
├── .gitconfig
├── .config/git/hooks/
│   ├── pre-commit
│   └── prepare-commit-msg
└── .local/bin/git-identity-check

lazygit/
└── .config/lazygit/config.yml

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

## Bootstrap

The supported target is Ubuntu 26.04 Linux. The installer assumes that target;
it does not implement backward-compatibility branches. Review the planned
operations before the first real run:

```sh
./install.sh --dry-run
./install.sh
```

Every run first inventories expected package versions, executable paths, and
providers. Already-satisfied entries are skipped. A real run installs only the
missing eligible entries, then applies each Stow package independently. It may
request sudo authentication. Logs are written to:

```text
~/.local/state/dotfiles/install-YYYYMMDD-HHMMSS.log
```

Useful scoped modes are:

```sh
./install.sh --install-only
./install.sh --stow-only
./install.sh --skip-remote
```

Stow deliberately refuses to replace an existing regular file. Back up and
review any conflict instead of using `--adopt` without understanding which copy
should become authoritative.

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
content when Gitleaks is installed, emits a visible skip warning when the
preferred tool is unavailable, and leaves full-history scans as an explicit
manual or CI task. `git commit --no-verify` bypasses this standard pre-commit
hook, but it does not bypass the `prepare-commit-msg` identity check.

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

## Git Workflow

Delta is the preferred Git pager, with the Nord syntax theme, line numbers,
navigation, and side-by-side output. A tracked wrapper falls back to `less` or
`cat` when Delta is not installed, so the preferred tool can remain optional.
It is used automatically by commands such as:

```sh
git diff
git staged
git show HEAD
git log -p
git blame path/to/file
```

Lazygit uses Neovim as its editor and the same Delta-with-fallback wrapper as
its diff pager. The configured entry points are:

```text
terminal: lazygit
tmux:     prefix + g
Neovim:  <Space>gg
```

When Gitleaks is available, the global hook checks staged content automatically.
Ubuntu 26.04 currently packages the older Gitleaks command interface, so manual
scans use:

```sh
# Current files only
gitleaks detect --no-git --redact --source .

# Complete Git history
gitleaks detect --redact --source .
```

The pre-commit scan prevents accidental leaks but remains a local guardrail. A
missing Gitleaks binary skips the scan with a warning, and `git commit
--no-verify` bypasses it explicitly. The separate identity hook still runs for
`--no-verify` commits.

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

### Keep the Installer State-Aware, Best-Effort, and Auditable

The installer has a different job from the shell config.

Shell config is defensive. The installer is state-aware, best-effort, and
auditable.

Before changing the machine, the installer checks whether every expected package
or command is already present and whether declared version/provider constraints
are satisfied. Satisfied entries are preserved. Failures should be loud and
auditable in the final table, but they should not abort later independent work.
One missing package, source conflict, or temporary network failure must not
prevent unrelated tools or Stow links from being applied.

This repository follows a "current machines, current tools" model. The current
Linux target is Ubuntu 26.04. A non-target system may attempt the same preferred
installation steps, but that behavior is not compatibility-tested or guaranteed.
The script does not add compatibility PPAs, compile source, or substitute an
unintended provider; failed summary items are resolved manually and then the
installer can be rerun.

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

- inventory every expected package/tool before installation
- skip existing tools that satisfy version and provider policy
- install eligible missing tools using the Ubuntu 26.04 target assumptions
- run Stow independently for selected packages
- log what happened
- print `SKIPPED`, `INSTALLED`, `PLANNED`, and `FAILED` results in a final table
- leave local/private configuration manual

It is not intended to be a compatibility layer for every Linux release. When a
step fails on a machine, the expected workflow is to inspect the log, fix the
machine or the script intentionally, and rerun the bootstrap. Successful earlier
and later steps should remain useful.

## Ubuntu 26.04 Package Expectations

Required apt packages are limited to bootstrap/system dependencies:

```text
ca-certificates curl gnupg stow wget zsh
```

User-facing tools are preferred rather than bootstrap-critical. On Ubuntu 26.04,
the script may install these from apt when their candidate version satisfies the
declared minimum:

```text
bat direnv fd-find fzf git git-delta gitleaks lazygit ripgrep tmux zsh-autosuggestions
```

Some tools are intentionally installed outside the default Ubuntu archive:

- `nvim` uses Snap `latest/stable` with classic confinement and must be at least
  version 0.11; the script will not install an apt replacement. The installer
  and tracked Zsh configuration put `/snap/bin` ahead of system apt binaries.
- `starship` uses the official install script.
- `zoxide` uses the upstream install script.
- `eza` uses the official eza Debian/Ubuntu repository.
- `sesh` uses a pinned official Linux x86_64 release archive, verifies its
  SHA256, installs the binary under `~/.local/bin`, and generates Zsh completion.

The tmux plugins TPM, tmux-sensible, tmux-resurrect, tmux-continuum, and
vim-tmux-navigator are cloned from their official repositories and checked out
at commits pinned in `install.sh`. Dirty or unexpected-source plugin directories
are reported without being overwritten. See `tmux/README.md` for the complete
tmux installation and maintenance workflow.

The tracked configuration also requires Git 2.35 or newer for `zdiff3` and tmux
3.3 or newer for popup titles and styling. An existing tool from another source
is preserved unless that tool has an explicit provider restriction, as Neovim
does.

Package names and command names are not always identical on Ubuntu. The script
verifies `fd-find` as `fdfind`, `bat` as `batcat`, and `git-delta` as `delta`.
When `--skip-remote` is used, a missing remote-only tool is left as a manual
action in the summary.

## Roadmap

`TODO.md` is the working roadmap. It tracks the current baseline, remaining
reproducibility gaps, and optional workflow enhancements.

The roadmap should stay close to the current state of the repository. When a
tool is added, deferred, or moved out of scope, the roadmap should say so.
