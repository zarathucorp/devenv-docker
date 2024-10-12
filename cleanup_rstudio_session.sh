#!/bin/bash

# Check if username is provided as a parameter
if [ -z "$1" ]; then
    echo "사용법: $0 <유저이름>"
    exit 1
fi

USERNAME=$1

# Remove RStudio directories for the user
rm -rf "/home/$USERNAME/.local/share/rstudio"
rm -rf "/home/$USERNAME/.config/rstudio"

# Get the list of active RStudio sessions for the user
PIDs=$(rstudio-server active-sessions | tail -n +2 | awk -v user="$USERNAME" '$0 ~ user {print $1}')

if [ -z "$PIDs" ]; then
    echo "유저 '$USERNAME'의 RStudio 세션이 없습니다."
else
    # Kill each active session for the user
    for PID in $PIDs; do
        echo "유저 '$USERNAME'의 RStudio 세션 $PID을 종료합니다."
        rstudio-server kill-session "$PID"
    done
fi
