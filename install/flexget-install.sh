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
export PATH="/root/.local/bin:$PATH"
msg_ok "Installed uv"

msg_info "Installing FlexGet (uv-based version)"
$STD uv tool install --python 3.13 flexget[locked,all]
msg_ok "Installed FlexGet"


#https://raw.githubusercontent.com/Flexget/Flexget/develop/tests/api_tests/raw_config.yml
#https://github.com/Flexget/Flexget/releases/download/v${RELEASE}/flexget-${RELEASE}.tar.gz

#  RELEASE=$(curl -fsSL https://api.github.com/repos/Flexget/Flexget/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
#  temp_file=$(mktemp)
#  mkdir -p /tmp/flexget_release_${RELEASE}
#  curl -fsSL "https://github.com/Flexget/Flexget/releases/download/v${RELEASE}/flexget-${RELEASE}.tar.gz" -o "$temp_file"
#  tar zxf "$temp_file" --strip-components=1 -C /tmp/flexget_release_${RELEASE}
#  cp /tmp/flexget_release_${RELEASE}/flexget-${RELEASE}-/ "${HOME}/.flexget/config.yml"




msg_info "Creating basic FlexGet config.yml"
mkdir /.flexget/

FLEXGET_CONFIG_FILE="${HOME}/.flexget/config.yml"
if [ -f "${FLEXGET_CONFIG_FILE}" ]; then
    echo -e "${INFO}${YW} The FlexGet config file already exists so we will not modify it."
else
    echo -e "${INFO}${YW} The FlexGet config file not found, so downloading a default config.yml from github."
	curl -fsSL "https://raw.githubusercontent.com/Flexget/Flexget/develop/tests/api_tests/raw_config.yml" -o "${HOME}/.flexget/config.yml"
	
	#verify if we were able to download the test config file
	if [ -f "${FLEXGET_CONFIG_FILE}" ]; then
		echo -e "${INFO}${YW} The FlexGet latest test config file was pulled from github."
	else
		echo -e "${INFO}${YW} The could not pull test config from github, using a generic one as last resort"
		cat <<EOF > "${HOME}/.flexget/config.yml"
tasks:
  test:
    rss:
      url: http://test/rss
    mock:
      - title: entry 1
EOF
	fi
fi


msg_ok "Created ~/.flexget/config.yml"
msg_ok "You should edit the ~/.flexget/config.yml to suite your needs"

msg_info "Starting FlexGet daemon"
flexget daemon start -d --autoreload-config


msg_info "Cleaning up"
rm -f "${temp_file"}
rm -f /tmp/flexget_release_${RELEASE}/*

echo -e "${INFO}${YW} FlexGet is configured as Deamon. Use 'schedules' in you config" 
echo -e "${INFO}${YW} https://flexget.com/Plugins/Daemon/scheduler#period"

motd_ssh
customize
cleanup_lxc
