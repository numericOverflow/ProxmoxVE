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
 
#  if [[ -d /opt/open-webui ]]; then
#    msg_warn "Legacy installation detected — migrating to uv based install..."
#    msg_info "Stopping Service"
#    systemctl stop open-webui
#    msg_ok "Stopped Service"
#
#    msg_info "Creating Backup"
#    mkdir -p /opt/open-webui-backup
#    cp -a /opt/open-webui/backend/data /opt/open-webui-backup/data || true
#    cp -a /opt/open-webui/.env /opt/open-webui-backup/.env || true
#    msg_ok "Created Backup"
#
#    msg_info "Removing legacy installation"
#    rm -rf /opt/open-webui
#    rm -rf /root/.open-webui || true
#    msg_ok "Removed legacy installation"
#
#    msg_info "Installing uv-based Open-WebUI"
#    PYTHON_VERSION="3.14" setup_uv
#    $STD uv tool install --python 3.14 flexget[all]
#    msg_ok "Installed uv-based Open-WebUI"
#
#    msg_info "Restoring data"
#    mkdir -p /root/.open-webui
#    cp -a /opt/open-webui-backup/data/* /root/.open-webui/ || true
#    cp -a /opt/open-webui-backup/.env /root/.env || true
#    rm -rf /opt/open-webui-backup || true
#    msg_ok "Restored data"
#
#    msg_info "Recreating Service"
#    cat <<EOF >/etc/systemd/system/open-webui.service
#[Unit]
#Description=Open WebUI Service
#After=network.target
#
#[Service]
#Type=simple
#Environment=DATA_DIR=/root/.open-webui
#EnvironmentFile=-/root/.env
#ExecStart=/root/.local/bin/open-webui serve
#WorkingDirectory=/root
#Restart=on-failure
#RestartSec=5
#User=root
#
#[Install]
#WantedBy=multi-user.target
#EOF
#
#    $STD systemctl daemon-reload
#    systemctl enable -q --now open-webui
#    msg_ok "Recreated Service"
#
#    msg_ok "Migration completed"
#    exit 0
#  fi

#  if [[ ! -d /root/.open-webui ]]; then
#    msg_error "No ${APP} Installation Found!"
#    exit
#  fi

  msg_info "Setting up uv python"
  PYTHON_VERSION="3.13" setup_uv
  export PATH="/root/.local/bin:$PATH"
  msg_ok "Installed uv"

  msg_info "Updating FlexGet (uv-based version)"
  $STD uv tool upgrade --python 3.13 flexget[locked,all]
  #systemctl restart open-webui
  msg_ok "Updated FlexGet"
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
