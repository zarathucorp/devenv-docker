#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Add the user and set the password
useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Add the user to sudoers
usermod -aG sudo $USERNAME

# Create shiny directory for the user
mkdir -p /home/$USERNAME/ShinyApps
chown -R $USERNAME:$USERNAME /home/$USERNAME/ShinyApps
cp -r /srv/shiny-server/* /home/$USERNAME/ShinyApps

echo "User $USERNAME created successfully."