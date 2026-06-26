# Zarathu Devenv Docker

R/Shiny, RStudio Server, SSH를 함께 제공하는 회사 개발용 컨테이너입니다.

기본 이미지에는 회사 사용자 계정이나 고정 비밀번호를 만들지 않습니다. 계정은 컨테이너 시작 시 env로 부트스트랩하거나, 실행 후 `devenv-admin`으로 생성합니다.

## Build

```bash
docker build -t devenv-docker:latest .
```

CI는 `Dockerfile`을 사용해 Docker Hub와 GitHub Container Registry에 이미지를 배포합니다.

## Persistent home volume

`/home`은 반드시 이미지/컨테이너 내부가 아니라 별도 Docker volume에 마운트해서 사용합니다. 이렇게 해야 이미지를 업데이트하거나 컨테이너를 새로 만들어도 사용자 파일, Shiny 앱, RStudio 설정, SSH key, OTP secret이 유지됩니다.

```bash
docker volume create zarathu-home
```

실행할 때는 항상 아래처럼 `/home`에 연결합니다.

```bash
-v zarathu-home:/home
```

Linux 계정 자체와 그룹 membership은 `/home`에 저장되지 않습니다. 컨테이너를 새로 만든 뒤에는 `devenv-admin`으로 같은 계정을 다시 생성해야 합니다.

컨테이너를 교체하기 전에는 계정 manifest를 `/home` volume에 export해 두는 것을 권장합니다. 이 manifest에는 UID/GID, shell, home, sudo 여부, `otp_exempt` 여부, SSH public key가 저장됩니다. 비밀번호와 OTP secret은 저장하지 않습니다.

```bash
devenv-admin user export --output /home/.devenv/users.tsv
```

새 컨테이너를 같은 `/home` volume으로 띄운 뒤 manifest를 import하면 기존 파일 ownership과 맞는 UID/GID로 계정을 다시 만들 수 있습니다.

```bash
devenv-admin user import --file /home/.devenv/users.tsv
```

이 이미지는 컨테이너 시작 시 SSH, PAM, Linux 계정, supervisor 설정을 초기화하므로 root로 시작해야 합니다. Kubernetes나 hardened runtime에서 `runAsNonRoot`를 강제하는 구성은 현재 지원하지 않습니다.

## Run without a bootstrap user

```bash
docker run -itd \
  --name zarathu-devenv \
  -p 3838:3838 \
  -p 8787:8787 \
  -p 22:22 \
  -v zarathu-home:/home \
  devenv-docker:latest
```

이 방식으로 시작하면 사용자 계정이 없습니다. 컨테이너에 root로 들어가서 계정을 만듭니다.

```bash
docker exec -it zarathu-devenv bash
devenv-admin user add alice --password 'change-me' --sudo no
```

Shiny 앱은 `http://<host>:3838/alice/<app-name>/` 형태로 접근합니다. RStudio는 `http://<host>:8787`에서 Linux 계정으로 로그인합니다.

## Run with a bootstrap user

비밀번호를 파일로 넘기는 방식을 권장합니다.

```bash
printf '%s' 'change-me' > /srv/zarathu-bootstrap-password

docker run -itd \
  --name zarathu-devenv \
  -p 3838:3838 \
  -p 8787:8787 \
  -p 22:22 \
  -v zarathu-home:/home \
  -v /srv/zarathu-bootstrap-password:/run/secrets/bootstrap-password:ro \
  -e DEVENV_BOOTSTRAP_USER=alice \
  -e DEVENV_BOOTSTRAP_PASSWORD_FILE=/run/secrets/bootstrap-password \
  -e DEVENV_BOOTSTRAP_SUDO=no \
  devenv-docker:latest
```

이미 존재하는 사용자는 기본적으로 비밀번호를 덮어쓰지 않습니다. 덮어써야 하면 `DEVENV_BOOTSTRAP_FORCE_PASSWORD=true`를 추가합니다.

## Account management

컨테이너 안에서 `devenv-admin`을 사용합니다.

인자 없이 실행하면 번호를 선택하는 대화형 메뉴가 열립니다.

```bash
devenv-admin
```

기존처럼 명령을 직접 지정해서 실행할 수도 있습니다.

```bash
devenv-admin user add alice --password 'change-me' --sudo no
devenv-admin user passwd alice
devenv-admin user sudo alice on
devenv-admin user key add alice --ssh-key 'ssh-ed25519 AAAA... alice@example'
devenv-admin user key list alice
devenv-admin user inspect alice
devenv-admin user export --output /home/.devenv/users.tsv
devenv-admin user import --file /home/.devenv/users.tsv
devenv-admin user delete alice --remove-home
```

`devenv-admin`은 컨테이너 안에서 `/usr/local/bin/devenv-admin`으로 실행되고, 내부 구현은 `/usr/local/lib/devenv-admin` 아래 기능별 모듈로 분리됩니다.

## SSH policy

SSH는 VPN 또는 내부망에서만 노출하는 전제입니다. 기본값은 비밀번호 인증 비활성화입니다.

컨테이너 시작 시 설정:

```bash
-e DEVENV_SSH_PASSWORD_AUTH=false
```

실행 중 변경:

```bash
devenv-admin ssh password-auth status
devenv-admin ssh password-auth on
devenv-admin ssh password-auth off
```

SSH 키는 `devenv-admin user key add`로 사용자별 `authorized_keys`에 추가합니다.

## RStudio OTP

RStudio TOTP 로그인을 옵션으로 사용할 수 있습니다. 기본값은 비활성화입니다.

컨테이너 시작 시 OTP PAM 모듈 활성화:

```bash
-e DEVENV_RSERVER_OTP=true
```

실행 중 활성화 및 사용자 초기화:

```bash
devenv-admin otp enable
devenv-admin otp init alice
devenv-admin otp status
devenv-admin otp disable
```

OTP를 켜면 `otp_exempt` 시스템 그룹이 생성됩니다. 일반 사용자는 RStudio 비밀번호 입력창에 비밀번호가 아니라 OTP만 입력합니다. OTP를 면제하고 비밀번호 로그인을 허용할 사용자는 아래 명령으로 관리합니다.

```bash
devenv-admin otp exempt add alice
devenv-admin otp exempt list
devenv-admin otp exempt remove alice
```

`otp_exempt` 사용자는 OTP가 활성화되어 있어도 OTP 없이 기존 비밀번호만으로 로그인할 수 있습니다. OTP가 켜져 있고 `otp_exempt`가 아닌 사용자는 `devenv-admin otp init <user>`로 OTP secret을 먼저 만들어야 로그인할 수 있습니다.

사용자가 터미널에서 직접 `google-authenticator`를 실행해 자기 홈 디렉터리에 OTP secret을 만들어도 됩니다. `devenv-admin otp init <user>`는 root가 같은 초기화 명령을 해당 사용자로 대신 실행해 주는 관리용 편의 명령입니다.

## Operations

상태 점검:

```bash
devenv-admin status
devenv-admin doctor
devenv-admin healthcheck
```

서비스 관리:

```bash
devenv-admin service status all
devenv-admin service restart rstudio-server
devenv-admin service restart shiny-server
devenv-admin service restart sshd
```

로그 확인:

```bash
devenv-admin logs services --lines 120
devenv-admin logs rstudio
devenv-admin logs shiny
devenv-admin logs ssh
devenv-admin logs auth
```

관리 설정 백업:

```bash
devenv-admin config backup --output /home/.devenv/config-backup.tar.gz
```

RStudio 세션 초기화:

```bash
devenv-admin rstudio reset alice
```

Shiny 앱 디렉터리 초기화:

```bash
devenv-admin shiny init alice
```

## Smoke test

테스트 컨테이너에서 새 관리 기능을 한 번에 확인하려면 `devenv-smoke-test`를 실행합니다. 이 스크립트는 테스트 사용자 생성, user inspect/export/import, sudo 토글, SSH key 추가/삭제, SSH 비밀번호 인증 토글, OTP 활성화/면제/초기화/비활성화, RStudio/Shiny 관리 명령, service/log/config 명령, `doctor`, `healthcheck`를 순서대로 실행합니다.

운영 컨테이너에서는 실행하지 마세요. 기본 테스트 사용자 `devenvtest`와 OTP secret 같은 상태가 남고, SSH/RStudio 설정도 테스트 과정에서 변경됩니다.

```bash
docker exec -it zarathu-devenv devenv-smoke-test
```

테스트 사용자명을 바꾸려면 환경변수를 넘깁니다.

```bash
docker exec -it \
  -e DEVENV_TEST_USER=devenvtest2 \
  zarathu-devenv \
  devenv-smoke-test
```

## External access

RStudio와 Shiny를 외부망에 열 경우 컨테이너를 직접 TLS 종단점으로 쓰지 말고, 호스트나 인프라 계층의 reverse proxy를 앞에 둡니다. RStudio는 WebSocket을 사용하므로 proxy에서 WebSocket upgrade와 충분한 timeout을 허용해야 합니다.

권장 노출 모델:

- SSH: VPN 또는 내부망 전용
- RStudio: reverse proxy + TLS + 접근 제어
- Shiny: reverse proxy + TLS + 필요한 앱별 접근 제어

## Package installation

CRAN 패키지는 `zarathu/dependencies/CRAN.R`, GitHub 패키지는 `zarathu/dependencies/REMOTE.R`에서 관리합니다.
