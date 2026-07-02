#!/usr/bin/env bash
set -Eeuo pipefail

# Personal dotfiles bootstrap.
#
# Philosophy:
# - zsh config is defensive: missing tools must not break shell startup.
# - this installer is assertive: install the current preferred toolset.
# - no old-distro compatibility fallbacks; fail loudly and inspect the log.
# - secrets and machine-local files stay manual.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

export PATH="${HOME}/.local/bin:${PATH}"

DO_INSTALL=1
DO_STOW=1
DRY_RUN=0
SKIP_REMOTE=0

APT_BASE_PACKAGES=(
  ca-certificates
  curl
  direnv
  fd-find
  fzf
  git
  gnupg
  ripgrep
  stow
  tmux
  wget
  zsh
)

APT_PREFERRED_PACKAGES=(
  bat
  git-delta
)

STOW_PACKAGES=(
  tmux
  zsh
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --install-only   Install tools but do not run stow
  --stow-only      Run stow but do not install tools
  --skip-remote    Skip remote installers and third-party apt repositories
  --dry-run        Print commands without executing them
  -h, --help       Show this help

Behavior:
  - Targets current Ubuntu/Debian-like machines.
  - Fails loudly instead of silently downgrading or hiding missing packages.
  - Writes a log under ~/.local/state/dotfiles/.
  - Leaves secrets and ~/.zshrc.local manual.
EOF
}

log() {
  printf '\n==> %s\n' "$*" | tee -a "${LOG_FILE}"
}

warn() {
  printf '\nWARNING: %s\n' "$*" | tee -a "${LOG_FILE}" >&2
}

die() {
  printf '\nERROR: %s\n' "$*" | tee -a "${LOG_FILE}" >&2
  exit 1
}

run() {
  {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "${LOG_FILE}"

  if [[ "${DRY_RUN}" -eq 0 ]]; then
    "$@" 2>&1 | tee -a "${LOG_FILE}"
    return "${PIPESTATUS[0]}"
  fi
}

run_shell() {
  printf '+ %s\n' "$*" | tee -a "${LOG_FILE}"

  if [[ "${DRY_RUN}" -eq 0 ]]; then
    bash -c "$*" 2>&1 | tee -a "${LOG_FILE}"
    return "${PIPESTATUS[0]}"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command after install: $1"
}

detect_os() {
  [[ -r /etc/os-release ]] || die "cannot detect OS: /etc/os-release is missing"
  # shellcheck disable=SC1091
  source /etc/os-release

  case "${ID:-}" in
    ubuntu|debian)
      ;;
    *)
      die "unsupported OS '${ID:-unknown}'. This installer currently targets Ubuntu/Debian."
      ;;
  esac
}

install_apt_packages() {
  log "Installing base apt packages"
  run sudo apt update
  run sudo apt install -y "${APT_BASE_PACKAGES[@]}"

  log "Installing preferred apt packages"
  run sudo apt install -y "${APT_PREFERRED_PACKAGES[@]}"
}

install_starship() {
  log "Installing starship"
  run_shell 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
}

install_zoxide() {
  log "Installing zoxide"
  run_shell 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
}

install_eza_repo() {
  log "Installing eza from the official eza Debian/Ubuntu repository"
  run sudo mkdir -p /etc/apt/keyrings
  run_shell 'wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/gierens.gpg >/dev/null'
  run_shell 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null'
  run sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  run sudo apt update
  run sudo apt install -y eza
}

install_gh_repo() {
  log "Installing gh from the official GitHub CLI apt repository"
  run sudo mkdir -p -m 755 /etc/apt/keyrings
  run_shell 'wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null'
  run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  run sudo mkdir -p -m 755 /etc/apt/sources.list.d
  run_shell 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null'
  run sudo apt update
  run sudo apt install -y gh
}

verify_tools() {
  log "Verifying expected commands"

  local commands=(
    batcat
    delta
    direnv
    eza
    fdfind
    fzf
    gh
    git
    rg
    starship
    stow
    tmux
    zoxide
    zsh
  )

  local cmd
  for cmd in "${commands[@]}"; do
    need_cmd "${cmd}"
  done
}

stow_dotfiles() {
  log "Stowing dotfile packages"
  cd "${ROOT_DIR}"
  run stow "${STOW_PACKAGES[@]}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-only)
        DO_INSTALL=1
        DO_STOW=0
        ;;
      --stow-only)
        DO_INSTALL=0
        DO_STOW=1
        ;;
      --skip-remote)
        SKIP_REMOTE=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  mkdir -p "${LOG_DIR}"
  : > "${LOG_FILE}"

  trap 'die "bootstrap failed at line ${LINENO}. Log: ${LOG_FILE}"' ERR

  log "Dotfiles bootstrap started"
  log "Repository: ${ROOT_DIR}"
  log "Log file: ${LOG_FILE}"

  detect_os

  if [[ "${DO_INSTALL}" -eq 1 ]]; then
    install_apt_packages

    if [[ "${SKIP_REMOTE}" -eq 1 ]]; then
      warn "Skipping remote installers and third-party repositories"
    else
      install_starship
      install_zoxide
      install_eza_repo
      install_gh_repo
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
      warn "Dry run: skipping command verification"
    else
      verify_tools
    fi
  fi

  if [[ "${DO_STOW}" -eq 1 ]]; then
    stow_dotfiles
  fi

  log "Dotfiles bootstrap completed"
}

main "$@"
