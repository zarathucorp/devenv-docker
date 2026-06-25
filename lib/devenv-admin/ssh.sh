ensure_sshd_config_include() {
    mkdir -p "$SSHD_CONFIG_DIR"
    touch "$SSHD_CONFIG"

    if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$SSHD_CONFIG"; then
        printf '\nInclude /etc/ssh/sshd_config.d/*.conf\n' >>"$SSHD_CONFIG"
    fi
}

comment_base_sshd_setting() {
    local key="$1"

    if [ -f "$SSHD_CONFIG" ]; then
        sed -i -E "s/^([[:space:]]*)#?[[:space:]]*(${key})[[:space:]].*$/# \2 managed by devenv-admin/" "$SSHD_CONFIG"
    fi
}

set_ssh_password_auth() {
    local state="$1"
    local restart="${2:-yes}"
    local password_auth="no"
    local keyboard_auth="no"

    require_root
    state="$(normalize_on_off "$state")"

    if [ "$state" = "on" ]; then
        password_auth="yes"
        keyboard_auth="yes"
    fi

    ensure_sshd_config_include
    comment_base_sshd_setting "PasswordAuthentication"
    comment_base_sshd_setting "KbdInteractiveAuthentication"
    comment_base_sshd_setting "ChallengeResponseAuthentication"
    comment_base_sshd_setting "PermitRootLogin"
    comment_base_sshd_setting "PubkeyAuthentication"

    cat >"$SSHD_DEVENV_CONFIG" <<EOF
# Managed by devenv-admin.
PasswordAuthentication ${password_auth}
KbdInteractiveAuthentication ${keyboard_auth}
ChallengeResponseAuthentication ${keyboard_auth}
PermitRootLogin no
PubkeyAuthentication yes
EOF

    if command -v sshd >/dev/null 2>&1; then
        mkdir -p /run/sshd
        sshd -t
    fi

    log "ssh password authentication ${state}"
    [ "$restart" = "yes" ] && restart_service_if_running "sshd"
}

ssh_password_auth_status() {
    local output=""

    if command -v sshd >/dev/null 2>&1; then
        mkdir -p /run/sshd 2>/dev/null || true
        ssh-keygen -A >/dev/null 2>&1 || true
        output="$(sshd -T 2>/dev/null || true)"
        if [ -n "$output" ]; then
            printf '%s\n' "$output" | awk '/^passwordauthentication / { print $2; found=1 } END { if (!found) print "unknown" }'
            return 0
        fi
    fi

    if [ -f "$SSHD_DEVENV_CONFIG" ]; then
        awk '/^PasswordAuthentication / { print $2; found=1 } END { if (!found) print "unknown" }' "$SSHD_DEVENV_CONFIG"
    else
        printf 'unknown\n'
    fi
}

ssh_password_auth() {
    local action="${1:-}"
    shift || true
    local restart="yes"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-restart)
                restart="no"
                shift
                ;;
            *)
                die "unknown ssh password-auth option '${1}'"
                ;;
        esac
    done

    case "$action" in
        on | off | true | false | yes | no | 1 | 0 | enable | disable | enabled | disabled)
            set_ssh_password_auth "$action" "$restart"
            ;;
        status)
            ssh_password_auth_status
            ;;
        *)
            die "usage: devenv-admin ssh password-auth on|off|status [--no-restart]"
            ;;
    esac
}
