#!/usr/bin/env bash

# Updated for Ubuntu 25.04 Bare Metal
# Secure: Runs Tdarr under unprivileged user and asks for group membership
# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo " This script must be run as root. Please run it with:"
  echo "   sudo $0"
  exit 1
fi

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

read -rp "Enter group name for media access (default: media): " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-media}

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y curl sudo mc handbrake-cli unzip jq
msg_ok "Installed Dependencies"

msg_info "Creating tdarr User"
useradd -r -s /usr/sbin/nologin -d /opt/tdarr -m tdarr
groupadd -f "$GROUP_NAME"
usermod -aG "$GROUP_NAME",video,render tdarr
msg_ok "User 'tdarr' created and added to groups: $GROUP_NAME, video, render"

msg_info "Setting Up Hardware Acceleration"
$STD apt-get -y install va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools
chgrp -R video /dev/dri || true
chmod 755 /dev/dri || true
chmod 660 /dev/dri/* || true
msg_ok "Hardware Acceleration Set Up"

msg_info "Installing Tdarr"
mkdir -p /opt/tdarr
cd /opt/tdarr
chown tdarr:tdarr /opt/tdarr

if command -v jq >/dev/null 2>&1; then
  RELEASE=$(curl -s https://f000.backblazeb2.com/file/tdarrs/versions.json | jq -r '.Tdarr_Updater | to_entries[] | select(.key | test("linux_x64")) | .value' | head -n 1)
else
  RELEASE=$(curl -s https://f000.backblazeb2.com/file/tdarrs/versions.json | grep -oP '(?<="Tdarr_Updater": ")[^"]+' | grep linux_x64 | head -n 1)
fi

wget -q "$RELEASE" -O Tdarr_Updater.zip
sudo -u tdarr unzip Tdarr_Updater.zip
rm -f Tdarr_Updater.zip
chmod +x Tdarr_Updater
sudo -u tdarr ./Tdarr_Updater &>/dev/null
msg_ok "Tdarr Installed"

msg_info "Creating Services"

cat <<EOF >/etc/systemd/system/tdarr-server.service
[Unit]
Description=Tdarr Server Daemon
After=network.target

[Service]
User=tdarr
Group=tdarr
Type=simple
WorkingDirectory=/opt/tdarr/Tdarr_Server
ExecStartPre=/opt/tdarr/Tdarr_Updater
ExecStart=/opt/tdarr/Tdarr_Server/Tdarr_Server
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/tdarr-node.service
[Unit]
Description=Tdarr Node Daemon
After=network.target
Requires=tdarr-server.service

[Service]
User=tdarr
Group=tdarr
Type=simple
WorkingDirectory=/opt/tdarr/Tdarr_Node
ExecStart=/opt/tdarr/Tdarr_Node/Tdarr_Node
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

chown -R tdarr:tdarr /opt/tdarr

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now tdarr-server.service
systemctl enable --now tdarr-node.service
msg_ok "Services Created and Started"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
