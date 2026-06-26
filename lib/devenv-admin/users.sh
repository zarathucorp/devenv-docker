set_user_password() {
    local username="$1"
    local password="$2"

    [ -n "$password" ] || die "password cannot be empty"
    printf '%s:%s\n' "$username" "$password" | chpasswd
    passwd -u "$username" >/dev/null 2>&1 || true
}

set_user_sudo() {
    local username="$1"
    local state="$2"

    require_root
    require_regular_user_exists "$username"
    state="$(normalize_on_off "$state")"

    if [ "$state" = "on" ]; then
        usermod -aG sudo "$username"
        log "sudo enabled for ${username}"
    else
        gpasswd -d "$username" sudo >/dev/null 2>&1 || true
        log "sudo disabled for ${username}"
    fi
}

authorized_keys_file() {
    local username="$1"
    local group
    local home_dir

    require_regular_user_exists "$username"
    group="$(primary_group "$username")"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"

    install -d -m 700 -o "$username" -g "$group" "${home_dir}/.ssh"
    touch "${home_dir}/.ssh/authorized_keys"
    chown "$username:$group" "${home_dir}/.ssh/authorized_keys"
    chmod 600 "${home_dir}/.ssh/authorized_keys"
    printf '%s' "${home_dir}/.ssh/authorized_keys"
}

authorized_keys_path() {
    local username="$1"
    local home_dir

    require_regular_user_exists "$username"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    printf '%s' "${home_dir}/.ssh/authorized_keys"
}

add_ssh_key() {
    local username="$1"
    local key="$2"
    local file

    [ -n "$key" ] || die "ssh key cannot be empty"
    file="$(authorized_keys_file "$username")"

    if grep -Fxq "$key" "$file"; then
        log "ssh key already exists for ${username}"
    else
        printf '%s\n' "$key" >>"$file"
        log "ssh key added for ${username}"
    fi
}

remove_ssh_key() {
    local username="$1"
    local key="$2"
    local file
    local tmp

    [ -n "$key" ] || die "ssh key cannot be empty"
    file="$(authorized_keys_file "$username")"
    tmp="$(mktemp)"
    grep -Fxv "$key" "$file" >"$tmp" || true
    cat "$tmp" >"$file"
    rm -f "$tmp"
    log "ssh key removed for ${username}"
}

user_add() {
    local username="$1"
    shift

    local password=""
    local password_set="no"
    local force_password="no"
    local sudo_state=""
    local ssh_key
    local -a ssh_keys=()
    local existed="no"

    require_root
    validate_username "$username"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --password)
                [ "$#" -ge 2 ] || die "--password requires a value"
                password="$2"
                password_set="yes"
                shift 2
                ;;
            --password-file)
                [ "$#" -ge 2 ] || die "--password-file requires a value"
                password="$(read_first_line "$2")"
                password_set="yes"
                shift 2
                ;;
            --password-stdin)
                password="$(cat)"
                password_set="yes"
                shift
                ;;
            --force-password)
                force_password="yes"
                shift
                ;;
            --sudo)
                [ "$#" -ge 2 ] || die "--sudo requires yes or no"
                sudo_state="$(normalize_yes_no "$2")"
                shift 2
                ;;
            --ssh-key)
                [ "$#" -ge 2 ] || die "--ssh-key requires a value"
                ssh_keys+=("$2")
                shift 2
                ;;
            --ssh-key-file)
                [ "$#" -ge 2 ] || die "--ssh-key-file requires a file"
                [ -r "$2" ] || die "cannot read ssh key file '${2}'"
                while IFS= read -r ssh_key || [ -n "$ssh_key" ]; do
                    [ -n "$ssh_key" ] && ssh_keys+=("$ssh_key")
                done <"$2"
                shift 2
                ;;
            *)
                die "unknown user add option '${1}'"
                ;;
        esac
    done

    if id "$username" >/dev/null 2>&1; then
        existed="yes"
        log "user ${username} already exists"
    else
        useradd -m -s /bin/bash "$username"
        log "user ${username} created"
    fi

    if [ "$password_set" = "yes" ]; then
        if [ "$existed" = "no" ] || [ "$force_password" = "yes" ]; then
            set_user_password "$username" "$password"
            log "password set for ${username}"
        else
            log "password unchanged for existing user ${username}; use --force-password to update it"
        fi
    fi

    if [ -n "$sudo_state" ]; then
        set_user_sudo "$username" "$sudo_state"
    fi
    ensure_shiny_dir "$username"

    for ssh_key in "${ssh_keys[@]}"; do
        add_ssh_key "$username" "$ssh_key"
    done
}

user_delete() {
    local username="$1"
    shift
    local remove_home="no"

    require_root
    require_regular_user_exists "$username"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --remove-home)
                remove_home="yes"
                shift
                ;;
            *)
                die "unknown user delete option '${1}'"
                ;;
        esac
    done

    if [ "$remove_home" = "yes" ]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi
    log "user ${username} deleted"
}

user_passwd() {
    local username="$1"
    shift
    local password=""
    local password_set="no"

    require_root
    require_regular_user_exists "$username"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --password)
                [ "$#" -ge 2 ] || die "--password requires a value"
                password="$2"
                password_set="yes"
                shift 2
                ;;
            --password-file)
                [ "$#" -ge 2 ] || die "--password-file requires a value"
                password="$(read_first_line "$2")"
                password_set="yes"
                shift 2
                ;;
            --password-stdin)
                password="$(cat)"
                password_set="yes"
                shift
                ;;
            *)
                die "unknown user passwd option '${1}'"
                ;;
        esac
    done

    if [ "$password_set" = "yes" ]; then
        set_user_password "$username" "$password"
    else
        passwd "$username"
    fi
}

read_key_arg() {
    local key=""

    [ "$#" -gt 0 ] || die "ssh key value is required"
    case "$1" in
        --ssh-key)
            [ "$#" -eq 2 ] || die "--ssh-key requires exactly one value"
            key="$2"
            ;;
        --ssh-key-file)
            [ "$#" -eq 2 ] || die "--ssh-key-file requires exactly one file"
            key="$(read_first_line "$2")"
            ;;
        *)
            [ "$#" -eq 1 ] || die "ssh key accepts exactly one value"
            key="$1"
            ;;
    esac
    printf '%s' "$key"
}

user_key() {
    local action="$1"
    local username="$2"
    shift 2
    local file
    local key

    require_root
    require_regular_user_exists "$username"

    case "$action" in
        add)
            key="$(read_key_arg "$@")"
            add_ssh_key "$username" "$key"
            ;;
        remove)
            key="$(read_key_arg "$@")"
            remove_ssh_key "$username" "$key"
            ;;
        list)
            [ "$#" -eq 0 ] || die "usage: devenv-admin user key list USER"
            file="$(authorized_keys_path "$username")"
            if [ -f "$file" ]; then
                cat "$file"
            fi
            ;;
        *)
            die "unknown user key action '${action}'"
            ;;
    esac
}
