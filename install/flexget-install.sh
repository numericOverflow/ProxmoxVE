#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: numericOverflow
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://flexget.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Setting up uv Python"
PYTHON_VERSION="3.13" setup_uv
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
}
EOF
msg_ok "Log rotation added"

#echo -e "${INFO}${YW} Generating FlexGet default HTTPS certificates${CL}"
msg_info "Generating FlexGet default HTTPS certificates"
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
	msg_ok "The FlexGet config file already exists so we will not modify it"
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
msg_ok "Created FlexGet config file located at '/etc/flexget/config.yml'"
fi


if command -v whiptail >/dev/null 2>&1; then
  if whiptail --title "FlexGet Web-UI" --yesno "Would you like to enable the FlexGet Web-UI now?" 8 60; then
    enable_webui=1
  else
    enable_webui=0
  fi
fi

if [ "${enable_webui}" = "1" ]; then
  GEN_PWD=$(openssl rand -base64 99 | tr -dc 'a-zA-Z0-9' | head -c16)

  if command -v whiptail >/dev/null 2>&1; then
      PWD_OUT=$(whiptail --inputbox "Please enter the web-ui password (leave blank to generate):" 8 60 "${GEN_PWD}" 3>&1 1>&2 2>&3)
      WHIPTAIL_STATUS=$?

      if [ ${WHIPTAIL_STATUS} -eq 0 ]; then
          FLEXGET_PWD="${PWD_OUT:-$GEN_PWD}"
      else
          FLEXGET_PWD="${GEN_PWD}"
      fi
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
   msg_error "FlexGet Web-UI config skipped"
fi

msg_info "Setup flexget to run at startup"
cat <<EOF >/etc/systemd/system/flexget.service
[Unit]
Description=Flexget Daemon
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/etc/flexget
ExecStart=/root/.local/bin/flexget daemon start --autoreload-config
ExecStop=/root/.local/bin/flexget daemon stop
ExecReload=/root/.local/bin/flexget daemon reload --autoreload-config

[Install]
WantedBy=multi-user.target
EOF
msg_ok "FlexGet will run at startup"

#echo -e "${INFO}${YW} Starting FlexGet daemon${CL}"
msg_info "Starting FlexGet daemon"
$STD systemctl enable -q --now flexget
msg_ok "Started FlexGet"

msg_info "Cleaning up"
#rm -f "${temp_file}"
#rm -f /tmp/flexget_release_${RELEASE}/*
$STD rm -f "${TEMP_CONFIG_FILE}"
$STD rm -f "${TEMP_WEBGUI_ENABLE}"
apt-get -y autoremove
apt-get -y autoclean
msg_ok "Cleanup complete"

echo -e "${INFO}${YW} Created FlexGet config file is located at '/etc/flexget/config.yml'${CL}"
echo -e "${INFO}${YW} FlexGet is configured as Daemon. Use 'schedules' plugin in your config${CL}"
echo -e "${INFO}${YW}     See: https://flexget.com/Plugins/Daemon/scheduler${CL}"

echo -e "${INFO}${YW} You Flexget Web-UI password is:  ${FLEXGET_PWD}${CL}"
echo -e "${INFO}${YW} Be sure to save this somewhere safe${CL}"
echo -e "${INFO}${YW} To update Flexget Web-UI password in the future, use 'flexget web passwd NeW-sTrOnG-pAsSwOrD_hErE12!'${CL}"

motd_ssh
customize
cleanup_lxc
