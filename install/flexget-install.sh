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

msg_info "Setting up uv python"
PYTHON_VERSION="3.13" setup_uv
#echo 'export PATH=/root/.local/bin:$PATH' >>~/.bashrc
#export PATH="/root/.local/bin:$PATH"
msg_ok "Installed uv"

msg_info "Adding flexget bin to PATH"
[[ ":$PATH:" != *":/root/.local/bin:"* ]] &&
  echo -e "\nexport PATH=\"/root/.local/bin:\$PATH\"" >>~/.bashrc &&
  source ~/.bashrc
msg_ok "PATH updated"

msg_info "Installing FlexGet (uv-based version)"
$STD uv tool install --python 3.13 flexget[locked,all]
msg_ok "Installed FlexGet"

msg_info "Creating symlink to config for easy access"
mkdir /root/.flexget
ln -s /root/.flexget /root/flexget
msg_ok "Symlink '/root/flexget' added"

msg_info "Setup FlexGet log rotation"
cat <<EOF > /etc/logrotate.d/flexget-log
/root/.flexget/flexget.log {
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

msg_info "Creating basic FlexGet config.yml"
TEMP_CONFIG_FILE=$(mktemp) 
FLEXGET_CONFIG_FILE="/root/.flexget/config.yml"
mkdir -p "$(dirname "${FLEXGET_CONFIG_FILE}")"

if [ -f "${FLEXGET_CONFIG_FILE}" ]; then
    echo -e "${INFO}${YW} The FlexGet config file already exists so we will not modify it.${CL}"
else
    echo -e "${INFO}${YW} The FlexGet config file not found, so downloading a default config.yml from github.${CL}"
    curl -fsSL "https://raw.githubusercontent.com/Flexget/Flexget/develop/tests/api_tests/raw_config.yml" -o "${TEMP_CONFIG_FILE}"
    
    if [ $? -eq 0 ]; then
        mkdir -p "$(dirname "${FLEXGET_CONFIG_FILE}")"
        mv "${TEMP_CONFIG_FILE}" "${FLEXGET_CONFIG_FILE}" 
        
        echo -e "${INFO}${YW} The FlexGet latest test config file was pulled from github.${CL}"
    else
        echo -e "${INFO}${YW} Could not pull test config from github, using a generic one as last resort${CL}"

        # Write generic config directly to final file (no need for temp file here)
        cat <<EOF > "${FLEXGET_CONFIG_FILE}"
tasks:
  test:
    rss:
      url: http://test/rss
    mock:
      - title: entry 1
EOF
    fi
fi

msg_ok "Created /root/.flexget/config.yml"
msg_ok "You should edit /root/.flexget/config.yml to suite your needs"

echo -e "${INFO}${YW} Starting FlexGet daemon${CL}"
flexget daemon start -d --autoreload-config
echo -e ""
msg_ok "Started FlexGet"

msg_info "Setup flexget to run at startup"
cat <<EOF >/etc/systemd/system/flexget.service
[Unit]
Description=Flexget Automation Daemon
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/flexget daemon start --autoreload-config
Restart=always
RestartSec=5s
#StandardOutput=journal
#StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now flexget

msg_info "Cleaning up"
#rm -f "${temp_file}"
#rm -f /tmp/flexget_release_${RELEASE}/*
rm -f "${TEMP_CONFIG_FILE}"

echo -e "${INFO}${YW} FlexGet is configured as Deamon. Use 'schedules' in you config${CL}" 
echo -e "${INFO}${YW} https://flexget.com/Plugins/Daemon/scheduler#period${CL}"

motd_ssh
customize
cleanup_lxc
