# Git TODO — Ubuntu 26.04 WSL

Continuation checklist for the personal Ubuntu 26.04 WSL baseline.

Fill in observed U26 state on that machine before changing installation logic.
Do not treat versions or availability observed on the Ubuntu 20.04 development
host as U26 facts. Keep names, private email addresses, tokens, work paths, and
authentication files out of this document and out of Git.

---

## 1. Record the U26 baseline

Date checked:

```text
git:
delta:
lazygit:
gh:
gh authentication:
gitleaks:
git-lfs:
git-filter-repo:
nvim:
```

Useful read-only checks:

```sh
git --version
delta --version
lazygit --version
gh --version
gh auth status
gitleaks version
git lfs version
git filter-repo --version
nvim --version
```

- [ ] Record the installed versions above without copying private identity or
      authentication output into this file.
- [ ] Confirm whether `git-delta` and `lazygit` are available from the enabled
      Ubuntu 26.04 apt sources.
- [ ] Record any package-name/command-name differences found on U26.

---

## 2. Protect Git identity before testing commits

The stowed public Git configuration should be safe on the personal U26 machine
without a private override. Do not copy the U20 development machine's private
identity files to U26.

- [ ] Confirm `~/.gitconfig` is a Stow link to this repository's
      `git/.gitconfig`.
- [ ] Leave `~/.gitconfig.local` and `~/.gitconfig.work` absent unless U26 has a
      real need for another identity.
- [ ] Confirm a new test repository outside any private work root selects the
      public profile.
- [ ] Run the identity checker in this repository:

  ```sh
  ~/.local/bin/git-identity-check .
  ```

- [ ] Run the isolated malicious-override regression suite:

  ```sh
  ./scripts/test-git-identity-security.sh
  ```

- [ ] Confirm the suite rejects local config, malicious include, command-line,
      environment, `--author`, `--no-verify`, weak-permission, and symlink
      override attempts.
- [ ] Remember that a command-level `core.hooksPath` override can bypass a
      client-side hook; use remote CI or server-side policy if enforcement must
      be non-bypassable.

---

## 3. Delta — required core tool

The shared Git config already uses Delta as `core.pager` and
`interactive.diffFilter`, so Git output is incomplete until the `delta` command
exists.

- [ ] Install `git-delta` from apt if U26 provides it.
- [ ] If apt does not provide a suitable package, use an official release
      package and record the reason here before adding another installer path.
- [ ] Verify the current settings before changing their presentation:

  ```sh
  git config --get core.pager
  git config --get interactive.diffFilter
  git config --get delta.line-numbers
  git config --get delta.navigate
  git config --get delta.side-by-side
  git config --get merge.conflictstyle
  ```

- [ ] Test `git diff`, `git show`, `git log -p`, `git blame`, and interactive
      staging.
- [ ] Test side-by-side output in both a wide terminal and a narrow tmux pane;
      only change the default after observing the U26 result.

---

## 4. Lazygit — required workflow tool

tmux and Neovim already expose Lazygit entry points, so the bootstrap should
install and verify it on U26.

- [ ] Add `lazygit` to the appropriate apt package group in `install.sh`.
- [ ] Add `lazygit` to command verification.
- [ ] Create a Stow package at:

  ```text
  lazygit/.config/lazygit/config.yml
  ```

- [ ] Keep the initial config small: Neovim editor integration, Delta pager,
      and existing safety confirmations.
- [ ] Do not disable force-push, discard, amend, or no-staged-files warnings.
- [ ] Validate all three entry points:

  ```text
  terminal: lazygit
  tmux:     prefix + g
  Neovim:  <leader>gg
  ```

- [ ] Create disposable public-profile commits and confirm the global identity
      guard still runs from Lazygit, including its commit-without-hook action.

---

## 5. GitHub CLI

Installation may be automated, but authentication remains manual and private.

- [ ] Confirm `gh` is installed from the intended source.
- [ ] Authenticate interactively using the SSH Git protocol:

  ```sh
  gh auth login --git-protocol ssh
  ```

- [ ] Check where credentials were stored and verify permissions if the system
      credential store was unavailable.
- [ ] Never commit `GH_TOKEN`, auth files, device codes, or `gh auth status`
      output containing private account details.
- [ ] Validate `gh repo view`, `gh pr status`, and `gh issue status`.

---

## 6. Gitleaks — optional security phase

- [ ] Install the Gitleaks CLI from a trusted official package or release.
- [ ] Run a redacted working-tree scan:

  ```sh
  gitleaks dir --redact .
  ```

- [ ] Run a redacted history scan:

  ```sh
  gitleaks git --redact .
  ```

- [ ] Review false positives before adding `.gitleaks.toml` or
      `.gitleaksignore`.
- [ ] If adopted in the global hook, scan staged content quickly and keep full
      history scanning as a manual or CI task.
- [ ] Do not add pre-commit or Lefthook until their interaction with the shared
      `core.hooksPath` design is explicit.

---

## 7. Diffview.nvim — only after checking Git version

Diffview currently requires Git 2.31 or newer. Do not add it until the U26 Git
version satisfies that requirement.

- [ ] Confirm `git --version` is at least 2.31.
- [ ] Add `sindrets/diffview.nvim` as a dedicated custom plugin module.
- [ ] Add discoverable mappings under the existing `<leader>g` group for:
      current diff, branch comparison, current-file history, repository
      history, and closing Diffview.
- [ ] Validate staged/unstaged changes, renamed-file history, and a disposable
      three-way merge conflict.
- [ ] Confirm Diffview does not duplicate or conflict with Gitsigns, Trouble,
      Lazygit, or the existing `zdiff3` workflow.

---

## 8. Install only when a project needs them

- [ ] Git LFS — adopt only for a repository that actually tracks large binary
      assets; review its filter and pre-push hook interaction first.
- [ ] `git-filter-repo` — install as a recovery tool for deliberate history
      rewrites; never run it as part of bootstrap validation.
- [ ] `git-absorb` — evaluate only after the normal fixup/autosquash workflow
      is familiar.
- [ ] Difftastic — evaluate as an optional difftool, not as a replacement for
      Delta's default pager.

---

## 9. Bootstrap and regression validation

- [ ] Run syntax and repository checks:

  ```sh
  bash -n install.sh
  git diff --check
  ./scripts/test-git-identity-security.sh
  ```

- [ ] Run a U26 dry run with temporary state:

  ```sh
  XDG_STATE_HOME=/tmp/dotfiles-state ./install.sh --dry-run
  ```

- [ ] Run the real bootstrap on U26 and review the generated log.
- [ ] Confirm `delta`, `lazygit`, `gh`, Stow links, tmux popup, and Neovim
      entry points after a fresh shell/login.
- [ ] Confirm no private identity, credential, token, or machine-only config is
      staged before committing.

Suggested commit split:

```text
bootstrap: install git workflow tools
lazygit: add shared configuration
git: add secret scanning
nvim: add diffview git workflow
```

Keep optional phases in separate commits so each can be validated and reverted
independently.
