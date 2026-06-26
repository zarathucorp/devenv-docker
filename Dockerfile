FROM rocker/shiny:4.6.1

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    dirmngr \
    gdebi-core \
    git \
    gnupg \
    libcairo2-dev \
    libuv1-dev \
    libudunits2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libprotobuf-dev \
    libwebp-dev \
    libcurl4-gnutls-dev \
    libpam-google-authenticator \
    libssl-dev \
    libxt-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libsqlite3-dev \
    libxml2-dev \
    locales \
    openssh-server \
    pandoc \
    protobuf-compiler \
    software-properties-common \
    sudo \
    supervisor \
    vim \
    tcl \
    tk \
    wget \
    tzdata \
    && ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime \
    && echo Asia/Seoul > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Seoul

COPY zarathu/dependencies /tmp/zarathu-dependencies

RUN Rscript "/tmp/zarathu-dependencies/CRAN.R" \
    && Rscript "/tmp/zarathu-dependencies/REMOTE.R" \
    && Rscript "/tmp/zarathu-dependencies/Bioconductor.R" \
    && R -e "shinytest::installDependencies()" \
    && rm -rf /tmp/zarathu-dependencies

RUN /rocker_scripts/install_rstudio.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY bin/devenv-admin /usr/local/bin/devenv-admin
COPY lib/devenv-admin /usr/local/lib/devenv-admin
COPY scripts/devenv-smoke-test.sh /usr/local/bin/devenv-smoke-test
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
COPY supervisord.conf /etc/supervisord.conf

RUN chmod +x \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/devenv-admin \
    /usr/local/bin/devenv-smoke-test \
    && mkdir -p /etc/ssh/sshd_config.d /run/sshd

EXPOSE 3838 8787 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD /usr/local/bin/devenv-admin healthcheck

ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
