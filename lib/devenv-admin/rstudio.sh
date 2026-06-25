rstudio_reset() {
    local username="$1"
    local home_dir
    local pid
    local pids=""

    require_root
    require_user_exists "$username"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"

    rm -rf "${home_dir}/.local/share/rstudio" "${home_dir}/.config/rstudio"

    if command -v rstudio-server >/dev/null 2>&1; then
        pids="$(rstudio-server active-sessions 2>/dev/null | tail -n +2 | awk -v user="$username" '$0 ~ user { print $1 }' || true)"
        for pid in $pids; do
            rstudio-server kill-session "$pid" || true
        done
    fi

    log "RStudio session state reset for ${username}"
}
