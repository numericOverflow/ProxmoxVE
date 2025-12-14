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

  if [[ ! -d /etc/flexget ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  msg_info "Stop existing Flexget daemon (if exists)"
  systemctl stop flexget
  msg_ok "Started FlexGet"

  msg_info "Updating uv python"
  PYTHON_VERSION="3.13" setup_uv
  msg_ok "Updated uv"

  msg_info "Updating FlexGet (uv-based version)"
  $STD uv tool upgrade --python 3.13 flexget[locked,all]
  msg_ok "Updated FlexGet"
  
  msg_info "Starting FlexGet daemon"
  flexget daemon start -d --autoreload-config
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
