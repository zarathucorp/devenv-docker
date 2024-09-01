#!/bin/bash

if [ "${USE_GOOGLE_AUTHENTICATOR}" = "true" ]; then 
    cp /path/to/google-authenticator.sh /usr/local/bin/google-authenticator.sh && 
    chmod +x /usr/local/bin/google-authenticator.sh && 
    /usr/local/bin/google-authenticator.sh
fi

# Start supervisord
/usr/bin/supervisord -c /etc/supervisord.conf