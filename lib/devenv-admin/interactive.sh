interactive_pause() {
    local ignored

    printf '\n'
    read -r -p "Press Enter to continue..." ignored || true
}

interactive_print_command() {
    local arg

    printf '\n$ devenv-admin'
    for arg in "$@"; do
        printf ' %q' "$arg"
    done
    printf '\n'
}

interactive_run() {
    local stdin_value=""
    local use_stdin="no"
    local status

    if [ "${1:-}" = "--stdin" ]; then
        use_stdin="yes"
        stdin_value="$2"
        shift 2
    fi

    interactive_print_command "$@"

    set +e
    if [ "$use_stdin" = "yes" ]; then
        printf '%s' "$stdin_value" | "$DEVENV_ADMIN_SELF" "$@"
    else
        "$DEVENV_ADMIN_SELF" "$@"
    fi
    status=$?
    set -e

    if [ "$status" -ne 0 ]; then
        printf '[devenv-admin] command exited with status %s\n' "$status" >&2
    fi
    interactive_pause
}

interactive_read() {
    local __var="$1"
    local prompt="$2"
    local value

    read -r -p "$prompt" value || return 1
    printf -v "$__var" '%s' "$value"
}

interactive_read_required() {
    local __var="$1"
    local prompt="$2"
    local value

    while true; do
        interactive_read value "$prompt" || return 1
        if [ -n "$value" ]; then
            printf -v "$__var" '%s' "$value"
            return 0
        fi
        printf 'Value is required.\n'
    done
}

interactive_read_yes_no() {
    local __var="$1"
    local prompt="$2"
    local default_value="$3"
    local value

    while true; do
        read -r -p "${prompt} [${default_value}]: " value || return 1
        value="${value:-$default_value}"
        value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        case "$value" in
            y | yes)
                printf -v "$__var" 'yes'
                return 0
                ;;
            n | no)
                printf -v "$__var" 'no'
                return 0
                ;;
            *)
                printf 'Enter yes or no.\n'
                ;;
        esac
    done
}

interactive_read_optional_yes_no() {
    local __var="$1"
    local prompt="$2"
    local value

    while true; do
        read -r -p "$prompt" value || return 1
        value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        case "$value" in
            "")
                printf -v "$__var" ''
                return 0
                ;;
            y | yes)
                printf -v "$__var" 'yes'
                return 0
                ;;
            n | no)
                printf -v "$__var" 'no'
                return 0
                ;;
            *)
                printf 'Enter yes, no, or leave blank.\n'
                ;;
        esac
    done
}

interactive_read_password() {
    local __var="$1"
    local prompt="$2"
    local allow_empty="$3"
    local password
    local confirm

    while true; do
        read -r -s -p "$prompt" password || {
            printf '\n'
            return 1
        }
        printf '\n'

        if [ -z "$password" ] && [ "$allow_empty" = "yes" ]; then
            printf -v "$__var" ''
            return 0
        fi
        if [ -z "$password" ]; then
            printf 'Password cannot be empty.\n'
            continue
        fi

        read -r -s -p "Confirm password: " confirm || {
            printf '\n'
            return 1
        }
        printf '\n'

        if [ "$password" = "$confirm" ]; then
            printf -v "$__var" '%s' "$password"
            return 0
        fi
        printf 'Passwords do not match.\n'
    done
}

interactive_user_add() {
    local username
    local password
    local sudo_state
    local force_password
    local ssh_key
    local -a args

    interactive_read_required username "Username: " || return
    args=(user add "$username")

    interactive_read_password password "Password (blank to skip): " yes || return
    if [ -n "$password" ]; then
        args+=(--password-stdin)
        interactive_read_yes_no force_password "Overwrite password if user already exists?" no || return
        if [ "$force_password" = "yes" ]; then
            args+=(--force-password)
        fi
    fi

    interactive_read_optional_yes_no sudo_state "Set sudo? yes/no, blank to leave unchanged: " || return
    if [ -n "$sudo_state" ]; then
        args+=(--sudo "$sudo_state")
    fi

    interactive_read ssh_key "SSH public key (blank to skip): " || return
    if [ -n "$ssh_key" ]; then
        args+=(--ssh-key "$ssh_key")
    fi

    if [ -n "$password" ]; then
        interactive_run --stdin "$password" "${args[@]}"
    else
        interactive_run "${args[@]}"
    fi
}

interactive_user_delete() {
    local username
    local remove_home
    local -a args

    interactive_read_required username "Username: " || return
    args=(user delete "$username")
    interactive_read_yes_no remove_home "Remove home directory?" no || return
    if [ "$remove_home" = "yes" ]; then
        args+=(--remove-home)
    fi
    interactive_run "${args[@]}"
}

interactive_user_passwd() {
    local username
    local password

    interactive_read_required username "Username: " || return
    interactive_read_password password "New password (blank to use passwd prompt): " yes || return
    if [ -n "$password" ]; then
        interactive_run --stdin "$password" user passwd "$username" --password-stdin
    else
        interactive_run user passwd "$username"
    fi
}

interactive_user_sudo() {
    local username
    local sudo_state

    interactive_read_required username "Username: " || return
    interactive_read_yes_no sudo_state "Enable sudo?" no || return
    if [ "$sudo_state" = "yes" ]; then
        interactive_run user sudo "$username" on
    else
        interactive_run user sudo "$username" off
    fi
}

interactive_user_key() {
    local action="$1"
    local username
    local ssh_key

    interactive_read_required username "Username: " || return
    case "$action" in
        add)
            interactive_read_required ssh_key "SSH public key: " || return
            interactive_run user key add "$username" --ssh-key "$ssh_key"
            ;;
        remove)
            interactive_read_required ssh_key "SSH public key to remove: " || return
            interactive_run user key remove "$username" --ssh-key "$ssh_key"
            ;;
        list)
            interactive_run user key list "$username"
            ;;
    esac
}

interactive_user_menu() {
    local choice

    while true; do
        cat <<'MENU'

User management
  1) Add user
  2) Delete user
  3) Change password
  4) Toggle sudo
  5) Add SSH key
  6) Remove SSH key
  7) List SSH keys
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1) interactive_user_add ;;
            2) interactive_user_delete ;;
            3) interactive_user_passwd ;;
            4) interactive_user_sudo ;;
            5) interactive_user_key add ;;
            6) interactive_user_key remove ;;
            7) interactive_user_key list ;;
            0) return 0 ;;
            *) printf 'Unknown selection.\n' ;;
        esac
    done
}

interactive_ssh_menu() {
    local choice

    while true; do
        cat <<'MENU'

SSH password authentication
  1) Show status
  2) Enable password auth
  3) Disable password auth
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1) interactive_run ssh password-auth status ;;
            2) interactive_run ssh password-auth on ;;
            3) interactive_run ssh password-auth off ;;
            0) return 0 ;;
            *) printf 'Unknown selection.\n' ;;
        esac
    done
}

interactive_otp_exempt_menu() {
    local choice
    local username

    while true; do
        cat <<'MENU'

OTP exemption group
  1) Add user to otp_exempt
  2) Remove user from otp_exempt
  3) List otp_exempt users
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1)
                interactive_read_required username "Username: " || return
                interactive_run otp exempt add "$username"
                ;;
            2)
                interactive_read_required username "Username: " || return
                interactive_run otp exempt remove "$username"
                ;;
            3)
                interactive_run otp exempt list
                ;;
            0)
                return 0
                ;;
            *)
                printf 'Unknown selection.\n'
                ;;
        esac
    done
}

interactive_otp_menu() {
    local choice
    local username

    while true; do
        cat <<'MENU'

RStudio OTP
  1) Show status
  2) Enable OTP
  3) Disable OTP
  4) Initialize user OTP secret
  5) Manage otp_exempt users
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1) interactive_run otp status ;;
            2) interactive_run otp enable ;;
            3) interactive_run otp disable ;;
            4)
                interactive_read_required username "Username: " || return
                interactive_run otp init "$username"
                ;;
            5) interactive_otp_exempt_menu ;;
            0) return 0 ;;
            *) printf 'Unknown selection.\n' ;;
        esac
    done
}

interactive_rstudio_menu() {
    local choice
    local username

    while true; do
        cat <<'MENU'

RStudio
  1) Reset user session
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1)
                interactive_read_required username "Username: " || return
                interactive_run rstudio reset "$username"
                ;;
            0)
                return 0
                ;;
            *)
                printf 'Unknown selection.\n'
                ;;
        esac
    done
}

interactive_shiny_menu() {
    local choice
    local username

    while true; do
        cat <<'MENU'

Shiny
  1) Initialize user ShinyApps directory
  2) List user Shiny apps
  0) Back
MENU
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1)
                interactive_read_required username "Username: " || return
                interactive_run shiny init "$username"
                ;;
            2)
                interactive_read_required username "Username: " || return
                interactive_run shiny list "$username"
                ;;
            0)
                return 0
                ;;
            *)
                printf 'Unknown selection.\n'
                ;;
        esac
    done
}

interactive_menu() {
    local choice

    cat <<'BANNER'
devenv-admin interactive menu
BANNER

    while true; do
        cat <<'MENU'

Main menu
  1) Status
  2) Doctor
  3) Healthcheck
  4) User management
  5) SSH password authentication
  6) RStudio OTP
  7) RStudio
  8) Shiny
  9) Help
  0) Exit
MENU
        read -r -p "Select: " choice || {
            printf '\n'
            return 0
        }
        case "$choice" in
            1) interactive_run status ;;
            2) interactive_run doctor ;;
            3) interactive_run healthcheck ;;
            4) interactive_user_menu ;;
            5) interactive_ssh_menu ;;
            6) interactive_otp_menu ;;
            7) interactive_rstudio_menu ;;
            8) interactive_shiny_menu ;;
            9) usage; interactive_pause ;;
            0) return 0 ;;
            *) printf 'Unknown selection.\n' ;;
        esac
    done
}
