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
    local value

    value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    case "$value" in
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

if [ "$(id -u)" -ne 0 ]; then
    log "container must start as root"
    exit 1
fi

if [ ! -x /usr/bin/supervisord ]; then
    log "missing executable: /usr/bin/supervisord"
    exit 1
fi

if [ ! -r /etc/supervisord.conf ]; then
    log "missing readable supervisor config: /etc/supervisord.conf"
    exit 1
fi

mkdir -p /run/sshd
ssh-keygen -A

ssh_password_auth="$(normalize_on_off "${DEVENV_SSH_PASSWORD_AUTH:-false}")"
devenv-admin ssh password-auth "$ssh_password_auth" --no-restart

otp_state="$(normalize_on_off "${DEVENV_RSERVER_OTP:-false}")"
if [ "$otp_state" = "on" ]; then
    devenv-admin otp enable
fi

if [ -n "${DEVENV_BOOTSTRAP_USER:-}" ]; then
    bootstrap_args=(user add "$DEVENV_BOOTSTRAP_USER")
    if [ -n "${DEVENV_BOOTSTRAP_SUDO:-}" ]; then
        bootstrap_args+=(--sudo "$DEVENV_BOOTSTRAP_SUDO")
    fi

    bootstrap_password_set="no"
    if [ -n "${DEVENV_BOOTSTRAP_PASSWORD_FILE:-}" ]; then
        bootstrap_password="$(read_first_line "$DEVENV_BOOTSTRAP_PASSWORD_FILE")"
        bootstrap_password_set="yes"
        bootstrap_args+=(--password-stdin)
    elif [ -n "${DEVENV_BOOTSTRAP_PASSWORD:-}" ]; then
        bootstrap_password="$DEVENV_BOOTSTRAP_PASSWORD"
        bootstrap_password_set="yes"
        bootstrap_args+=(--password-stdin)
    else
        bootstrap_password=""
    fi

    if [ "$bootstrap_password_set" = "yes" ] && [ -z "$bootstrap_password" ]; then
        log "bootstrap password is empty"
        exit 1
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
    if [ "$bootstrap_password_set" = "yes" ]; then
        printf '%s' "$bootstrap_password" | devenv-admin "${bootstrap_args[@]}"
    else
        devenv-admin "${bootstrap_args[@]}"
    fi
fi

exec /usr/bin/supervisord -c /etc/supervisord.conf
