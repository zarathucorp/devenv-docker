SUPERVISOR_SOCKET="${SUPERVISOR_SOCKET:-/var/run/supervisor.sock}"

require_supervisor_running() {
    command -v supervisorctl >/dev/null 2>&1 || die "supervisorctl is not installed"
    [ -S "$SUPERVISOR_SOCKET" ] || die "supervisor is not running"
}

normalize_service_name() {
    local service="${1:-}"

    case "$service" in
        all)
            printf 'all'
            ;;
        rstudio | rstudio-server)
            printf 'rstudio-server'
            ;;
        shiny | shiny-server)
            printf 'shiny-server'
            ;;
        ssh | sshd)
            printf 'sshd'
            ;;
        *)
            die "unknown service '${service}'. Use rstudio-server, shiny-server, sshd, or all."
            ;;
    esac
}

service_targets() {
    local service="$1"

    service="$(normalize_service_name "$service")"
    if [ "$service" = "all" ]; then
        printf '%s\n' shiny-server rstudio-server sshd
    else
        printf '%s\n' "$service"
    fi
}

service_status() {
    local service="${1:-all}"
    local target

    require_supervisor_running

    if [ "$service" = "all" ]; then
        supervisorctl status
    else
        while IFS= read -r target; do
            supervisorctl status "$target"
        done < <(service_targets "$service")
    fi
}

service_control() {
    local action="$1"
    local service="${2:-}"
    local target

    [ -n "$service" ] || die "usage: devenv-admin service ${action} SERVICE|all"
    require_supervisor_running

    case "$action" in
        start | stop | restart)
            ;;
        *)
            die "unknown service action '${action}'"
            ;;
    esac

    while IFS= read -r target; do
        supervisorctl "$action" "$target"
    done < <(service_targets "$service")
}

service_command() {
    local action="${1:-}"
    shift || true

    case "$action" in
        status)
            [ "$#" -le 1 ] || die "usage: devenv-admin service status [SERVICE|all]"
            service_status "${1:-all}"
            ;;
        start | stop | restart)
            [ "$#" -eq 1 ] || die "usage: devenv-admin service ${action} SERVICE|all"
            service_control "$action" "$1"
            ;;
        *)
            die "usage: devenv-admin service status [SERVICE|all] | start|stop|restart SERVICE|all"
            ;;
    esac
}
