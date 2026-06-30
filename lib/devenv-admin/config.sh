managed_config_files() {
    printf '%s\n' \
        "$RSERVER_CONF" \
        "$PAM_FILE" \
        "$SSHD_CONFIG" \
        "$SSHD_DEVENV_CONFIG" \
        "/etc/shiny-server/shiny-server.conf" \
        "/etc/supervisord.conf"
}

config_backup() {
    local output="/home/.devenv/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    local file
    local list_file
    local relative_file

    require_root

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output)
                [ "$#" -ge 2 ] || die "--output requires a file"
                output="$2"
                shift 2
                ;;
            *)
                die "unknown config backup option '${1}'"
                ;;
        esac
    done

    mkdir -p "$(dirname "$output")"
    list_file="$(mktemp)"

    while IFS= read -r file; do
        if [ -e "$file" ]; then
            relative_file="${file#/}"
            printf '%s\n' "$relative_file" >>"$list_file"
        else
            warn "skipping missing config file: ${file}"
        fi
    done < <(managed_config_files)

    if [ ! -s "$list_file" ]; then
        rm -f "$list_file"
        die "no managed config files found"
    fi

    if tar -czf "$output" -C / -T "$list_file"; then
        rm -f "$list_file"
        log "config backup written to ${output}"
    else
        rm -f "$list_file"
        die "failed to create config backup"
    fi
}

config_command() {
    local action="${1:-}"
    shift || true

    case "$action" in
        backup)
            config_backup "$@"
            ;;
        *)
            die "usage: devenv-admin config backup [--output FILE]"
            ;;
    esac
}
