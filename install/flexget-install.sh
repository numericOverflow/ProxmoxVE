#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: numericOverflow
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://flexget.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
#source <(curl -fsSL https://raw.githubusercontent.com/numericOverflow/ProxmoxVE/flexget/misc/build.func)

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

echo -e "FUNCTIONS_FILE_PATH:"
echo -e "$FUNCTIONS_FILE_PATH"

msg_info "Setting up uv Python"
PYTHON_VERSION="3.13" setup_uv
#echo 'export PATH=/root/.local/bin:$PATH' >>~/.bashrc
#export PATH="/root/.local/bin:$PATH"
msg_ok "Installed uv"

msg_info "Adding flexget bin to PATH"
[[ ":${PATH}:" != *":/root/.local/bin:"* ]] &&
  echo -e "\nexport PATH=\"/root/.local/bin:\$PATH\"" >>~/.bashrc &&
  source ~/.bashrc
msg_ok "PATH updated"

msg_info "Creating config directories"
mkdir -p /etc/flexget
mkdir -p /etc/flexget/ssl/
msg_ok "Created directories"

msg_info "Creating symlinks to config for easy access"
ln -s /etc/flexget /root/.flexget
ln -s /etc/flexget /root/flexget
msg_ok "Symlink '/root/flexget' added"

msg_info "Installing FlexGet (uv-based version)"
$STD uv tool install --python 3.13 flexget[locked,all]
msg_ok "Installed FlexGet"

msg_info "Setup FlexGet log rotation"
cat <<EOF > /etc/logrotate.d/flexget-log
/etc/flexget/flexget.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0600 root root
    su root root
}
EOF
msg_ok "Log rotation added"

echo -e "${INFO}${YW} Generating FlexGet default HTTPS certificates${CL}"
if [ ! -f /etc/flexget/ssl/flexget.pem ] || [ ! -f /etc/flexget/ssl/flexget.key ]; then
  $STD openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/O=Flexget Web-UI/OU=Dummy Certificate/CN=localhost" -keyout /etc/flexget/ssl/flexget.key -out /etc/flexget/ssl/flexget.pem
  chmod 600 /etc/flexget/ssl/flexget.pem
  chmod 600 /etc/flexget/ssl/flexget.key
fi
msg_ok "Certs created"  

msg_info "Creating basic FlexGet config.yml"
TEMP_CONFIG_FILE=$(mktemp) 
FLEXGET_CONFIG_FILE="/etc/flexget/config.yml"
mkdir -p "$(dirname "${FLEXGET_CONFIG_FILE}")"

if [ -f "${FLEXGET_CONFIG_FILE}" ]; then
    echo -e "${INFO}${YW} The FlexGet config file already exists so we will not modify it.${CL}"
else
	# Write generic config directly to final file (no need for temp file here)
	cat <<EOF > "${FLEXGET_CONFIG_FILE}"
#https://flexget.com/Plugins/Daemon/scheduler
schedules:
  #Run every task once an hour
  - tasks: '*'
    interval:
      hours: 1

#Basic task structure - configure this
tasks:
  test:
    rss:
      url: http://test/rss
    mock:
      - title: entry 1
EOF
fi
msg_ok "Created FlexGet config file located at '/etc/flexget/config.yml'"

if command -v whiptail >/dev/null 2>&1; then
  if whiptail --title "FlexGet Web-UI" --yesno "Would you like to enable the FlexGet Web-UI now?" 8 60; then
    enable_webui=1
  else
    enable_webui=0
  fi
fi

if [ "${enable_webui}" = "1" ]; then
  echo -e "${INFO}${YW} Configuring FlexGet Web-UI${CL}"
  
  GEN_PWD=$(openssl rand -base64 99 | tr -dc 'a-zA-Z0-9' | head -c16)

  if command -v whiptail >/dev/null 2>&1; then
      
      PWD_OUT=$(whiptail --inputbox "Please enter the web-ui password (leave blank to generate):" 8 60 "${GEN_PWD}" 3>&1 1>&2 2>&3)
      WHIPTAIL_STATUS=$?
  
      if [ ${WHIPTAIL_STATUS} -eq 0 ]; then
          FLEXGET_PWD="${PWD_OUT:-$GEN_PWD}"
      else
          FLEXGET_PWD="${GEN_PWD}"
      fi
  else
      read -r -p "${TAB3}Please enter the web-ui password [${GEN_PWD}]:" FLEXGET_PWD
      FLEXGET_PWD="${FLEXGET_PWD:-$GEN_PWD}"
  fi

  msg_info "Setting Flexget Web-UI password"
  $STD flexget web passwd "${FLEXGET_PWD}"
  msg_ok "Web-UI password set"

  if grep -q '^web_server:' "${FLEXGET_CONFIG_FILE}"; then
    msg_ok "Web server config already present. Skipping."
  else
    TEMP_WEBGUI_ENABLE=$(mktemp)
    {
    cat <<'EOF'
web_server:
  bind: 0.0.0.0
  port: 5050
  ssl_certificate: '/etc/flexget/ssl/flexget.pem'
  ssl_private_key: '/etc/flexget/ssl/flexget.key'
  web_ui: yes

EOF
    cat "${FLEXGET_CONFIG_FILE}"
    } > "$TEMP_WEBGUI_ENABLE" && \
    cp -fp "$TEMP_WEBGUI_ENABLE" "${FLEXGET_CONFIG_FILE}"
    msg_ok "Web-UI config added to file."
  fi
  msg_ok "Web-UI config complete"
else
  echo -e "${INFO}${YW} FlexGet Web-UI config skipped${CL}"
fi

msg_info "Setup flexget to run at startup"
cat <<EOF >/etc/systemd/system/flexget.service
[Unit]
Description=Flexget Daemon
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
WorkingDirectory=/etc/flexget
ExecStart=/root/.local/bin/flexget daemon start --autoreload-config
ExecStop=/root/.local/bin/flexget daemon stop
ExecReload=/root/.local/bin/flexget daemon reload --autoreload-config

[Install]
WantedBy=multi-user.target
EOF

echo -e "${INFO}${YW} Starting FlexGet daemon${CL}"
$STD systemctl enable -q --now flexget
echo -e ""
msg_ok "Started FlexGet"

msg_info "Cleaning up"
#rm -f "${temp_file}"
#rm -f /tmp/flexget_release_${RELEASE}/*
$STD rm -f "${TEMP_CONFIG_FILE}"
$STD rm -f "${TEMP_WEBGUI_ENABLE}"

echo -e "${INFO}${YW} Created FlexGet config file is located at '/etc/flexget/config.yml'${CL}" 
echo -e "${INFO}${YW} FlexGet is configured as Daemon. Use 'schedules' in your config${CL}"
echo -e "${INFO}${YW} https://flexget.com/Plugins/Daemon/scheduler${CL}"

msg_info "You Flexget Web-UI password is:  ${FLEXGET_PWD}"
msg_info "Be sure to save this somewhere safe"
msg_info "To update Flexget Web-UI password in the future, use 'flexget web passwd NeW-sTrOnG-pAsSwOrD_hErE12!'"

motd_ssh
customize
cleanup_lxc
