DEFAULT_LOG_LINES="${DEFAULT_LOG_LINES:-120}"

print_file_tail() {
    local file="$1"
    local lines="$2"

    if [ -f "$file" ]; then
        printf '\n==> %s <==\n' "$file"
        tail -n "$lines" "$file"
        return 0
    fi
    return 1
}

print_glob_tail() {
    local pattern="$1"
    local lines="$2"
    local matched=0
    local file

    for file in $pattern; do
        [ -e "$file" ] || continue
        matched=1
        print_file_tail "$file" "$lines" || true
    done

    [ "$matched" -eq 1 ]
}

print_supervisor_tail() {
    local program="$1"
    local stream="$2"
    local lines="$3"

    if command -v supervisorctl >/dev/null 2>&1 && [ -S "$SUPERVISOR_SOCKET" ]; then
        printf '\n==> supervisor:%s:%s <==\n' "$program" "$stream"
        supervisorctl tail "$program" "$stream" 2>/dev/null | tail -n "$lines" || true
        return 0
    fi
    return 1
}

logs_services() {
    local lines="$1"
    local program

    if command -v supervisorctl >/dev/null 2>&1 && [ -S "$SUPERVISOR_SOCKET" ]; then
        supervisorctl status || true
        for program in shiny-server rstudio-server sshd; do
            print_supervisor_tail "$program" stdout "$lines" || true
            print_supervisor_tail "$program" stderr "$lines" || true
        done
    else
        warn "supervisor is not running; service stdout/stderr is usually available via docker logs on the host"
    fi
}

logs_rstudio() {
    local lines="$1"
    local found=0

    print_glob_tail "/var/log/rstudio/rstudio-server/*.log" "$lines" && found=1
    print_glob_tail "/var/log/rstudio/*.log" "$lines" && found=1
    print_supervisor_tail rstudio-server stdout "$lines" && found=1
    print_supervisor_tail rstudio-server stderr "$lines" && found=1

    [ "$found" -eq 1 ] || warn "no RStudio logs found inside the container"
}

logs_shiny() {
    local lines="$1"
    local found=0

    print_glob_tail "/var/log/shiny-server/*.log" "$lines" && found=1
    print_supervisor_tail shiny-server stdout "$lines" && found=1
    print_supervisor_tail shiny-server stderr "$lines" && found=1

    [ "$found" -eq 1 ] || warn "no Shiny logs found inside the container"
}

logs_ssh() {
    local lines="$1"
    local found=0

    print_file_tail "/var/log/auth.log" "$lines" && found=1
    print_file_tail "/var/log/syslog" "$lines" && found=1
    print_supervisor_tail sshd stdout "$lines" && found=1
    print_supervisor_tail sshd stderr "$lines" && found=1

    [ "$found" -eq 1 ] || warn "no SSH logs found inside the container"
}

logs_auth() {
    local lines="$1"
    local found=0

    print_file_tail "/var/log/auth.log" "$lines" && found=1
    print_file_tail "/var/log/syslog" "$lines" && found=1
    print_glob_tail "/var/log/rstudio/rstudio-server/*.log" "$lines" && found=1

    [ "$found" -eq 1 ] || warn "no auth logs found inside the container"
}

logs_command() {
    local target="${1:-}"
    local lines="$DEFAULT_LOG_LINES"

    [ -n "$target" ] || die "usage: devenv-admin logs services|rstudio|shiny|ssh|auth [--lines N]"
    shift || true

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --lines)
                [ "$#" -ge 2 ] || die "--lines requires a number"
                validate_numeric_id "$2" "line count"
                lines="$2"
                shift 2
                ;;
            *)
                die "unknown logs option '${1}'"
                ;;
        esac
    done

    case "$target" in
        services)
            logs_services "$lines"
            ;;
        rstudio)
            logs_rstudio "$lines"
            ;;
        shiny)
            logs_shiny "$lines"
            ;;
        ssh | sshd)
            logs_ssh "$lines"
            ;;
        auth)
            logs_auth "$lines"
            ;;
        *)
            die "unknown log target '${target}'"
            ;;
    esac
}
