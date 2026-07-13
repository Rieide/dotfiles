#!/usr/bin/env bash
set -Eeuo pipefail

# Personal dotfiles bootstrap.
#
# Policy:
# - inventory every expected package/tool before making changes;
# - preserve an installed tool only when its version and source satisfy policy;
# - keep independent installation and Stow failures non-blocking;
# - install only for the current target OS; unsupported systems get a manual
#   action in the final summary instead of compatibility fallbacks;
# - distinguish required bootstrap dependencies from preferred user tools.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

export PATH="${HOME}/.local/bin:${PATH}"

DO_INSTALL=1
DO_STOW=1
DRY_RUN=0
SKIP_REMOTE=0
OS_SUPPORTED=0
APT_METADATA_READY=0

TARGET_OS="Ubuntu 26.04"

# Required means required by the bootstrap process itself. User-facing tools are
# preferred so an old/unsupported distribution does not trigger compatibility
# repositories or source builds automatically.
APT_REQUIRED_PACKAGES=(
  ca-certificates
  curl
  gnupg
  stow
  wget
  zsh
)

PREFERRED_ITEMS=(
  direnv
  fd
  fzf
  git
  nvim
  rg
  tmux
  bat
  delta
  gitleaks
  lazygit
  zsh-autosuggestions
  eza
  starship
  zoxide
)

STOW_PACKAGES=(
  git
  lazygit
  nvim
  starship
  tmux
  zsh
)

declare -A ITEM_KIND=(
  [direnv]="apt"
  [fd]="apt"
  [fzf]="apt"
  [git]="apt"
  [nvim]="snap"
  [rg]="apt"
  [tmux]="apt"
  [bat]="apt"
  [delta]="apt"
  [gitleaks]="apt"
  [lazygit]="apt"
  [zsh-autosuggestions]="apt"
  [eza]="remote"
  [starship]="remote"
  [zoxide]="remote"
)

declare -A ITEM_PACKAGE=(
  [direnv]="direnv"
  [fd]="fd-find"
  [fzf]="fzf"
  [git]="git"
  [nvim]=""
  [rg]="ripgrep"
  [tmux]="tmux"
  [bat]="bat"
  [delta]="git-delta"
  [gitleaks]="gitleaks"
  [lazygit]="lazygit"
  [zsh-autosuggestions]="zsh-autosuggestions"
  [eza]="eza"
  [starship]="starship"
  [zoxide]="zoxide"
)

declare -A ITEM_COMMAND=(
  [direnv]="direnv"
  [fd]="fdfind"
  [fzf]="fzf"
  [git]="git"
  [nvim]="nvim"
  [rg]="rg"
  [tmux]="tmux"
  [bat]="batcat"
  [delta]="delta"
  [gitleaks]="gitleaks"
  [lazygit]="lazygit"
  [zsh-autosuggestions]=""
  [eza]="eza"
  [starship]="starship"
  [zoxide]="zoxide"
)

# Only constraints justified by the tracked configuration belong here.
declare -A ITEM_MIN_VERSION=(
  [git]="2.35"
  [nvim]="0.11"
  [tmux]="3.2"
)

# Empty means any existing source is accepted. Installation still follows
# ITEM_KIND. Neovim is intentionally Snap-only to avoid an older apt binary
# shadowing /snap/bin/nvim.
declare -A ITEM_ALLOWED_SOURCES=(
  [nvim]="snap"
)

declare -A ITEM_VERSION_ARGS=(
  [tmux]="-V"
  [gitleaks]="version"
)

declare -a SUMMARY_KEYS=()
declare -A SUMMARY_LABEL=()
declare -A SUMMARY_CLASS=()
declare -A SUMMARY_STATUS=()
declare -A SUMMARY_DETAIL=()
declare -A ITEM_STATE=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --install-only   Install tools but do not run Stow
  --stow-only      Run Stow but do not install tools
  --skip-remote    Skip upstream installers and third-party repositories
  --dry-run        Inventory the machine and print planned commands
  -h, --help       Show this help

Behavior:
  - Targets Ubuntu 26.04.
  - Inventories versions and sources before making changes.
  - Skips already-satisfied packages and tools.
  - Does not add compatibility fallbacks on unsupported operating systems.
  - Continues independent work after a failure and prints a final summary.
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
    bash -o pipefail -c "$*" 2>&1 | tee -a "${LOG_FILE}"
    return "${PIPESTATUS[0]}"
  fi
}

add_summary_item() {
  local key="$1"
  local label="$2"
  local class="$3"

  if [[ -z "${SUMMARY_LABEL[${key}]+x}" ]]; then
    SUMMARY_KEYS+=("${key}")
  fi

  SUMMARY_LABEL["${key}"]="${label}"
  SUMMARY_CLASS["${key}"]="${class}"
  SUMMARY_STATUS["${key}"]="PENDING"
  SUMMARY_DETAIL["${key}"]="not inspected"
}

set_result() {
  local key="$1"
  local status="$2"
  local detail="$3"

  SUMMARY_STATUS["${key}"]="${status}"
  SUMMARY_DETAIL["${key}"]="${detail}"
}

initialize_summary() {
  local package
  local item

  for package in "${APT_REQUIRED_PACKAGES[@]}"; do
    add_summary_item "required:${package}" "${package}" "required"
  done

  for item in "${PREFERRED_ITEMS[@]}"; do
    add_summary_item "tool:${item}" "${item}" "preferred"
  done
}

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    warn "Cannot detect OS: /etc/os-release is missing"
    return 0
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]; then
    OS_SUPPORTED=1
    log "Detected target OS: ${TARGET_OS}"
  else
    warn "Installer target is ${TARGET_OS}; detected ${PRETTY_NAME:-unknown OS}. Preferred tools that need installation will be left for manual setup"
  fi
}

installed_deb_version() {
  local package="$1"
  local result

  result="$(dpkg-query -W -f='${Status}\t${Version}' "${package}" 2>/dev/null || true)"
  if [[ "${result}" == "install ok installed"$'\t'* ]]; then
    printf '%s\n' "${result#*$'\t'}"
  fi
}

candidate_deb_version() {
  local package="$1"
  apt-cache policy "${package}" 2>/dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n 1
}

detect_command_source() {
  local path="$1"

  case "${path}" in
    /snap/bin/*)
      printf '%s\n' snap
      ;;
    "${HOME}"/.local/bin/*)
      printf '%s\n' local
      ;;
    "${HOME}"/miniconda3/*|*/conda/*)
      printf '%s\n' conda
      ;;
    /usr/local/bin/*)
      printf '%s\n' upstream
      ;;
    /usr/bin/*|/bin/*)
      printf '%s\n' apt
      ;;
    *)
      printf '%s\n' other
      ;;
  esac
}

command_version_output() {
  local item="$1"
  local path="$2"
  local args_text="${ITEM_VERSION_ARGS[${item}]:---version}"
  local -a args=()
  local snap_command
  local snap_binary

  read -r -a args <<<"${args_text}"

  # Calling a Snap launcher can fail in restricted/containerized validation
  # even though the installed payload is healthy. Inspect the payload directly
  # while retaining /snap/bin/... as the provider path in the summary.
  if [[ "${path}" == /snap/bin/* ]]; then
    snap_command="${path##*/}"
    snap_binary="/snap/${snap_command}/current/usr/bin/${snap_command}"
    if [[ -x "${snap_binary}" ]]; then
      if [[ "${snap_command}" == "nvim" ]]; then
        NVIM_LOG_FILE=/dev/null "${snap_binary}" "${args[@]}" 2>/dev/null || true
      else
        "${snap_binary}" "${args[@]}" 2>/dev/null || true
      fi
      return 0
    fi
  fi

  "${path}" "${args[@]}" 2>/dev/null || true
}

extract_version() {
  local text="$1"
  grep -Eo '[0-9]+([.][0-9]+)+' <<<"${text}" | head -n 1 || true
}

version_satisfies() {
  local actual="$1"
  local minimum="$2"
  dpkg --compare-versions "${actual}" ge "${minimum}"
}

source_is_allowed() {
  local source="$1"
  local allowed="$2"

  [[ -z "${allowed}" || " ${allowed} " == *" ${source} "* ]]
}

inspect_required_package() {
  local package="$1"
  local version

  version="$(installed_deb_version "${package}")"
  if [[ -n "${version}" ]]; then
    ITEM_STATE["required:${package}"]="satisfied"
    set_result "required:${package}" "SKIPPED" "apt ${version} is already installed"
  else
    ITEM_STATE["required:${package}"]="needs-install"
    set_result "required:${package}" "PENDING" "required apt package is missing"
  fi
}

inspect_preferred_item() {
  local item="$1"
  local kind="${ITEM_KIND[${item}]}"
  local package="${ITEM_PACKAGE[${item}]}"
  local command="${ITEM_COMMAND[${item}]}"
  local minimum="${ITEM_MIN_VERSION[${item}]:-}"
  local allowed_sources="${ITEM_ALLOWED_SOURCES[${item}]:-}"
  local path=""
  local source=""
  local output=""
  local version=""
  local detail=""

  if [[ -z "${command}" ]]; then
    version="$(installed_deb_version "${package}")"
    if [[ -n "${version}" ]]; then
      ITEM_STATE["tool:${item}"]="satisfied"
      set_result "tool:${item}" "SKIPPED" "apt ${version} is already installed"
      return 0
    fi
  elif path="$(command -v "${command}" 2>/dev/null)" && [[ -n "${path}" ]]; then
    source="$(detect_command_source "${path}")"
    output="$(command_version_output "${item}" "${path}")"
    version="$(extract_version "${output}")"
    detail="${path} (${source}${version:+, ${version}})"

    if ! source_is_allowed "${source}" "${allowed_sources}"; then
      ITEM_STATE["tool:${item}"]="failed"
      set_result "tool:${item}" "FAILED" "${detail}; allowed source: ${allowed_sources}; manual action required"
      return 0
    fi

    if [[ -n "${minimum}" && -z "${version}" ]]; then
      ITEM_STATE["tool:${item}"]="failed"
      set_result "tool:${item}" "FAILED" "${detail}; cannot assert minimum ${minimum}"
      return 0
    fi

    if [[ -n "${minimum}" ]] && ! version_satisfies "${version}" "${minimum}"; then
      if [[ "${OS_SUPPORTED}" -eq 1 && "${kind}" == "apt" ]]; then
        ITEM_STATE["tool:${item}"]="needs-install"
        set_result "tool:${item}" "PENDING" "${detail}; minimum ${minimum}; apt upgrade required"
      else
        ITEM_STATE["tool:${item}"]="failed"
        set_result "tool:${item}" "FAILED" "${detail}; minimum ${minimum}; manual upgrade required"
      fi
      return 0
    fi

    ITEM_STATE["tool:${item}"]="satisfied"
    set_result "tool:${item}" "SKIPPED" "${detail} already satisfies policy"
    return 0
  fi

  if [[ "${OS_SUPPORTED}" -eq 0 || "${kind}" == "manual" ]]; then
    ITEM_STATE["tool:${item}"]="failed"
    set_result "tool:${item}" "FAILED" "not installed; manual installation required"
  else
    ITEM_STATE["tool:${item}"]="needs-install"
    set_result "tool:${item}" "PENDING" "not installed; planned source: ${kind}"
  fi
}

inventory_expected_content() {
  log "Inventorying expected packages, versions, and sources"

  local package
  local item
  for package in "${APT_REQUIRED_PACKAGES[@]}"; do
    inspect_required_package "${package}"
  done

  for item in "${PREFERRED_ITEMS[@]}"; do
    inspect_preferred_item "${item}"
  done
}

ensure_apt_metadata() {
  if [[ "${APT_METADATA_READY}" -eq 1 ]]; then
    return 0
  fi

  log "Updating apt package metadata"
  if run sudo apt-get update; then
    APT_METADATA_READY=1
    return 0
  fi

  warn "apt metadata update failed; dependent package installations will be marked failed"
  return 1
}

install_required_packages() {
  log "Installing missing required bootstrap packages"

  local package
  local key
  local version
  for package in "${APT_REQUIRED_PACKAGES[@]}"; do
    key="required:${package}"
    [[ "${ITEM_STATE[${key}]}" == "needs-install" ]] || continue

    if ! ensure_apt_metadata; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "apt metadata unavailable"
      continue
    fi

    if ! apt-cache show "${package}" >/dev/null 2>&1; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "package is unavailable in configured apt sources"
      continue
    fi

    if run sudo apt-get install -y "${package}"; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        set_result "${key}" "PLANNED" "would install from apt"
        continue
      fi
      version="$(installed_deb_version "${package}")"
      if [[ -n "${version}" ]]; then
        ITEM_STATE["${key}"]="satisfied"
        set_result "${key}" "INSTALLED" "apt ${version}"
      else
        ITEM_STATE["${key}"]="failed"
        set_result "${key}" "FAILED" "apt command succeeded but package verification failed"
      fi
    else
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "apt installation command failed"
    fi
  done
}

install_preferred_apt_items() {
  log "Installing eligible preferred apt tools"

  local item
  local key
  local package
  local minimum
  local candidate
  for item in "${PREFERRED_ITEMS[@]}"; do
    [[ "${ITEM_KIND[${item}]}" == "apt" ]] || continue
    key="tool:${item}"
    [[ "${ITEM_STATE[${key}]}" == "needs-install" ]] || continue
    package="${ITEM_PACKAGE[${item}]}"
    minimum="${ITEM_MIN_VERSION[${item}]:-}"

    if ! ensure_apt_metadata; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "apt metadata unavailable; manual installation required"
      continue
    fi

    candidate="$(candidate_deb_version "${package}")"
    if [[ -z "${candidate}" || "${candidate}" == "(none)" ]]; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "${package} is unavailable in configured apt sources; manual installation required"
      continue
    fi

    if [[ -n "${minimum}" ]] && ! version_satisfies "${candidate}" "${minimum}"; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "apt candidate ${candidate} is below minimum ${minimum}; manual installation required"
      continue
    fi

    if run sudo apt-get install -y "${package}"; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        set_result "${key}" "PLANNED" "would install ${package} ${candidate} from apt"
        continue
      fi
      inspect_preferred_item "${item}"
      if [[ "${ITEM_STATE[${key}]}" == "satisfied" ]]; then
        SUMMARY_STATUS["${key}"]="INSTALLED"
      else
        set_result "${key}" "FAILED" "apt installation completed but version/source verification failed"
      fi
    else
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "apt installation command failed"
    fi
  done
}

install_preferred_snap_items() {
  log "Installing eligible preferred Snap tools"

  local item
  local key
  for item in "${PREFERRED_ITEMS[@]}"; do
    [[ "${ITEM_KIND[${item}]}" == "snap" ]] || continue
    key="tool:${item}"
    [[ "${ITEM_STATE[${key}]}" == "needs-install" ]] || continue

    if ! command -v snap >/dev/null 2>&1; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "snap is unavailable; manual installation required"
      continue
    fi

    if run sudo snap install "${item}" --classic --channel=latest/stable; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        set_result "${key}" "PLANNED" "would install from Snap latest/stable"
        continue
      fi
      inspect_preferred_item "${item}"
      if [[ "${ITEM_STATE[${key}]}" == "satisfied" ]]; then
        SUMMARY_STATUS["${key}"]="INSTALLED"
      else
        set_result "${key}" "FAILED" "Snap installation completed but version/source verification failed"
      fi
    else
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "Snap installation command failed"
    fi
  done
}

install_eza_repo() {
  run sudo mkdir -p /etc/apt/keyrings || return 1
  run_shell 'wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/gierens.gpg >/dev/null' || return 1
  run_shell 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null' || return 1
  run sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list || return 1
  run sudo apt-get update || return 1
  run sudo apt-get install -y eza
}

run_remote_installer() {
  local item="$1"

  case "${item}" in
    eza)
      install_eza_repo
      ;;
    starship)
      run_shell 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
      ;;
    zoxide)
      run_shell 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
      ;;
  esac
}

install_remote_items() {
  log "Installing eligible preferred upstream tools"

  local item
  local key
  for item in eza starship zoxide; do
    key="tool:${item}"
    [[ "${ITEM_STATE[${key}]}" == "needs-install" ]] || continue

    if [[ "${SKIP_REMOTE}" -eq 1 ]]; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "remote installation disabled; manual installation required"
      continue
    fi

    if run_remote_installer "${item}"; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        set_result "${key}" "PLANNED" "would install from upstream source"
        continue
      fi
      inspect_preferred_item "${item}"
      if [[ "${ITEM_STATE[${key}]}" == "satisfied" ]]; then
        SUMMARY_STATUS["${key}"]="INSTALLED"
      else
        set_result "${key}" "FAILED" "installer completed but version/source verification failed"
      fi
    else
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "upstream installation command failed"
    fi
  done
}

stow_command_for_package() {
  case "$1" in
    tmux)
      printf '%s\n' tmux
      ;;
    zsh)
      printf '%s\n' zsh
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

stow_package_is_already_satisfied() {
  local package="$1"

  case "${package}" in
    nvim)
      [[ -L "${HOME}/.config/nvim" ]] || return 1
      [[ "$(readlink -f "${HOME}/.config/nvim")" == "$(readlink -f "${ROOT_DIR}/nvim/.config/nvim")" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

simulate_stow() {
  local package="$1"

  printf '+ stow --simulate --verbose=1 --target=%q --no-folding %q\n' "${HOME}" "${package}" | tee -a "${LOG_FILE}"
  stow --simulate --verbose=1 --target="${HOME}" --no-folding "${package}" 2>&1 | tee -a "${LOG_FILE}"
  return "${PIPESTATUS[0]}"
}

stow_dotfiles() {
  log "Stowing dotfile packages independently"
  cd "${ROOT_DIR}"

  local package
  local command
  local key
  for package in "${STOW_PACKAGES[@]}"; do
    key="stow:${package}"
    add_summary_item "${key}" "${package}" "stow"
    command="$(stow_command_for_package "${package}")"

    if ! command -v stow >/dev/null 2>&1; then
      set_result "${key}" "FAILED" "stow command is missing"
      continue
    fi

    if ! command -v "${command}" >/dev/null 2>&1; then
      set_result "${key}" "FAILED" "required command ${command} is missing"
      continue
    fi

    if stow_package_is_already_satisfied "${package}"; then
      set_result "${key}" "SKIPPED" "existing link already points to this package"
      continue
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
      if simulate_stow "${package}"; then
        set_result "${key}" "PLANNED" "would apply Stow package"
      else
        set_result "${key}" "FAILED" "Stow simulation found a conflict; other packages continued"
      fi
    elif run stow --target="${HOME}" --no-folding "${package}"; then
      set_result "${key}" "INSTALLED" "Stow package applied"
    else
      set_result "${key}" "FAILED" "Stow conflict or command failure; other packages continued"
    fi
  done
}

print_summary() {
  log "Installation summary"

  {
    printf '%-24s %-11s %-10s %s\n' TOOL CLASS RESULT DETAIL
    printf '%-24s %-11s %-10s %s\n' '------------------------' '-----------' '----------' '------'

    local key
    for key in "${SUMMARY_KEYS[@]}"; do
      printf '%-24s %-11s %-10s %s\n' \
        "${SUMMARY_LABEL[${key}]}" \
        "${SUMMARY_CLASS[${key}]}" \
        "${SUMMARY_STATUS[${key}]}" \
        "${SUMMARY_DETAIL[${key}]}"
    done
  } | tee -a "${LOG_FILE}"

  local failed=0
  local key
  for key in "${SUMMARY_KEYS[@]}"; do
    [[ "${SUMMARY_STATUS[${key}]}" == "FAILED" ]] && ((failed += 1))
  done

  if [[ "${failed}" -eq 0 ]]; then
    log "Bootstrap completed without failed postconditions"
  else
    warn "Bootstrap completed with ${failed} failed postcondition(s). Review: ${LOG_FILE}"
  fi
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
  : >"${LOG_FILE}"

  trap 'die "bootstrap failed unexpectedly at line ${LINENO}. Log: ${LOG_FILE}"' ERR

  log "Dotfiles bootstrap started"
  log "Repository: ${ROOT_DIR}"
  log "Log file: ${LOG_FILE}"

  initialize_summary
  detect_os
  inventory_expected_content

  if [[ "${DO_INSTALL}" -eq 1 ]]; then
    install_required_packages
    install_preferred_apt_items
    install_preferred_snap_items
    install_remote_items
  fi

  if [[ "${DO_STOW}" -eq 1 ]]; then
    stow_dotfiles
  fi

  print_summary
}

main "$@"
