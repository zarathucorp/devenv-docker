#!/bin/bash

if [ "${USE_GOOGLE_AUTHENTICATOR}" = "true" ]; then 
    cp /path/to/google-authenticator.sh /usr/local/bin/google-authenticator.sh && 
    chmod +x /usr/local/bin/google-authenticator.sh && 
    /usr/local/bin/google-authenticator.sh
fi

if ! mkdir -p /run/sshd; then
    echo "Failed to create /run/sshd" >&2
    exit 1
fi

if ! ssh-keygen -A; then
    echo "Failed to generate SSH host keys" >&2
    exit 1
fi

# Start supervisord
/usr/bin/supervisord -c /etc/supervisord.conf
