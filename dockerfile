FROM rocker/shiny:4.4.1

ENV debian_frontend=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    wget \
    gdebi-core \
    pandoc \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libxml2-dev \
    software-properties-common \
    dirmngr \
    gnupg \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    build-essential \ 
    locales

# Install supervisord
RUN apt-get install -y supervisor

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# Install 차라투 개발 Dependencies
COPY zarathu/dependencies /temp

RUN Rscript "/temp/CRAN.R"
RUN Rscript "/temp/REMOTE.R"
RUN R -e "shinytest::installDependencies()" 

# Install RStudio Server
RUN /rocker_scripts/install_rstudio.sh

# Install VSCode Server
# RUN curl -fsSL https://code-server.dev/install.sh | sh

# Copy scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY create_user.sh /usr/local/bin/create_user.sh
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/create_user.sh
RUN /usr/local/bin/create_user.sh limcw limcw

# Copy supervisord configuration
COPY supervisord.conf /etc/supervisord.conf

# Expose ports
EXPOSE 3838 8787 

# Set the entrypoint
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]