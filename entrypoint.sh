#!/bin/bash
set -Eeuo pipefail

log() {
    printf '[entrypoint] %s\n' "$*" >&2
}

read_first_line() {
    local file="$1"
    local value=""

    [ -r "$file" ] || {
        printf '[entrypoint] cannot read %s\n' "$file" >&2
        exit 1
    }
    IFS= read -r value <"$file" || true
    printf '%s' "$value"
}

normalize_on_off() {
    case "${1:-}" in
        on | true | yes | y | 1 | enable | enabled)
            printf 'on'
            ;;
        off | false | no | n | 0 | disable | disabled)
            printf 'off'
            ;;
        *)
            printf '[entrypoint] invalid boolean value: %s\n' "${1:-}" >&2
            exit 1
            ;;
    esac
}

mkdir -p /run/sshd
ssh-keygen -A

ssh_password_auth="$(normalize_on_off "${DEVENV_SSH_PASSWORD_AUTH:-false}")"
devenv-admin ssh password-auth "$ssh_password_auth" --no-restart

otp_state="$(normalize_on_off "${DEVENV_RSERVER_OTP:-false}")"
if [ "$otp_state" = "on" ]; then
    devenv-admin otp enable
fi

if [ -n "${DEVENV_BOOTSTRAP_USER:-}" ]; then
    bootstrap_args=(user add "$DEVENV_BOOTSTRAP_USER" --sudo "${DEVENV_BOOTSTRAP_SUDO:-no}")

    if [ -n "${DEVENV_BOOTSTRAP_PASSWORD_FILE:-}" ]; then
        bootstrap_password="$(read_first_line "$DEVENV_BOOTSTRAP_PASSWORD_FILE")"
        bootstrap_args+=(--password-stdin)
    elif [ -n "${DEVENV_BOOTSTRAP_PASSWORD:-}" ]; then
        bootstrap_password="$DEVENV_BOOTSTRAP_PASSWORD"
        bootstrap_args+=(--password-stdin)
    else
        bootstrap_password=""
    fi

    force_password_state="$(normalize_on_off "${DEVENV_BOOTSTRAP_FORCE_PASSWORD:-false}")"
    if [ "$force_password_state" = "on" ]; then
        bootstrap_args+=(--force-password)
    fi

    if [ -n "${DEVENV_BOOTSTRAP_SSH_KEY_FILE:-}" ]; then
        bootstrap_args+=(--ssh-key-file "$DEVENV_BOOTSTRAP_SSH_KEY_FILE")
    fi

    if [ -n "${DEVENV_BOOTSTRAP_SSH_KEY:-}" ]; then
        bootstrap_args+=(--ssh-key "$DEVENV_BOOTSTRAP_SSH_KEY")
    fi

    log "bootstrapping user ${DEVENV_BOOTSTRAP_USER}"
    if [ -n "$bootstrap_password" ]; then
        printf '%s' "$bootstrap_password" | devenv-admin "${bootstrap_args[@]}"
    else
        devenv-admin "${bootstrap_args[@]}"
    fi
fi

exec /usr/bin/supervisord -c /etc/supervisord.conf
