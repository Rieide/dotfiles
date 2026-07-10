#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHECKER="${HOME}/.local/bin/git-identity-check"
LOG_FILE="$(mktemp /tmp/git-identity-security-log.XXXXXX)"
PUBLIC_REPO="$(mktemp -d /tmp/git-identity-public.XXXXXX)"
WORK_REPO="$(mktemp -d "${ROOT_DIR}/.git-identity-work.XXXXXX")"
EVIL_CONFIG="$(mktemp /tmp/git-identity-evil.XXXXXX)"
FAKE_HOME="$(mktemp -d /tmp/git-identity-home.XXXXXX)"

cleanup() {
  rm -rf -- "${PUBLIC_REPO}" "${WORK_REPO}" "${FAKE_HOME}"
  rm -f -- "${LOG_FILE}" "${EVIL_CONFIG}"
}
trap cleanup EXIT

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  if [[ -s "${LOG_FILE}" ]]; then
    sed -n '1,20p' "${LOG_FILE}" >&2
  fi
  exit 1
}

expect_success() {
  local label="$1"
  shift
  : > "${LOG_FILE}"
  if "$@" > "${LOG_FILE}" 2>&1; then
    pass "${label}"
  else
    fail "${label}"
  fi
}

expect_guard_reject() {
  local label="$1"
  shift
  : > "${LOG_FILE}"
  if "$@" > "${LOG_FILE}" 2>&1; then
    fail "${label}: malicious commit was accepted"
  fi
  if rg -q 'Git identity check failed:' "${LOG_FILE}"; then
    pass "${label}"
  else
    fail "${label}: command failed for a reason other than the identity guard"
  fi
}

[[ -x "${CHECKER}" ]] || fail 'deployed identity checker is missing or not executable'

git -C "${PUBLIC_REPO}" init -q
git -C "${WORK_REPO}" init -q

expect_success 'public profile outside the work root' "${CHECKER}" "${PUBLIC_REPO}"
expect_success 'work profile inside the work root' "${CHECKER}" "${WORK_REPO}"
expect_success 'dotfiles repository keeps its public exception' "${CHECKER}" "${ROOT_DIR}"
expect_success 'baseline public commit passes the deployed hook' git -C "${PUBLIC_REPO}" commit --allow-empty -m baseline-public
expect_success 'baseline work commit passes the deployed hook' git -C "${WORK_REPO}" commit --allow-empty -m baseline-work

git -C "${WORK_REPO}" config user.name Mallory
git -C "${WORK_REPO}" config user.email mallory@example.invalid
expect_guard_reject 'repository-local identity override is rejected' git -C "${WORK_REPO}" commit --allow-empty -m attack-local
git -C "${WORK_REPO}" config --unset-all user.name
git -C "${WORK_REPO}" config --unset-all user.email

git config --file "${EVIL_CONFIG}" user.name Mallory
git config --file "${EVIL_CONFIG}" user.email mallory@example.invalid
git -C "${WORK_REPO}" config --add include.path "${EVIL_CONFIG}"
expect_guard_reject 'repository-local malicious include is rejected' git -C "${WORK_REPO}" commit --allow-empty -m attack-include
git -C "${WORK_REPO}" config --unset-all include.path

expect_guard_reject 'git -c identity override is rejected' \
  git -C "${WORK_REPO}" -c user.name=Mallory -c user.email=mallory@example.invalid \
  commit --allow-empty -m attack-command-config

expect_guard_reject 'author environment override is rejected' \
  env GIT_AUTHOR_NAME=Mallory GIT_AUTHOR_EMAIL=mallory@example.invalid \
  git -C "${WORK_REPO}" commit --allow-empty -m attack-author-env

expect_guard_reject 'committer environment override is rejected' \
  env GIT_COMMITTER_NAME=Mallory GIT_COMMITTER_EMAIL=mallory@example.invalid \
  git -C "${WORK_REPO}" commit --allow-empty -m attack-committer-env

expect_guard_reject '--author override is rejected' \
  git -C "${WORK_REPO}" commit --allow-empty --author='Mallory <mallory@example.invalid>' -m attack-author-option

expect_guard_reject '--no-verify does not bypass prepare-commit-msg identity validation' \
  git -C "${WORK_REPO}" -c user.name=Mallory -c user.email=mallory@example.invalid \
  commit --allow-empty --no-verify -m attack-no-verify

git config --file "${FAKE_HOME}/.gitconfig.local" identity.workRoot "${ROOT_DIR}"
git config --file "${FAKE_HOME}/.gitconfig.work" user.name Mallory
git config --file "${FAKE_HOME}/.gitconfig.work" user.email mallory@example.invalid
chmod 600 "${FAKE_HOME}/.gitconfig.local"
chmod 644 "${FAKE_HOME}/.gitconfig.work"
expect_guard_reject 'world-readable private identity policy is rejected' \
  env HOME="${FAKE_HOME}" "${CHECKER}" "${WORK_REPO}"

rm -f "${FAKE_HOME}/.gitconfig.work"
git config --file "${FAKE_HOME}/work-target" user.name Mallory
git config --file "${FAKE_HOME}/work-target" user.email mallory@example.invalid
chmod 600 "${FAKE_HOME}/work-target"
ln -s "${FAKE_HOME}/work-target" "${FAKE_HOME}/.gitconfig.work"
expect_guard_reject 'symlinked private identity policy is rejected' \
  env HOME="${FAKE_HOME}" "${CHECKER}" "${WORK_REPO}"

: > "${LOG_FILE}"
if git -C "${WORK_REPO}" -c core.hooksPath=/dev/null \
  -c user.name=Mallory -c user.email=mallory@example.invalid \
  commit --allow-empty -m known-local-bypass > "${LOG_FILE}" 2>&1; then
  printf 'KNOWN LIMIT: command-scope core.hooksPath can bypass a client-side hook\n'
else
  fail 'expected local hook bypass behavior changed; review the security model'
fi

printf 'Identity security regression suite completed.\n'
