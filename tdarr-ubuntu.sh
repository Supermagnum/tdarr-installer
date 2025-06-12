#!/usr/bin/env bash

# Tdarr Installer Script for Ubuntu 25.04 Bare Metal
# Author: supermag
# Description: Secure Tdarr install with NVIDIA and Intel GPU support

set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo " This script must be run as root. Please run it with:"
  echo "   sudo $0"
  exit 1
fi

# Prompt for media group name
read -rp "Enter group name for media access (default: media): " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-media}

echo "Checking required packages..."

# List of required packages
PACKAGES=(
  curl
  mc
  handbrake-cli
  unzip
  jq
  va-driver-all
  ocl-icd-libopencl1
  intel-opencl-icd
  vainfo
  intel-gpu-tools
  nvidia-driver-535
  libnvidia-encode-535
  libnvidia-compute-535
  libnvidia-decode-535
  libnvidia-ifr1-535
)

# Install missing packages
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo " Installing missing packages: ${MISSING_PKGS[*]}"
  apt-get update
  apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "All required packages are already installed."
fi

# Create tdarr user if not exists
echo " Ensuring user 'tdarr' exists..."
if id "tdarr" &>/dev/null; then
  echo " User 'tdarr' already exists."
else
  useradd -r -s /usr/sbin/nologin -d /opt/tdarr -m tdarr
  echo "Created user 'tdarr'."
fi

# Ensure required groups exist and user is in them
echo " Verifying groups and memberships..."
for grp in "$GROUP_NAME" video render; do
  if getent group "$grp" >/dev/null; then
    echo "Group '$grp' exists."
  else
    echo " Creating group '$grp'..."
    groupadd "$grp"
  fi
  usermod -aG "$grp" tdarr
done

# Set /dev/dri permissions if exists
if [ -d /dev/dri ]; then
  echo " Adjusting /dev/dri permissions..."
  chgrp -R video /dev/dri || true
  chmod 755 /dev/dri || true
  chmod 660 /dev/dri/* || true
fi

echo " Installing Tdarr..."
mkdir -p /opt/tdarr
cd /opt/tdarr
chown tdarr:tdarr /opt/tdarr

# Download latest Tdarr_Updater
echo " Fetching latest Tdarr Updater..."
RELEASE=$(curl -s https://f000.backblazeb2.com/file/tdarrs/versions.json | jq -r '.Tdarr_Updater | to_entries[] | select(.key | test("linux_x64")) | .value' | head -n 1)
wget -q "$RELEASE" -O Tdarr_Updater.zip
sudo -u tdarr unzip -o Tdarr_Updater.zip
rm -f Tdarr_Updater.zip
chmod +x Tdarr_Updater
sudo -u tdarr ./Tdarr_Updater &>/dev/null

echo "Creating systemd services..."

# Tdarr Server service
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

# Tdarr Node service
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

echo " Enabling and starting services..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now tdarr-server.service
systemctl enable --now tdarr-node.service

echo " Cleaning up..."
apt-get -y autoremove
apt-get -y autoclean

echo "Tdarr installation complete and running!"
echo "Access the web interface at: http://<your-ip>:8265"
