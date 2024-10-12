#!/bin/bash

if [ -z "$1" ]; then
    echo "사용법: $0 <유저이름>"
    exit 1
fi

USERNAME=$1
USER_HOME="/home/$USERNAME"

if [ ! -d "$USER_HOME" ]; then
    echo "유저 디렉토리 '$USER_HOME'가 존재하지 않습니다."
    exit 2
fi

rm -rf "$USER_HOME/.local/share/rstudio"
rm -rf "$USER_HOME/.config/rstudio"

PIDs=$(rstudio-server active-sessions | tail -n +2 | awk -v user="$USERNAME" '$0 ~ user {print $1}')

if [ -z "$PIDs" ]; then
    echo "유저 '$USERNAME'의 RStudio 세션이 없습니다."
    exit 3 
else
    for PID in $PIDs; do
        echo "유저 '$USERNAME'의 RStudio 세션 $PID을 종료합니다."
        rstudio-server kill-session "$PID"
    done
fi

exit 0
