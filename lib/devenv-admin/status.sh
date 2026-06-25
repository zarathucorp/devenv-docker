status() {
    printf 'SSH password authentication: '
    ssh_password_auth_status
    printf 'RStudio OTP: '
    otp_status

    if command -v supervisorctl >/dev/null 2>&1 && [ -S /var/run/supervisor.sock ]; then
        supervisorctl status || true
    else
        printf 'supervisor: not running\n'
    fi
}

doctor() {
    local failed=0
    local command_name

    for command_name in useradd usermod groupadd gpasswd getent chpasswd sshd supervisorctl Rscript; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            warn "missing command: ${command_name}"
            failed=1
        fi
    done

    [ -f /etc/shiny-server/shiny-server.conf ] || { warn "missing Shiny Server config"; failed=1; }
    [ -f /etc/supervisord.conf ] || { warn "missing supervisor config"; failed=1; }
    [ -d /etc/rstudio ] || { warn "missing /etc/rstudio"; failed=1; }

    if command -v sshd >/dev/null 2>&1; then
        mkdir -p /run/sshd
        ssh-keygen -A >/dev/null 2>&1 || true
        sshd -t || failed=1
    fi

    status
    return "$failed"
}

healthcheck() {
    if ! command -v supervisorctl >/dev/null 2>&1 || [ ! -S /var/run/supervisor.sock ]; then
        return 1
    fi

    supervisorctl status | awk '
      $1 ~ /^(shiny-server|rstudio-server|sshd)$/ {
        seen[$1] = 1
        if ($2 != "RUNNING") failed = 1
      }
      END {
        if (!seen["shiny-server"] || !seen["rstudio-server"] || !seen["sshd"]) failed = 1
        exit failed
      }
    '
    curl -fsS http://127.0.0.1:3838/ >/dev/null
}
