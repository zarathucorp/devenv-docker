#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <username> <password> <root>"
    echo "<root> should be 'yes' to add the user to the sudoers group, or 'no' to skip."
    exit 1
fi

USERNAME=$1
PASSWORD=$2
IS_ROOT=$3

# Add the user and set the password
useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Optionally add the user to sudoers
if [ "$IS_ROOT" == "yes" ]; then
    usermod -aG sudo $USERNAME
    echo "User $USERNAME added to the sudoers group."
fi

# Create shiny directory for the user
mkdir -p /home/$USERNAME/ShinyApps
chown -R $USERNAME:$USERNAME /home/$USERNAME/ShinyApps
cp -r /srv/shiny-server/* /home/$USERNAME/ShinyApps

echo "User $USERNAME created successfully."