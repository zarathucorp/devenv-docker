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
    locales \
    vim

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

# Define argument for username and password with default values
ARG USERNAME=limcw
ARG PASSWORD=limcw

# Create the user with specified username and password
RUN /usr/local/bin/create_user.sh ${USERNAME} ${PASSWORD} yes

# Define an argument for using Google Authenticator
ARG USE_GOOGLE_AUTHENTICATOR=false

# If USE_GOOGLE_AUTHENTICATOR is true, copy and run the google-authenticator script
RUN if [ "$USE_GOOGLE_AUTHENTICATOR" = "true" ]; then \
    cp /path/to/google-authenticator.sh /usr/local/bin/google-authenticator.sh && \
    chmod +x /usr/local/bin/google-authenticator.sh && \
    /usr/local/bin/google-authenticator.sh; \
    fi

# Copy supervisord configuration
COPY supervisord.conf /etc/supervisord.conf

# Expose ports
EXPOSE 3838 8787 

# Set the entrypoint
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]