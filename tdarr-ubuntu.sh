#!/usr/bin/env bash

# Tdarr Installer Script for Ubuntu 25.04 Bare Metal
# Secure setup: creates unprivileged user, supports NVIDIA and hardware acceleration

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "  This script must be run as root. Please run it with:"
  echo "   sudo $0"
  exit 1
fi

set -e

# Prompt for group
read -rp "Enter group name for media access (default: media): " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-media}

echo "Installing Dependencies..."
apt-get update
apt-get install -y curl sudo mc handbrake-cli unzip jq

echo "Creating 'tdarr' user..."
useradd -r -s /usr/sbin/nologin -d /opt/tdarr -m tdarr
groupadd -f "$GROUP_NAME"
usermod -aG "$GROUP_NAME",video,render tdarr

echo "Setting up Hardware Acceleration..."
apt-get install -y va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools

# NVIDIA drivers
apt-get install -y nvidia-driver-535 libnvidia-encode-535 libnvidia-compute-535 libnvidia-decode-535 libnvidia-ifr1-535
usermod -aG video tdarr

# Set device permissions
chgrp -R video /dev/dri || true
chmod 755 /dev/dri || true
chmod 660 /dev/dri/* || true

echo "Installing Tdarr..."
mkdir -p /opt/tdarr
cd /opt/tdarr
chown tdarr:tdarr /opt/tdarr

# Get latest Tdarr Updater
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

echo "Creating systemd services..."

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

echo "Enabling and starting services..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now tdarr-server.service
systemctl enable --now tdarr-node.service

echo "Cleaning up..."
apt-get -y autoremove
apt-get -y autoclean

echo " Tdarr installation complete and running!"
echo "You can now access the Tdarr web interface on port 8265."
