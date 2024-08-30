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

# RUN apt-get install -y libc6 libcurl4 libicu60-dev libreadline7

# Install Shiny Server Dependencies
# RUN su - -c "R -e \"install.packages('shiny')\""

# Install 차라투 개발 Dependencies
COPY zarathu/dependencies /temp
RUN ls /temp
RUN Rscript "/temp/CRAN.R"
RUN Rscript "/temp/REMOTE.R"
# RUN R -e "install.packages(c('shiny', 'quarto', 'rmarkdown', 'markdown', 'DT', 'data.table', 'ggplot2', 'devtools', 'epiDisplay', 'tableone', 'svglite', 'plotROC', 'pROC', 'labelled', 'geepack', 'lme4', 'PredictABEL', 'shinythemes', 'maxstat', 'manhattanly', 'Cairo', 'future', 'promises', 'GGally', 'fst', 'blogdown', 'metafor', 'roxygen2', 'MatchIt', 'distill', 'lubridate', 'testthat', 'rversions', 'spelling', 'rhub', 'remotes', 'ggpmisc', 'RefManageR', 'tidyr', 'shinytest', 'ggpubr', 'kableExtra', 'timeROC', 'survC1', 'survIDINRI', 'colourpicker', 'shinyWidgets', 'devEMF', 'see', 'aws.s3', 'epiR', 'zip', 'keyring', 'shinymanager', 'kappaSize', 'irr', 'gsDesign', 'jtools', 'svydiags', 'shinyBS', 'highcharter', 'forestplot', 'qgraph', 'bootnet', 'rhandsontable', 'meta', 'showtext', 'officer', 'rvg', 'httr', 'shinybrowser', 'pins', 'paws.storage'))"
# RUN R -e "remotes::install_github(c('jinseob2kim/jstable', 'jinseob2kim/jskm', 'emitanaka/shinycustomloader', 'Appsilon/shiny.i18n', 'metrumresearchgroup/sinew', 'jinseob2kim/jsmodule', 'yihui/xaringan', 'emitanaka/anicon'))"
RUN R -e "shinytest::installDependencies()" 

# Install Shiny Server
# RUN wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.22.1017-amd64.deb \
#     && gdebi -n shiny-server-1.5.22.1017-amd64.deb \
#     && rm shiny-server-1.5.22.1017-amd64.deb

# Install RStudio Server
# COPY install_rstudio_server.sh /usr/local/bin/install_rstudio_server.sh 
RUN /rocker_scripts/install_rstudio.sh
# RUN wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2024.04.2-764-amd64.deb \
#     && gdebi -n rstudio-server-2024.04.2-764-amd64.deb \
#     && rm rstudio-server-2024.04.2-764-amd64.deb

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
# 8443

# Set the entrypoint
ENTRYPOINT ["bin/bash", "/usr/local/bin/entrypoint.sh"]