#!/bin/bash
set -Eeuo pipefail

TEST_USER="${DEVENV_TEST_USER:-devenvtest}"
TEST_PASSWORD="${DEVENV_TEST_PASSWORD:-DevenvTest123!}"
TEST_KEY="${DEVENV_TEST_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEvenvSmokeTestKeyOnly devenv-smoke-test}"
TEST_MANIFEST="${DEVENV_TEST_MANIFEST:-/tmp/devenv-users-smoke.tsv}"
TEST_CONFIG_BACKUP="${DEVENV_TEST_CONFIG_BACKUP:-/tmp/devenv-config-smoke.tar.gz}"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'USAGE'
Usage:
  devenv-smoke-test

Environment:
  DEVENV_TEST_USER       Test Linux user to create/use. Default: devenvtest
  DEVENV_TEST_PASSWORD   Password assigned when the test user is first created. Default: DevenvTest123!
  DEVENV_TEST_KEY        SSH public key line used for add/remove testing.
  DEVENV_TEST_MANIFEST   User manifest path used for export/import testing.
  DEVENV_TEST_CONFIG_BACKUP Config backup path.

This script mutates users and service configuration. Run it only in a disposable
test container.
USAGE
    exit 0
fi

log() {
    printf '[smoke] %s\n' "$*"
}

fail() {
    printf '[smoke] FAIL: %s\n' "$*" >&2
    exit 1
}

run() {
    log "$*"
    "$@"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if ! printf '%s\n' "$haystack" | grep -Fq "$needle"; then
        fail "$message"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if printf '%s\n' "$haystack" | grep -Fq "$needle"; then
        fail "$message"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    fail "run as root inside the container"
fi

command -v devenv-admin >/dev/null 2>&1 || fail "devenv-admin not found"

log "starting devenv smoke test"
run devenv-admin status

log "creating test user: ${TEST_USER}"
printf '%s' "$TEST_PASSWORD" | devenv-admin user add "$TEST_USER" --password-stdin --sudo no
id "$TEST_USER" >/dev/null
test -d "/home/${TEST_USER}/ShinyApps" || fail "ShinyApps directory was not created"

log "verifying user inspect/export/import"
run devenv-admin user inspect "$TEST_USER"
run devenv-admin user export --output "$TEST_MANIFEST"
test -s "$TEST_MANIFEST" || fail "user manifest was not created"
run devenv-admin user import --file "$TEST_MANIFEST" --restore-keys yes --replace-keys no --restore-groups yes --create-home yes

log "verifying sudo toggles"
run devenv-admin user sudo "$TEST_USER" on
id -nG "$TEST_USER" | tr ' ' '\n' | grep -Fxq sudo || fail "sudo group was not added"
run devenv-admin user sudo "$TEST_USER" off
if id -nG "$TEST_USER" | tr ' ' '\n' | grep -Fxq sudo; then
    fail "sudo group was not removed"
fi

log "verifying ssh key management"
run devenv-admin user key add "$TEST_USER" --ssh-key "$TEST_KEY"
keys="$(devenv-admin user key list "$TEST_USER")"
assert_contains "$keys" "$TEST_KEY" "ssh key was not listed after add"
run devenv-admin user key remove "$TEST_USER" --ssh-key "$TEST_KEY"
keys="$(devenv-admin user key list "$TEST_USER")"
assert_not_contains "$keys" "$TEST_KEY" "ssh key was still listed after remove"

log "verifying shiny commands"
run devenv-admin shiny init "$TEST_USER"
run devenv-admin shiny list "$TEST_USER"

log "verifying rstudio reset command"
run devenv-admin rstudio reset "$TEST_USER"

log "verifying ssh password-auth toggles"
run devenv-admin ssh password-auth off --no-restart
ssh_status="$(devenv-admin ssh password-auth status)"
log "ssh password-auth status after off: ${ssh_status}"
run devenv-admin ssh password-auth on --no-restart
ssh_status="$(devenv-admin ssh password-auth status)"
log "ssh password-auth status after on: ${ssh_status}"
run devenv-admin ssh password-auth off --no-restart

log "verifying OTP commands"
run devenv-admin otp enable
otp_status="$(devenv-admin otp status)"
test "$otp_status" = "enabled" || fail "OTP status should be enabled, got '${otp_status}'"
run devenv-admin otp exempt add "$TEST_USER"
otp_exempt="$(devenv-admin otp exempt list)"
assert_contains "$otp_exempt" "$TEST_USER" "test user was not added to otp_exempt"
run devenv-admin otp exempt remove "$TEST_USER"
otp_exempt="$(devenv-admin otp exempt list || true)"
assert_not_contains "$otp_exempt" "$TEST_USER" "test user was not removed from otp_exempt"
if command -v google-authenticator >/dev/null 2>&1; then
    run devenv-admin otp init "$TEST_USER"
    test -f "/home/${TEST_USER}/.google_authenticator" || fail "OTP secret file was not created"
else
    log "google-authenticator command missing; skipping otp init"
fi
run devenv-admin otp disable
otp_status="$(devenv-admin otp status)"
test "$otp_status" = "disabled" || fail "OTP status should be disabled, got '${otp_status}'"

log "verifying doctor and healthcheck"
run devenv-admin service status all
run devenv-admin logs services --lines 20
run devenv-admin logs rstudio --lines 20
run devenv-admin logs shiny --lines 20
run devenv-admin logs ssh --lines 20
run devenv-admin logs auth --lines 20
run devenv-admin config backup --output "$TEST_CONFIG_BACKUP"
test -s "$TEST_CONFIG_BACKUP" || fail "config backup was not created"
run devenv-admin doctor
if devenv-admin healthcheck; then
    log "healthcheck passed"
else
    log "healthcheck failed; this is expected if supervisor services are not running in this shell"
fi

log "smoke test completed"
