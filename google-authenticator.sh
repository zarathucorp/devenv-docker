#!/bin/bash

apt-get update
apt-get install -y libpam-google-authenticator

# Define the paths for the files to be modified or created
PAM_FILE="/etc/pam.d/rstudio"
RSTUDIO_CONF="/etc/rstudio/rserver.conf"

# Create the /etc/pam.d/rstudio file if it does not exist and add the necessary lines
if [ ! -f "$PAM_FILE" ]; then
    echo "Creating $PAM_FILE"
    {
        echo "auth required pam_google_authenticator.so"
        echo "@include common-account"
        echo "@include common-session"
    } > "$PAM_FILE"
else
    echo "Modifying $PAM_FILE"
    if ! grep -q "auth required pam_google_authenticator.so" "$PAM_FILE"; then
        echo "Adding auth required pam_google_authenticator.so to $PAM_FILE"
        echo "auth required pam_google_authenticator.so" >> "$PAM_FILE"
    fi
    if ! grep -q "@include common-account" "$PAM_FILE"; then
        echo "Adding @include common-account to $PAM_FILE"
        echo "@include common-account" >> "$PAM_FILE"
    fi
    if ! grep -q "@include common-session" "$PAM_FILE"; then
        echo "Adding @include common-session to $PAM_FILE"
        echo "@include common-session" >> "$PAM_FILE"
    fi
fi

# Create the /etc/rstudio/rserver.conf file if it does not exist and add the necessary lines
if [ ! -f "$RSTUDIO_CONF" ]; then
    echo "Creating $RSTUDIO_CONF"
    {
        echo "# Server Configuration File"
        echo "auth-pam-require-password-prompt=0"
    } > "$RSTUDIO_CONF"
else
    echo "Modifying $RSTUDIO_CONF"
    if ! grep -q "# Server Configuration File" "$RSTUDIO_CONF"; then
        echo "# Server Configuration File" >> "$RSTUDIO_CONF"
    fi
    if ! grep -q "auth-pam-require-password-prompt=0" "$RSTUDIO_CONF"; then
        echo "Adding auth-pam-require-password-prompt=0 to $RSTUDIO_CONF"
        echo "auth-pam-require-password-prompt=0" >> "$RSTUDIO_CONF"
    fi
fi

echo "Configuration completed successfully."