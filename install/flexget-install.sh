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

FLEXGET_PYTHON_VERSION=3.14
PYTHON_VERSION="$FLEXGET_PYTHON_VERSION" setup_uv

msg_info "Installing FlexGet (uv-based version)"
$STD uv tool install --python $FLEXGET_PYTHON_VERSION flexget[all]
msg_ok "Installed FlexGet"

motd_ssh
customize
cleanup_lxc
