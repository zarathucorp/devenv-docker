#!/bin/bash

# Shiny Server Setting
# sed -i "s/srv\/shiny-server/home\/${USER}\/ShinyApps/g" /etc/shiny-server/shiny-server.conf 
# sed -i "s/var\/log\/shiny-server/home\/${USER}\/ShinyApps\/log/g" /etc/shiny-server/shiny-server.conf
# sed -i "s/shiny\;/${USER}\;/g" /etc/shiny-server/shiny-server.conf

# mkdir -p /root/.config/code-server
# cat <<EOL > /root/.config/code-server/config.yaml
# bind-addr: 0.0.0.0:8443
# auth: password
# password: $PASSWORD
# cert: false
# EOL

# Start Shiny Server
shiny-server &

# Start RStudio Server
rstudio-server start

# Start VSCode Server with authentication enabled
# code-server --config /root/.config/code-server/config.yaml &

# Keep the container running
tail -f /dev/null