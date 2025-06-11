# tdarr-installer
What tdarr is can be read here:
https://home.tdarr.io/
The .sh file installs tdarr on Ubuntu server.
sourced from:
https://github.com/tteck/Proxmox/blob/main/install/tdarr-install.sh


!!The modified script is not tested!!
Run with:
sudo ./tdarr-ubuntu.sh

This steps might be needed to get nvidia hardware to work.

To add NVIDIA GPU hardware acceleration support on Ubuntu 25.04 for your Tdarr setup, you'll need to:

1. Install NVIDIA drivers


2. Install NVIDIA Container Toolkit (optional if Docker is used later)


3. Install CUDA/nv-codec headers for transcoding


4. Ensure the tdarr user has access to the GPU


---

✅ Step-by-Step: Add NVIDIA GPU Support

🔧 1. Install NVIDIA Drivers

Ubuntu 25.04 should have recent drivers in its repo:

sudo apt update
sudo apt install -y nvidia-driver-535

> 🧪 Run nvidia-smi after reboot to confirm GPU is working:

nvidia-smi


---

📦 2. Install NVIDIA Video Codec SDK Components

Tdarr uses FFmpeg which relies on NVENC/NVDEC support:

sudo apt install -y nvidia-utils-535 libnvidia-encode-535

(Replace 535 with your installed driver version if needed.)

> Optional: For maximum compatibility, also install:

sudo apt install -y libnvidia-compute-535 libnvidia-decode-535 libnvidia-ifr1-535


---

🔁 3. Reconfigure Tdarr to Use NVIDIA GPU

Make sure FFmpeg inside Tdarr nodes uses the GPU via h264_nvenc, hevc_nvenc, etc.

No need to install ffmpeg system-wide unless you're customizing transcode scripts.


---

👤 4. Grant tdarr User Access to NVIDIA Devices

Run this:

sudo usermod -aG video tdarr

Check device permissions:

ls -la /dev/nvidia*

They should be owned by root:video with group read/write (crw-rw----).


---

🔌 5. Restart Services

After driver install and user group updates:

sudo reboot

After reboot:

sudo systemctl restart tdarr-server
sudo systemctl restart tdarr-node


---

🧪 Test GPU Transcoding in Tdarr

Inside Tdarr:

Open Tdarr_Node

Go to Transcode Settings > FFmpeg Arguments

Use:

-hwaccel cuda -hwaccel_output_format cuda -c:v h264_cuvid -c:a copy
-c:v h264_nvenc

(depends on input/output)


