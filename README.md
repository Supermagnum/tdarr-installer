# tdarr-installer
This script installs Tdarr on a bare metal ubuntu server.
It also creates the necessary services so tdarr starts automatically on boot. These services are run under a 
under unprivileged user as it is generally bad to run these as root.

What tdarr is can be read here:
https://home.tdarr.io/
The .sh file installs tdarr on Ubuntu server.
sourced from:
https://github.com/tteck/Proxmox/blob/main/install/tdarr-install.sh


!!The modified script is not tested!!
It is located here:
https://github.com/Supermagnum/tdarr-installer/blob/main/tdarr-ubuntu.sh

Install with:
git clone https://github.com/Supermagnum/tdarr-installer.git

Run with: sudo ./tdarr-ubuntu.sh

After running the script:

Run nvidia-smi after reboot to confirm GPU is working:

nvidia-smi
---
Reconfigure Tdarr to Use NVIDIA GPU

Make sure FFmpeg inside Tdarr nodes uses the GPU via h264_nvenc, hevc_nvenc, etc.

No need to install ffmpeg system-wide unless you're customizing transcode scripts.


---

Check device permissions:

ls -la /dev/nvidia*

They should be owned by root:video with group read/write (crw-rw----).


---
Restart Services

After driver install and user group updates:

sudo reboot

After reboot:

sudo systemctl restart tdarr-server
sudo systemctl restart tdarr-node


---

Test GPU Transcoding in Tdarr

Inside Tdarr:

Open Tdarr_Node

Go to Transcode Settings > FFmpeg Arguments

Use:

-hwaccel cuda -hwaccel_output_format cuda -c:v h264_cuvid -c:a copy
-c:v h264_nvenc

(depends on input/output)


