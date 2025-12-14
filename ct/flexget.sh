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
 
  msg_ok "Stop existing Flexget daemon (if exists)"
  
  TIMEOUT=90
  SLEEP_INTERVAL=2  
  if pgrep -fi "${APP}" > /dev/null; then
      echo -e "${INFO}${YW} ${APP} is running, attempting graceful stop..."
	  flexget daemon stop
	  echo -e ""
      msg_info "Waiting up to ${TIMEOUT}s for ${APP} to stop..."
      
      END_TIME=$(( $(date +%s) + TIMEOUT ))
      until ! pgrep -fi "${APP}" > /dev/null || [ $(date +%s) -ge $END_TIME ]; do
          sleep $SLEEP_INTERVAL
      done
  
      # Final status check and kill if still exists
      if pgrep -fi "${APP}" > /dev/null; then
          msg_info "Graceful stop failed. Killing ${APP}..."
          pkill -9 -f -i "${APP}"

          if ! pgrep -fi "${APP}" > /dev/null; then
              msg_ok "${APP} force-killed successfully."
          else
              msg_error "FATAL ERROR: Failed to kill ${APP} process."
              exit 1
          fi
      else
          msg_ok "${APP} stopped successfully."
      fi
  else
      msg_ok "${APP} is NOT running."
  fi
  
  msg_info "Updating uv python"
  PYTHON_VERSION="3.13" setup_uv
  msg_ok "Updated uv"

  msg_info "Updating FlexGet (uv-based version)"
  #$STD uv tool upgrade --python 3.13 flexget[locked,all]
  #systemctl restart open-webui
  msg_ok "Updated FlexGet"
  
  echo -e "${INFO}${YW} Starting FlexGet daemon${CL}"
  flexget daemon start -d --autoreload-config
  echo -e ""
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:5050${CL}"
