ensure_shiny_dir() {
    local username="$1"
    local group
    local home_dir

    require_user_exists "$username"
    group="$(primary_group "$username")"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"

    mkdir -p "${home_dir}/ShinyApps"
    if [ -d /srv/shiny-server ]; then
        cp -a /srv/shiny-server/. "${home_dir}/ShinyApps/" 2>/dev/null || true
    fi
    chown -R "${username}:${group}" "${home_dir}/ShinyApps"
}

shiny_init() {
    local username="$1"

    require_root
    ensure_shiny_dir "$username"
    log "ShinyApps initialized for ${username}"
}

shiny_list() {
    local username="$1"
    local home_dir

    require_user_exists "$username"
    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    if [ -d "${home_dir}/ShinyApps" ]; then
        find "${home_dir}/ShinyApps" -maxdepth 1 -mindepth 1 -print
    fi
}
