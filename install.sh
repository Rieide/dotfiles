#!/usr/bin/env bash
set -Eeuo pipefail

# Personal dotfiles bootstrap.
#
# Philosophy:
# - zsh config is defensive: missing tools must not break shell startup.
# - this installer is best-effort: install everything that can be installed.
# - failures must be loud and auditable in the log, but should not block later steps.
# - no old-distro compatibility fallbacks; tune for the current target OS.
# - secrets and machine-local files stay manual.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

export PATH="${HOME}/.local/bin:${PATH}"

DO_INSTALL=1
DO_STOW=1
DRY_RUN=0
SKIP_REMOTE=0
INSTALL_FAILURES=()

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
  starship
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
  - Targets the current preferred Ubuntu release, presently Ubuntu 26.04.
  - Installs best-effort: failures are logged loudly and later steps continue.
  - Writes a log under ~/.local/state/dotfiles/.
  - Runs Stow only for packages whose required command is available afterward.
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

command_string() {
  local rendered=""
  local part

  for part in "$@"; do
    printf -v part '%q' "${part}"
    rendered+="${part} "
  done

  printf '%s\n' "${rendered% }"
}

record_failure() {
  local message="$1"
  INSTALL_FAILURES+=("${message}")
  warn "${message}; continuing"
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

try_run() {
  local rendered
  rendered="$(command_string "$@")"

  if run "$@"; then
    return 0
  fi

  record_failure "Command failed: ${rendered}"
  return 0
}

try_run_shell() {
  local command_text="$*"

  if run_shell "$@"; then
    return 0
  fi

  record_failure "Command failed: ${command_text}"
  return 0
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || record_failure "Missing expected command after install: $1"
}

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    record_failure "Cannot detect OS: /etc/os-release is missing"
    return 0
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]; then
    log "Detected target OS: Ubuntu 26.04"
  else
    warn "This installer is tuned for Ubuntu 26.04; detected ${PRETTY_NAME:-unknown OS}. Continuing without compatibility guarantees"
  fi
}

install_available_apt_packages() {
  local group="$1"
  shift

  local pkg
  for pkg in "$@"; do
    if ! apt-cache show "${pkg}" >/dev/null 2>&1; then
      record_failure "Skipping ${group} apt package unavailable in current apt sources: ${pkg}"
      continue
    fi

    try_run sudo apt install -y "${pkg}"
  done
}

install_apt_packages() {
  log "Updating apt package metadata"
  try_run sudo apt update

  log "Installing base apt packages"
  install_available_apt_packages "base" "${APT_BASE_PACKAGES[@]}"

  log "Installing preferred apt packages"
  install_available_apt_packages "preferred" "${APT_PREFERRED_PACKAGES[@]}"
}

install_starship() {
  log "Installing starship"
  try_run_shell 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
}

install_zoxide() {
  log "Installing zoxide"
  try_run_shell 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
}

install_eza_repo() {
  log "Installing eza from the official eza Debian/Ubuntu repository"
  try_run sudo mkdir -p /etc/apt/keyrings
  try_run_shell 'wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/gierens.gpg >/dev/null'
  try_run_shell 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null'
  try_run sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  try_run sudo apt update
  try_run sudo apt install -y eza
}

install_gh_repo() {
  log "Installing gh from the official GitHub CLI apt repository"
  try_run sudo mkdir -p -m 755 /etc/apt/keyrings
  try_run_shell 'wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null'
  try_run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  try_run sudo mkdir -p -m 755 /etc/apt/sources.list.d
  try_run_shell 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null'
  try_run sudo apt update
  try_run sudo apt install -y gh
}

verify_tools() {
  log "Verifying expected commands"

  local required_commands=(
    curl
    direnv
    fdfind
    fzf
    git
    gpg
    rg
    stow
    tmux
    wget
    zsh
  )

  local preferred_commands=(
    batcat
    delta
  )

  local remote_commands=(
    eza
    gh
    starship
    zoxide
  )

  local cmd
  for cmd in "${required_commands[@]}"; do
    check_cmd "${cmd}"
  done

  for cmd in "${preferred_commands[@]}"; do
    check_cmd "${cmd}"
  done

  if [[ "${SKIP_REMOTE}" -eq 1 ]]; then
    warn "Skipping remote tool verification"
  else
    for cmd in "${remote_commands[@]}"; do
      check_cmd "${cmd}"
    done
  fi
}

stow_command_for_package() {
  case "$1" in
    tmux)
      printf "%s\n" tmux
      ;;
    zsh)
      printf "%s\n" zsh
      ;;
    *)
      printf "%s\n" "$1"
      ;;
  esac
}

stow_dotfiles() {
  log "Stowing dotfile packages"
  cd "${ROOT_DIR}"

  if ! command -v stow >/dev/null 2>&1; then
    record_failure "Cannot stow dotfiles: stow command is missing"
    return 0
  fi

  local package
  local required_command
  local packages_to_stow=()

  for package in "${STOW_PACKAGES[@]}"; do
    required_command="$(stow_command_for_package "${package}")"
    if command -v "${required_command}" >/dev/null 2>&1; then
      packages_to_stow+=("${package}")
    else
      record_failure "Skipping stow package ${package}: missing command ${required_command}"
    fi
  done

  if [[ "${#packages_to_stow[@]}" -eq 0 ]]; then
    warn "No stow packages available to link"
    return 0
  fi

  try_run stow --target="${HOME}" --no-folding "${packages_to_stow[@]}"
}

summarize_failures() {
  if [[ "${#INSTALL_FAILURES[@]}" -eq 0 ]]; then
    log "Dotfiles bootstrap completed without recorded failures"
    return 0
  fi

  warn "Dotfiles bootstrap completed with ${#INSTALL_FAILURES[@]} recorded failure(s). Review log: ${LOG_FILE}"

  local failure
  for failure in "${INSTALL_FAILURES[@]}"; do
    printf '  - %s\n' "${failure}" | tee -a "${LOG_FILE}" >&2
  done
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

  summarize_failures
}

main "$@"
