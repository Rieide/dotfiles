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
  sesh
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
  [sesh]="pinned-release"
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
  [sesh]="sesh"
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
  [sesh]="sesh"
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
  [sesh]="--version"
)

# Pinned tmux tooling. Upgrades are deliberate: change the version or commit
# here, review the upstream diff, then rerun this installer. TPM is used only
# to load plugins; it is not allowed to choose or update their revisions.
SESH_VERSION="2.26.2"
SESH_ARCHIVE="sesh_Linux_x86_64.tar.gz"
SESH_SHA256="4a5cdd75a38c6e3167ab80d419a9973097b2f7e1b63c8150c4e6db8e40c6d803"
SESH_URL="https://github.com/joshmedeski/sesh/releases/download/v${SESH_VERSION}/${SESH_ARCHIVE}"
SESH_BIN="${HOME}/.local/bin/sesh"
SESH_COMPLETION_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions"

TMUX_PLUGIN_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux/plugins"
TMUX_PLUGIN_NAMES=(
  tpm
  tmux-sensible
  tmux-resurrect
  tmux-continuum
  vim-tmux-navigator
)

declare -A TMUX_PLUGIN_REPOS=(
  [tpm]="https://github.com/tmux-plugins/tpm.git"
  [tmux-sensible]="https://github.com/tmux-plugins/tmux-sensible.git"
  [tmux-resurrect]="https://github.com/tmux-plugins/tmux-resurrect.git"
  [tmux-continuum]="https://github.com/tmux-plugins/tmux-continuum.git"
  [vim-tmux-navigator]="https://github.com/christoomey/vim-tmux-navigator.git"
)

declare -A TMUX_PLUGIN_COMMITS=(
  [tpm]="e261deb1b47614eed3400089ce7197dc68acc4eb"
  [tmux-sensible]="25cb91f42d020f675bb0a2ce3fbd3a5d96119efa"
  [tmux-resurrect]="cff343cf9e81983d3da0c8562b01616f12e8d548"
  [tmux-continuum]="0698e8f4b17d6454c71bf5212895ec055c578da0"
  [vim-tmux-navigator]="e41c431a0c7b7388ae7ba341f01a0d217eb3a432"
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

  for item in "${TMUX_PLUGIN_NAMES[@]}"; do
    add_summary_item "plugin:${item}" "${item}" "plugin"
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

inspect_sesh() {
  local key="tool:sesh"
  local path=""
  local output=""
  local version=""

  if path="$(command -v sesh 2>/dev/null)" && [[ -n "${path}" ]]; then
    output="$(command_version_output sesh "${path}")"
    version="$(extract_version "${output}")"

    if [[ "${path}" != "${SESH_BIN}" ]]; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "${path} is not the installer-managed binary ${SESH_BIN}; manual action required"
      return 0
    fi

    if [[ "${version}" != "${SESH_VERSION}" ]]; then
      if [[ "${OS_SUPPORTED}" -eq 1 && "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]; then
        ITEM_STATE["${key}"]="needs-install"
        set_result "${key}" "PENDING" "managed binary is ${version:-unknown}; pinned version is ${SESH_VERSION}"
      else
        ITEM_STATE["${key}"]="failed"
        set_result "${key}" "FAILED" "managed binary is ${version:-unknown}, but this platform cannot use the pinned Linux x86_64 release"
      fi
      return 0
    fi

    if [[ ! -s "${SESH_COMPLETION_DIR}/_sesh" ]]; then
      ITEM_STATE["${key}"]="needs-completion"
      set_result "${key}" "PENDING" "sesh ${version} is pinned; zsh completion is missing"
      return 0
    fi

    ITEM_STATE["${key}"]="satisfied"
    set_result "${key}" "SKIPPED" "${SESH_BIN} ${version} and zsh completion satisfy policy"
    return 0
  fi

  if [[ "${OS_SUPPORTED}" -eq 1 && "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]; then
    ITEM_STATE["${key}"]="needs-install"
    set_result "${key}" "PENDING" "not installed; pinned release v${SESH_VERSION} is available for Linux x86_64"
  else
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "pinned release supports the target Linux x86_64 platform only; manual installation required"
  fi
}

canonical_github_remote() {
  local remote="$1"
  local path=""

  case "${remote}" in
    https://github.com/*)
      path="${remote#https://github.com/}"
      ;;
    git@github.com:*)
      path="${remote#git@github.com:}"
      ;;
    *)
      return 1
      ;;
  esac

  path="${path%.git}"
  printf 'github.com/%s\n' "${path}"
}

inspect_tmux_plugin() {
  local name="$1"
  local key="plugin:${name}"
  local directory="${TMUX_PLUGIN_DIR}/${name}"
  local expected_remote="${TMUX_PLUGIN_REPOS[${name}]}"
  local expected_commit="${TMUX_PLUGIN_COMMITS[${name}]}"
  local actual_remote=""
  local actual_canonical=""
  local expected_canonical=""
  local actual_commit=""
  local dirty=""

  if [[ ! -e "${directory}" ]]; then
    ITEM_STATE["${key}"]="needs-install"
    set_result "${key}" "PENDING" "missing; pinned commit ${expected_commit:0:12}"
    return 0
  fi

  if [[ ! -d "${directory}/.git" ]]; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "${directory} is not a Git checkout; left untouched; manual action required"
    return 0
  fi

  actual_remote="$(git -C "${directory}" remote get-url origin 2>/dev/null || true)"
  actual_canonical="$(canonical_github_remote "${actual_remote}" 2>/dev/null || true)"
  expected_canonical="$(canonical_github_remote "${expected_remote}")"
  if [[ "${actual_canonical}" != "${expected_canonical}" ]]; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "unexpected origin ${actual_remote:-missing}; expected ${expected_remote}; left untouched; manual action required"
    return 0
  fi

  dirty="$(git -C "${directory}" status --porcelain --untracked-files=normal 2>/dev/null || true)"
  if [[ -n "${dirty}" ]]; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "working tree has local changes; left untouched; commit or stash them before retrying"
    return 0
  fi

  actual_commit="$(git -C "${directory}" rev-parse HEAD 2>/dev/null || true)"
  if [[ "${actual_commit}" == "${expected_commit}" ]]; then
    ITEM_STATE["${key}"]="satisfied"
    set_result "${key}" "SKIPPED" "official origin at pinned commit ${expected_commit:0:12}"
  else
    ITEM_STATE["${key}"]="needs-checkout"
    set_result "${key}" "PENDING" "official clean checkout at ${actual_commit:0:12}; will switch to ${expected_commit:0:12}"
  fi
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

  if [[ "${item}" == "sesh" ]]; then
    inspect_sesh
    return 0
  fi

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

  for item in "${TMUX_PLUGIN_NAMES[@]}"; do
    inspect_tmux_plugin "${item}"
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

generate_sesh_completion() {
  local completion_file="${SESH_COMPLETION_DIR}/_sesh"
  local temporary_file=""

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '+ mkdir -p %q\n' "${SESH_COMPLETION_DIR}" | tee -a "${LOG_FILE}"
    printf '+ %q completion zsh > %q\n' "${SESH_BIN}" "${completion_file}" | tee -a "${LOG_FILE}"
    return 0
  fi

  mkdir -p "${SESH_COMPLETION_DIR}" || return 1
  temporary_file="$(mktemp "${SESH_COMPLETION_DIR}/.sesh-completion.XXXXXX")" || return 1
  if "${SESH_BIN}" completion zsh >"${temporary_file}" && [[ -s "${temporary_file}" ]]; then
    mv "${temporary_file}" "${completion_file}"
    return 0
  fi

  rm -f "${temporary_file}"
  return 1
}

install_sesh() {
  local key="tool:sesh"
  local state="${ITEM_STATE[${key}]}"
  local temporary_directory=""
  local archive=""
  local extracted_binary=""
  local actual_sha=""

  [[ "${state}" == "needs-install" || "${state}" == "needs-completion" ]] || return 0

  if [[ "${state}" == "needs-completion" ]]; then
    if generate_sesh_completion; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        set_result "${key}" "PLANNED" "would generate zsh completion for pinned sesh ${SESH_VERSION}"
      else
        ITEM_STATE["${key}"]="satisfied"
        set_result "${key}" "INSTALLED" "generated zsh completion for pinned sesh ${SESH_VERSION}"
      fi
    else
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "could not generate zsh completion; binary was left untouched"
    fi
    return 0
  fi

  if [[ "${SKIP_REMOTE}" -eq 1 ]]; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "remote installation disabled; pinned sesh ${SESH_VERSION} was not downloaded"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '+ curl -fL --retry 3 --output <temporary> %q\n' "${SESH_URL}" | tee -a "${LOG_FILE}"
    printf '+ verify SHA256 %s and install %q\n' "${SESH_SHA256}" "${SESH_BIN}" | tee -a "${LOG_FILE}"
    set_result "${key}" "PLANNED" "would install pinned sesh ${SESH_VERSION} with SHA256 verification and zsh completion"
    return 0
  fi

  temporary_directory="$(mktemp -d)" || {
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "could not create a temporary download directory"
    return 0
  }
  archive="${temporary_directory}/${SESH_ARCHIVE}"

  if ! run curl -fL --retry 3 --output "${archive}" "${SESH_URL}"; then
    rm -rf "${temporary_directory}"
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "release download failed; other installation work continued"
    return 0
  fi

  actual_sha="$(sha256sum "${archive}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${SESH_SHA256}" ]]; then
    rm -rf "${temporary_directory}"
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "SHA256 mismatch (got ${actual_sha}); archive rejected"
    return 0
  fi

  if ! run tar -xzf "${archive}" -C "${temporary_directory}"; then
    rm -rf "${temporary_directory}"
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "verified release archive could not be extracted"
    return 0
  fi

  extracted_binary="${temporary_directory}/sesh"
  if [[ ! -f "${extracted_binary}" ]] || ! run mkdir -p "$(dirname "${SESH_BIN}")" || ! run install -m 0755 "${extracted_binary}" "${SESH_BIN}"; then
    rm -rf "${temporary_directory}"
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "verified binary could not be installed to ${SESH_BIN}"
    return 0
  fi
  rm -rf "${temporary_directory}"

  if generate_sesh_completion; then
    inspect_sesh
    if [[ "${ITEM_STATE[${key}]}" == "satisfied" ]]; then
      set_result "${key}" "INSTALLED" "pinned sesh ${SESH_VERSION}; SHA256 verified; zsh completion generated"
    else
      set_result "${key}" "FAILED" "installation completed but version/completion verification failed"
    fi
  else
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "sesh ${SESH_VERSION} installed, but zsh completion generation failed"
  fi
}

install_tmux_plugin() {
  local name="$1"
  local key="plugin:${name}"
  local state="${ITEM_STATE[${key}]}"
  local directory="${TMUX_PLUGIN_DIR}/${name}"
  local remote="${TMUX_PLUGIN_REPOS[${name}]}"
  local commit="${TMUX_PLUGIN_COMMITS[${name}]}"
  local staging=""
  local checkout=""

  [[ "${state}" == "needs-install" || "${state}" == "needs-checkout" ]] || return 0

  if [[ "${state}" == "needs-install" && "${SKIP_REMOTE}" -eq 1 ]]; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "remote installation disabled; plugin remains missing"
    return 0
  fi

  if [[ "${state}" == "needs-checkout" && "${SKIP_REMOTE}" -eq 1 ]] && ! git -C "${directory}" cat-file -e "${commit}^{commit}" 2>/dev/null; then
    ITEM_STATE["${key}"]="failed"
    set_result "${key}" "FAILED" "remote installation disabled and pinned commit is unavailable locally; checkout left unchanged"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    if [[ "${state}" == "needs-install" ]]; then
      printf '+ git clone %q %q && git checkout --detach %q\n' "${remote}" "${directory}" "${commit}" | tee -a "${LOG_FILE}"
      set_result "${key}" "PLANNED" "would clone official origin at ${commit:0:12}"
    else
      printf '+ git -C %q checkout --detach %q\n' "${directory}" "${commit}" | tee -a "${LOG_FILE}"
      set_result "${key}" "PLANNED" "would switch clean official checkout to ${commit:0:12}"
    fi
    return 0
  fi

  if [[ "${state}" == "needs-install" ]]; then
    if ! run mkdir -p "${TMUX_PLUGIN_DIR}"; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "could not create ${TMUX_PLUGIN_DIR}"
      return 0
    fi
    staging="$(mktemp -d "${TMUX_PLUGIN_DIR}/.${name}.XXXXXX")" || {
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "could not create a staging directory"
      return 0
    }
    checkout="${staging}/checkout"

    if ! run git clone --filter=blob:none --no-checkout "${remote}" "${checkout}" || ! run git -C "${checkout}" checkout --detach "${commit}"; then
      rm -rf "${staging}"
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "clone or pinned checkout failed; destination was left unchanged"
      return 0
    fi

    if ! mv "${checkout}" "${directory}"; then
      rm -rf "${staging}"
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "could not move verified checkout into ${directory}"
      return 0
    fi
    rmdir "${staging}" 2>/dev/null || true
  else
    if ! git -C "${directory}" cat-file -e "${commit}^{commit}" 2>/dev/null; then
      if [[ "${SKIP_REMOTE}" -eq 1 ]] || ! run git -C "${directory}" fetch --quiet origin "${commit}"; then
        ITEM_STATE["${key}"]="failed"
        set_result "${key}" "FAILED" "pinned commit is unavailable locally and could not be fetched; checkout left unchanged"
        return 0
      fi
    fi

    if ! run git -C "${directory}" checkout --quiet --detach "${commit}"; then
      ITEM_STATE["${key}"]="failed"
      set_result "${key}" "FAILED" "could not switch clean checkout; manual action required"
      return 0
    fi
  fi

  inspect_tmux_plugin "${name}"
  if [[ "${ITEM_STATE[${key}]}" == "satisfied" ]]; then
    set_result "${key}" "INSTALLED" "official origin pinned at ${commit:0:12}"
  else
    set_result "${key}" "FAILED" "plugin operation completed but postcondition verification failed"
  fi
}

install_tmux_plugins() {
  log "Installing pinned tmux plugins"

  local name
  for name in "${TMUX_PLUGIN_NAMES[@]}"; do
    install_tmux_plugin "${name}"
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
    install_sesh
    install_tmux_plugins
  fi

  if [[ "${DO_STOW}" -eq 1 ]]; then
    stow_dotfiles
  fi

  print_summary
}

main "$@"
