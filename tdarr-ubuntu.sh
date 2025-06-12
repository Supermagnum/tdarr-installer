#!/usr/bin/env bash

# Tdarr Installer Script for Ubuntu 25.04 Bare Metal
# Author: supermag (revised)
# Description: Secure Tdarr install with GPU support and fallback URL

set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please run it with:"
  echo "  sudo $0"
  exit 1
fi

# Prompt for media group name
read -rp "Enter group name for media access (default: media): " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-media}

echo "Checking required packages..."

# Required packages
PACKAGES=(
  curl mc handbrake unzip jq
  va-driver-all
  ocl-icd-opencl-dev intel-opencl-icd mesa-opencl-icd
  vainfo intel-gpu-tools
  nvidia-driver-535-server
)

MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "Installing missing packages: ${MISSING_PKGS[*]}"
  apt-get update
  apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "All required packages already installed."
fi

# Create tdarr user
echo "Ensuring user 'tdarr' exists..."
if id "tdarr" &>/dev/null; then
  echo "User 'tdarr' exists."
else
  useradd -r -s /usr/sbin/nologin -d /opt/tdarr -m tdarr
  echo "Created user 'tdarr'."
fi

# Group memberships
echo "Verifying groups..."
for grp in "$GROUP_NAME" video render; do
  if ! getent group "$grp" >/dev/null; then
    echo "Creating group '$grp'..."
    groupadd "$grp"
  else
    echo "Group '$grp' exists."
  fi
  usermod -aG "$grp" tdarr
done

# /dev/dri permissions
if [ -d /dev/dri ]; then
  echo "Adjusting /dev/dri permissions..."
  chgrp -R video /dev/dri || true
  chmod 755 /dev/dri || true
  chmod 660 /dev/dri/* || true
fi

echo "Installing Tdarr..."
mkdir -p /opt/tdarr && chown tdarr:tdarr /opt/tdarr
cd /opt/tdarr

echo "Fetching latest Tdarr Updater URL..."

VERSIONS=$(curl -sf https://f000.backblazeb2.com/file/tdarrs/versions.json) || {
  echo "❌ Network error reaching versions.json — using fallback URL"
  VERSIONS=""
}

RELEASE=$(printf '%s' "$VERSIONS" \
  | jq -r '.Tdarr_Updater // empty | to_entries[]? | select(.key | test("linux_x64|linux_arm64")) | .value' \
  | head -n1)

if [[ -z "$RELEASE" || "$RELEASE" == "null" ]]; then
  echo "⚠️ Couldn't parse versions.json — using fallback URL"
  RELEASE="https://storage.tdarr.io/versions/2.17.01/linux_arm64/Tdarr_Updater.zip"
fi

echo "Downloading: $RELEASE"
wget -q "$RELEASE" -O Tdarr_Updater.zip

echo "Extracting updater..."
sudo -u tdarr unzip -o Tdarr_Updater.zip >/dev/null 2>&1
rm -f Tdarr_Updater.zip
chmod +x Tdarr_Updater
sudo -u tdarr ./Tdarr_Updater &>/dev/null

echo "Creating systemd service files..."

cat <<EOF >/etc/systemd/system/tdarr-server.service
[Unit]
Description=Tdarr Server Daemon
After=network.target

[Service]
User=tdarr
Group=tdarr
Type=simple
WorkingDirectory=/opt/tdarr/Tdarr_Server
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

echo "Enabling services..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now tdarr-server.service
systemctl enable --now tdarr-node.service

echo "Cleaning up..."
apt-get -y autoremove
apt-get -y autoclean

echo
echo "✅ Tdarr installation complete!"
echo "👉 Access via http://<your-ip>:8265"
