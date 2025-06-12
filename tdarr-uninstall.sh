#!/usr/bin/env bash

# Tdarr Uninstaller Script for Ubuntu
# Author: supermag
# Description: Secure Tdarr uninstall script

set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo " This script must be run as root. Please run it with:"
  echo "   sudo $0"
  exit 1
fi

# Define the user and groups
TDARR_USER="tdarr"
GROUPS=("media" "video" "render")

# Stop and disable systemd services
echo "Stopping and disabling Tdarr services..."
systemctl stop tdarr-server.service || true
systemctl stop tdarr-node.service || true
systemctl disable tdarr-server.service || true
systemctl disable tdarr-node.service || true

# Remove systemd service files
echo "Removing systemd service files..."
rm -f /etc/systemd/system/tdarr-server.service
rm -f /etc/systemd/system/tdarr-node.service

# Remove Tdarr installation directory
echo "Removing Tdarr installation directory..."
rm -rf /opt/tdarr

# Remove the Tdarr user
if id "$TDARR_USER" &>/dev/null; then
  echo "Removing user '$TDARR_USER'..."
  userdel -r "$TDARR_USER"
else
  echo "User '$TDARR_USER' does not exist."
fi

# Remove groups if they are empty
for grp in "${GROUPS[@]}"; do
  if getent group "$grp" >/dev/null; then
    echo "Checking group '$grp'..."
    if [ -z "$(getent passwd | awk -F: -v grp="$grp" '$4 == grp {print $1}')" ]; then
      echo "Removing group '$grp'..."
      groupdel "$grp"
    else
      echo "Group '$grp' is not empty, not removing."
    fi
  else
    echo "Group '$grp' does not exist."
  fi
done

# List of packages to remove
PACKAGES=(
  curl
  mc
  handbrake
  unzip
  jq
  va-driver-all
  ocl-icd-opencl-dev
  intel-opencl-icd
  mesa-opencl-icd
  vainfo
  intel-gpu-tools
  nvidia-driver-535-server
)

# Remove packages
echo "Removing Tdarr related packages..."
apt-get remove --purge -y "${PACKAGES[@]}" || true

# Clean up unused packages
echo "Cleaning up unused packages..."
apt-get -y autoremove
apt-get -y autoclean

echo "Tdarr uninstallation complete!"
