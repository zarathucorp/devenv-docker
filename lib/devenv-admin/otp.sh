ensure_otp_exempt_group() {
    require_root

    if ! getent group "$OTP_EXEMPT_GROUP" >/dev/null 2>&1; then
        groupadd --system "$OTP_EXEMPT_GROUP"
        log "group ${OTP_EXEMPT_GROUP} created"
    fi
}

write_rstudio_pam_base() {
    mkdir -p "$(dirname "$PAM_FILE")"
    cat >"$PAM_FILE" <<'EOF'
# Managed by devenv-admin.
@include common-auth
@include common-account
@include common-session
EOF
}

write_rstudio_pam_otp() {
    mkdir -p "$(dirname "$PAM_FILE")"
    cat >"$PAM_FILE" <<EOF
# Managed by devenv-admin.
# Users in ${OTP_EXEMPT_GROUP} skip OTP and use password authentication.
auth [success=1 default=ignore] pam_succeed_if.so user ingroup ${OTP_EXEMPT_GROUP}
${OTP_PAM_LINE}
auth requisite pam_succeed_if.so user ingroup ${OTP_EXEMPT_GROUP}
@include common-auth
@include common-account
@include common-session
EOF
}

set_rserver_conf_value() {
    local key="$1"
    local value="$2"

    mkdir -p "$(dirname "$RSERVER_CONF")"
    touch "$RSERVER_CONF"

    if grep -Eq "^${key}=" "$RSERVER_CONF"; then
        sed -i -E "s|^${key}=.*$|${key}=${value}|" "$RSERVER_CONF"
    else
        printf '%s=%s\n' "$key" "$value" >>"$RSERVER_CONF"
    fi
}

otp_enable() {
    require_root
    ensure_otp_exempt_group
    write_rstudio_pam_otp
    set_rserver_conf_value "auth-pam-require-password-prompt" "0"
    log "RStudio OTP PAM module enabled with ${OTP_EXEMPT_GROUP} exemption group"
    restart_service_if_running "rstudio-server"
}

otp_disable() {
    require_root
    write_rstudio_pam_base
    log "RStudio OTP PAM module disabled"
    restart_service_if_running "rstudio-server"
}

otp_status() {
    if [ -f "$PAM_FILE" ] && grep -q 'pam_google_authenticator\.so' "$PAM_FILE"; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
}

otp_init() {
    local username="$1"

    require_root
    require_user_exists "$username"
    command -v google-authenticator >/dev/null 2>&1 || die "google-authenticator is not installed"

    runuser -u "$username" -- google-authenticator -t -d -f -r 3 -R 30 -w 3
}

otp_exempt_add() {
    local username="$1"

    require_root
    require_user_exists "$username"
    ensure_otp_exempt_group
    usermod -aG "$OTP_EXEMPT_GROUP" "$username"
    log "user ${username} added to ${OTP_EXEMPT_GROUP}"
}

otp_exempt_remove() {
    local username="$1"

    require_root
    require_user_exists "$username"
    if getent group "$OTP_EXEMPT_GROUP" >/dev/null 2>&1; then
        gpasswd -d "$username" "$OTP_EXEMPT_GROUP" >/dev/null 2>&1 || true
    fi
    log "user ${username} removed from ${OTP_EXEMPT_GROUP}"
}

otp_exempt_list() {
    if getent group "$OTP_EXEMPT_GROUP" >/dev/null 2>&1; then
        getent group "$OTP_EXEMPT_GROUP" | awk -F: '{ print $4 }' | tr ',' '\n' | sed '/^$/d'
    fi
}
