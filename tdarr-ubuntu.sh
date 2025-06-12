#!/usr/bin/env bash

# Tdarr Installer Script for Ubuntu 25.04 Bare Metal
# Author: supermag (updated by ChatGPT)
# Description: Secure Tdarr install with NVIDIA and Intel GPU support
# Handles manual Tdarr_Server and Tdarr_Node downloads

set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo " This script must be run as root. Please run it with:"
  echo "   sudo $0"
  exit 1
fi

read -rp "Enter group name for media access (default: media): " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-media}

echo "Checking required packages..."

PACKAGES=(
  curl
  mc
  handbrake-cli
  unzip
  jq
  vainfo
  intel-gpu-tools
  ocl-icd-libopencl1
  intel-opencl-icd
  va-driver-all
  nvidia-driver-535
  libnvidia-encode-535
  libnvidia-compute-535
  libnvidia-decode-535
  libnvidia-ifr1-535
)

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

echo "Ensuring user 'tdarr' exists..."
if id "tdarr" &>/dev/null; then
  echo "User 'tdarr' already exists."
else
  useradd -r -s /usr/sbin/nologin -d /opt/tdarr -m tdarr
  echo "Created user 'tdarr'."
fi

echo "Verifying groups and memberships..."
for grp in "$GROUP_NAME" video render; do
  if getent group "$grp" >/dev/null; then
    echo "Group '$grp' exists."
  else
    echo "Creating group '$grp'..."
    groupadd "$grp"
  fi
  usermod -aG "$grp" tdarr
done

if [ -d /dev/dri ]; then
  echo "Adjusting /dev/dri permissions..."
  chgrp -R video /dev/dri || true
  chmod 755 /dev/dri || true
  chmod 660 /dev/dri/* || true
fi

mkdir -p /opt/tdarr
chown tdarr:tdarr /opt/tdarr

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TAG="linux_x64" ;;
  aarch64) ARCH_TAG="linux_arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

TDARR_VERSION="2.17.01"
BASE_URL="https://storage.tdarr.io/versions/$TDARR_VERSION"

echo "Downloading Tdarr_Updater for architecture: $ARCH_TAG"
wget -q "$BASE_URL/$ARCH_TAG/Tdarr_Updater.zip" -O /opt/tdarr/Tdarr_Updater.zip
chown tdarr:tdarr /opt/tdarr/Tdarr_Updater.zip

echo "Extracting Tdarr_Updater..."
sudo -u tdarr unzip -o /opt/tdarr/Tdarr_Updater.zip -d /opt/tdarr/
chmod +x /opt/tdarr/Tdarr_Updater

echo "Downloading Tdarr_Server and Tdarr_Node zips manually..."
wget -q "$BASE_URL/$ARCH_TAG/Tdarr_Server.zip" -O /opt/tdarr/Tdarr_Server.zip
wget -q "$BASE_URL/$ARCH_TAG/Tdarr_Node.zip" -O /opt/tdarr/Tdarr_Node.zip
chown tdarr:tdarr /opt/tdarr/Tdarr_Server.zip /opt/tdarr/Tdarr_Node.zip

echo "Extracting Tdarr_Server..."
sudo -u tdarr unzip -o /opt/tdarr/Tdarr_Server.zip -d /opt/tdarr/
chmod +x /opt/tdarr/Tdarr_Server/Tdarr_Server

echo "Extracting Tdarr_Node..."
sudo -u tdarr unzip -o /opt/tdarr/Tdarr_Node.zip -d /opt/tdarr/
chmod +x /opt/tdarr/Tdarr_Node/Tdarr_Node

echo "Cleaning up zip files..."
rm -f /opt/tdarr/Tdarr_Updater.zip /opt/tdarr/Tdarr_Server.zip /opt/tdarr/Tdarr_Node.zip

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

echo "Enabling and starting Tdarr services..."
systemctl daemon-reload
systemctl enable --now tdarr-server.service
systemctl enable --now tdarr-node.service

echo
echo "Waiting 5 seconds for services to stabilize..."
sleep 5
echo
echo "✅ Tdarr installation complete!"
echo "👉 Access via http://<your-ip>:8265"
