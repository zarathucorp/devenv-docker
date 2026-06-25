SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
SSHD_CONFIG_DIR="${SSHD_CONFIG_DIR:-/etc/ssh/sshd_config.d}"
SSHD_DEVENV_CONFIG="${SSHD_DEVENV_CONFIG:-${SSHD_CONFIG_DIR}/99-devenv.conf}"
PAM_FILE="${PAM_FILE:-/etc/pam.d/rstudio}"
RSERVER_CONF="${RSERVER_CONF:-/etc/rstudio/rserver.conf}"
OTP_PAM_LINE="${OTP_PAM_LINE:-auth sufficient pam_google_authenticator.so}"
OTP_EXEMPT_GROUP="${OTP_EXEMPT_GROUP:-otp_exempt}"

log() {
    printf '[devenv-admin] %s\n' "$*" >&2
}

warn() {
    printf '[devenv-admin] warning: %s\n' "$*" >&2
}

die() {
    printf '[devenv-admin] error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "this command must be run as root"
    fi
}

validate_username() {
    local username="$1"

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        die "invalid username '${username}'. Use lowercase letters, numbers, underscore, and hyphen only."
    fi

    case "$username" in
        root | daemon | bin | sys | sync | games | man | lp | mail | news | uucp | proxy | www-data | backup | list | irc)
            die "refusing to manage system user '${username}'"
            ;;
    esac
}

require_user_exists() {
    local username="$1"
    validate_username "$username"

    if ! id "$username" >/dev/null 2>&1; then
        die "user '${username}' does not exist"
    fi
}

primary_group() {
    id -gn "$1"
}

read_first_line() {
    local file="$1"
    local value=""

    [ -r "$file" ] || die "cannot read '${file}'"
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
            die "expected on/off, yes/no, true/false, or 1/0; got '${1:-}'"
            ;;
    esac
}

normalize_yes_no() {
    case "${1:-}" in
        yes | y | true | 1 | on)
            printf 'yes'
            ;;
        no | n | false | 0 | off)
            printf 'no'
            ;;
        *)
            die "expected yes/no for sudo; got '${1:-}'"
            ;;
    esac
}

restart_service_if_running() {
    local service="$1"

    if command -v supervisorctl >/dev/null 2>&1 && [ -S /var/run/supervisor.sock ]; then
        supervisorctl restart "$service" >/dev/null || warn "failed to restart ${service}"
    fi
}
