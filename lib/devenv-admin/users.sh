set_user_password() {
    local username="$1"
    local password="$2"

    [ -n "$password" ] || die "password cannot be empty"
    printf '%s:%s\n' "$username" "$password" | chpasswd
    passwd -u "$username" >/dev/null 2>&1 || true
}

user_in_group() {
    local username="$1"
    local group="$2"

    getent group "$group" >/dev/null 2>&1 || return 1
    id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -Fxq "$group"
}

base64_one_line() {
    if base64 --help 2>&1 | grep -q -- '-w'; then
        base64 -w0
    else
        base64 | tr -d '\n'
    fi
}

base64_decode() {
    if base64 --help 2>&1 | grep -q -- '-d'; then
        base64 -d
    else
        base64 -D
    fi
}

is_managed_user_record() {
    local username="$1"
    local uid="$2"
    local home_dir="$3"

    [ "$uid" -ge 1000 ] || return 1
    [ "$uid" -lt 60000 ] || return 1
    [ "$username" != "nobody" ] || return 1
    [[ "$home_dir" = /home/* ]] || return 1
}

encode_authorized_keys() {
    local file="$1"
    local key
    local encoded
    local output=""
    local separator=""

    [ -f "$file" ] || return 0

    while IFS= read -r key || [ -n "$key" ]; do
        [ -n "$key" ] || continue
        encoded="$(printf '%s' "$key" | base64_one_line)"
        output="${output}${separator}${encoded}"
        separator=","
    done <"$file"

    printf '%s' "$output"
}

decode_authorized_key() {
    local encoded="$1"

    printf '%s' "$encoded" | base64_decode
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

user_export() {
    local output="-"
    local destination
    local tmp=""
    local username
    local _password
    local uid
    local gid
    local gecos
    local home_dir
    local shell
    local sudo_state
    local otp_state
    local keys
    local key_file

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output)
                [ "$#" -ge 2 ] || die "--output requires a file"
                output="$2"
                shift 2
                ;;
            *)
                die "unknown user export option '${1}'"
                ;;
        esac
    done

    if [ "$output" = "-" ]; then
        destination="/dev/stdout"
    else
        mkdir -p "$(dirname "$output")"
        tmp="$(mktemp)"
        destination="$tmp"
    fi

    {
        printf '# devenv-admin user manifest v1\n'
        printf 'username\tuid\tgid\tshell\thome\tsudo\totp_exempt\tssh_keys_b64\n'

        while IFS=: read -r username _password uid gid gecos home_dir shell; do
            if ! is_managed_user_record "$username" "$uid" "$home_dir"; then
                continue
            fi

            sudo_state="no"
            user_in_group "$username" sudo && sudo_state="yes"

            otp_state="no"
            user_in_group "$username" "$OTP_EXEMPT_GROUP" && otp_state="yes"

            key_file="${home_dir}/.ssh/authorized_keys"
            keys="$(encode_authorized_keys "$key_file")"

            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$username" "$uid" "$gid" "$shell" "$home_dir" "$sudo_state" "$otp_state" "$keys"
        done < <(getent passwd)
    } >"$destination"

    if [ "$output" != "-" ]; then
        mv "$tmp" "$output"
        log "user manifest exported to ${output}"
    fi
}

ensure_import_group() {
    local username="$1"
    local gid="$2"
    local group_name
    local existing_group

    existing_group="$(getent group | awk -F: -v gid="$gid" '$3 == gid { print $1; exit }')"
    if [ -n "$existing_group" ]; then
        printf '%s' "$existing_group"
        return 0
    fi

    if getent group "$username" >/dev/null 2>&1; then
        group_name="devenv-g${gid}"
    else
        group_name="$username"
    fi

    if getent group "$group_name" >/dev/null 2>&1; then
        die "group '${group_name}' already exists with a different gid"
    fi

    groupadd -g "$gid" "$group_name"
    log "group ${group_name} created with gid ${gid}"
    printf '%s' "$group_name"
}

validate_numeric_id() {
    local value="$1"
    local label="$2"

    [[ "$value" =~ ^[0-9]+$ ]] || die "invalid ${label}: '${value}'"
}

import_user_row() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local shell="$4"
    local home_dir="$5"
    local sudo_state="$6"
    local otp_state="$7"
    local keys_b64="$8"
    local restore_keys="$9"
    local replace_keys="${10}"
    local restore_groups="${11}"
    local create_home="${12}"
    local group_name
    local existing_uid_user
    local current_uid
    local current_gid
    local key_file
    local encoded_key
    local -a encoded_keys=()
    local key
    local useradd_home_flag="-m"

    validate_username "$username"
    validate_numeric_id "$uid" "uid"
    validate_numeric_id "$gid" "gid"
    [[ "$shell" = /* ]] || die "invalid shell for ${username}: '${shell}'"
    [[ "$home_dir" = /home/* ]] || die "invalid home for ${username}: '${home_dir}'"
    sudo_state="$(normalize_yes_no "$sudo_state")"
    otp_state="$(normalize_yes_no "$otp_state")"

    existing_uid_user="$(getent passwd | awk -F: -v uid="$uid" '$3 == uid { print $1; exit }')"
    if [ -n "$existing_uid_user" ] && [ "$existing_uid_user" != "$username" ]; then
        die "uid ${uid} is already used by ${existing_uid_user}; refusing to import ${username}"
    fi

    group_name="$(ensure_import_group "$username" "$gid")"

    if id "$username" >/dev/null 2>&1; then
        current_uid="$(id -u "$username")"
        current_gid="$(id -g "$username")"
        if [ "$current_uid" != "$uid" ] || [ "$current_gid" != "$gid" ]; then
            die "user ${username} already exists with uid:gid ${current_uid}:${current_gid}, manifest has ${uid}:${gid}"
        fi
        log "user ${username} already exists"
    else
        [ "$create_home" = "yes" ] || useradd_home_flag="-M"
        useradd "$useradd_home_flag" -u "$uid" -g "$group_name" -d "$home_dir" -s "$shell" "$username"
        log "user ${username} created with uid:gid ${uid}:${gid}"
    fi

    ensure_shiny_dir "$username"

    if [ "$restore_groups" = "yes" ]; then
        set_user_sudo "$username" "$sudo_state"
        if [ "$otp_state" = "yes" ]; then
            otp_exempt_add "$username"
        else
            otp_exempt_remove "$username"
        fi
    fi

    if [ "$restore_keys" = "yes" ]; then
        key_file="$(authorized_keys_file "$username")"
        if [ "$replace_keys" = "yes" ]; then
            : >"$key_file"
        fi

        if [ -n "$keys_b64" ]; then
            IFS=',' read -r -a encoded_keys <<<"$keys_b64"
            for encoded_key in "${encoded_keys[@]}"; do
                [ -n "$encoded_key" ] || continue
                key="$(decode_authorized_key "$encoded_key")"
                add_ssh_key "$username" "$key"
            done
        fi
    fi
}

user_import() {
    local file=""
    local restore_keys="yes"
    local replace_keys="no"
    local restore_groups="yes"
    local create_home="yes"
    local line_number=0
    local username
    local uid
    local gid
    local shell
    local home_dir
    local sudo_state
    local otp_state
    local keys_b64

    require_root

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --file)
                [ "$#" -ge 2 ] || die "--file requires a path"
                file="$2"
                shift 2
                ;;
            --restore-keys)
                [ "$#" -ge 2 ] || die "--restore-keys requires yes or no"
                restore_keys="$(normalize_yes_no "$2")"
                shift 2
                ;;
            --replace-keys)
                [ "$#" -ge 2 ] || die "--replace-keys requires yes or no"
                replace_keys="$(normalize_yes_no "$2")"
                shift 2
                ;;
            --restore-groups)
                [ "$#" -ge 2 ] || die "--restore-groups requires yes or no"
                restore_groups="$(normalize_yes_no "$2")"
                shift 2
                ;;
            --create-home)
                [ "$#" -ge 2 ] || die "--create-home requires yes or no"
                create_home="$(normalize_yes_no "$2")"
                shift 2
                ;;
            *)
                die "unknown user import option '${1}'"
                ;;
        esac
    done

    [ -n "$file" ] || die "usage: devenv-admin user import --file FILE"
    [ -r "$file" ] || die "cannot read user manifest '${file}'"

    while IFS=$'\t' read -r username uid gid shell home_dir sudo_state otp_state keys_b64 || [ -n "${username:-}" ]; do
        line_number=$((line_number + 1))
        case "${username:-}" in
            "" | \#*)
                continue
                ;;
            username)
                continue
                ;;
        esac

        if [ -z "${uid:-}" ] || [ -z "${gid:-}" ] || [ -z "${shell:-}" ] || [ -z "${home_dir:-}" ] || [ -z "${sudo_state:-}" ] || [ -z "${otp_state:-}" ]; then
            die "invalid manifest row at line ${line_number}"
        fi

        import_user_row "$username" "$uid" "$gid" "$shell" "$home_dir" "$sudo_state" "$otp_state" "${keys_b64:-}" "$restore_keys" "$replace_keys" "$restore_groups" "$create_home"
    done <"$file"
}

count_user_processes() {
    local username="$1"

    if command -v pgrep >/dev/null 2>&1; then
        pgrep -u "$username" 2>/dev/null | wc -l | awk '{ print $1 }'
    else
        ps -u "$username" -o pid= 2>/dev/null | wc -l | awk '{ print $1 }'
    fi
}

count_shiny_apps() {
    local username="$1"
    local home_dir
    local app_dir

    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    app_dir="${home_dir}/ShinyApps"

    if [ -d "$app_dir" ]; then
        find "$app_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | awk '{ print $1 }'
    else
        printf '0\n'
    fi
}

count_ssh_keys() {
    local username="$1"
    local file

    file="$(authorized_keys_path "$username")"
    if [ -f "$file" ]; then
        grep -cv '^[[:space:]]*$' "$file" || true
    else
        printf '0\n'
    fi
}

last_login_summary() {
    local username="$1"

    if command -v lastlog >/dev/null 2>&1; then
        lastlog -u "$username" 2>/dev/null | tail -n +2 | sed -E 's/[[:space:]]+/ /g; s/^ //'
    elif command -v last >/dev/null 2>&1; then
        last -n 1 "$username" 2>/dev/null | head -n 1 | sed -E 's/[[:space:]]+/ /g; s/^ //'
    else
        printf 'unavailable\n'
    fi
}

user_inspect() {
    local username="$1"
    local uid
    local gid
    local group_name
    local home_dir
    local shell
    local sudo_state="no"
    local otp_state="no"
    local otp_secret="missing"
    local shiny_dir="missing"
    local ssh_keys
    local shiny_apps
    local process_count
    local last_login

    require_regular_user_exists "$username"

    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    group_name="$(id -gn "$username")"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    shell="$(getent passwd "$username" | cut -d: -f7)"

    user_in_group "$username" sudo && sudo_state="yes"
    user_in_group "$username" "$OTP_EXEMPT_GROUP" && otp_state="yes"
    [ -f "${home_dir}/.google_authenticator" ] && otp_secret="present"
    [ -d "${home_dir}/ShinyApps" ] && shiny_dir="present"

    ssh_keys="$(count_ssh_keys "$username")"
    shiny_apps="$(count_shiny_apps "$username")"
    process_count="$(count_user_processes "$username")"
    last_login="$(last_login_summary "$username")"

    cat <<EOF
username: ${username}
uid: ${uid}
gid: ${gid}
primary_group: ${group_name}
home: ${home_dir}
shell: ${shell}
sudo: ${sudo_state}
otp_exempt: ${otp_state}
otp_secret: ${otp_secret}
ssh_keys: ${ssh_keys}
shiny_apps_dir: ${shiny_dir}
shiny_apps: ${shiny_apps}
processes: ${process_count}
last_login: ${last_login}
EOF
}
