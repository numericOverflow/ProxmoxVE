#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/numericOverflow/ProxmoxVE/flexget/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: numericOverflow
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://flexget.com/

APP="FlexGet"
var_tags="${var_tags:-arr;usenet;downloader}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-25}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
 
  msg_info "Stop existing Flexget daemon (if exists)"
  TIMEOUT=60
  SLEEP_INTERVAL=2  

  # Check if the process is running using case-insensitive search (-i)
  if pgrep -fi "${APP}" > /dev/null; then
      echo "INFO: ${APP} is running, stopping before update..."
      flexget daemon stop 
      
      echo "INFO: Waiting up to ${TIMEOUT} seconds for ${APP} to stop..."
      
      TIMER=0
      # Loop while the process is running AND the timer hasn't exceeded the timeout
      # pgrep -fi ensures case-insensitive rechecking
      while pgrep -fi "${APP}" > /dev/null && [ $TIMER -lt $TIMEOUT ]; do
          sleep $SLEEP_INTERVAL
          TIMER=$(( TIMER + SLEEP_INTERVAL ))
      done
  
      # Final check to determine the outcome
      if pgrep -fi "${APP}" > /dev/null; then
          echo "ERROR: Timeout reached! ${APP} process did not stop within ${TIMEOUT} seconds."
      else
          echo "SUCCESS: ${APP} stopped successfully."
      fi
  else
      echo "INFO: ${APP} is NOT running."
  fi
  
  msg_info "Setting up uv python"
  PYTHON_VERSION="3.13" setup_uv
  msg_ok "Updated uv"

  msg_info "Updating FlexGet (uv-based version)"
  #$STD uv tool upgrade --python 3.13 flexget[locked,all]
  #systemctl restart open-webui
  msg_ok "Updated FlexGet"
  
  msg_info "Starting FlexGet daemon"
  echo -e "\n"
  flexget daemon start -d --autoreload-config
  echo -e "\n"

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${INFO}${YW} (assuming you have 'web_server: yes' in your config.yml)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5050${CL}"
