#!/bin/bash

# Get the username from input
read -p "유저 ID 입력: " USERNAME

# RStudio 관련 폴더 삭제
echo "$USERNAME의 RStudio 관련 폴더 삭제 시작"
rm -rf /home/$USERNAME/.local/share/rstudio
rm -rf /home/$USERNAME/.config/rstudio

echo "$USERNAME의 RStudio 관련 폴더 삭제 완료"

# 특정 유저의 세션 삭제
kill_rstudio_session() {
  local USERNAME="$1"

  echo "$USERNAME의 세션 검색 중"
  
  sessions=$(rstudio-server active-sessions | grep "/usr/lib/rstudio-server/bin/rsession -u $USERNAME" | awk '{print $1}')

  if [ -z "$sessions" ]; then
    echo "$USERNAME의 세션 없음. 프로그램 종료"
  else
    echo "$USERNAME의 세션 $session 삭제 시작"
    for session in $sessions; do
      rstudio-server kill-session $session
      echo "$USERNAME의 세션 $session 삭제 완료"
    done
  fi
}

kill_rstudio_session "$USERNAME"
