# Qubic Testnet Docker

This repository contains all the scripts and Dockerfiles necessary for launching a Qubic testnet node via Docker.

## Table of Contents
- [System Recommendations](#system-recommendations)
  - [Host Machine Requirements](#host-machine-requirements)
  - [Remote Connection Options](#remote-connection-options)
- [Quick Approach with run.sh](#quick-approach-with-runsh)
  - [Prerequisites](#prerequisites)
  - [Run ./run.sh](#run-runsh)
  - [Example](#example)
  - [Important: Version Compatibility](#important-version-compatibility)
- [Manual Approach](#manual-approach)
  - [Preparation Steps](#preparation-steps)
    - [1. VHD epoch increment preparation](#1-vhd-epoch-increment-preperation)
    - [2. Build the Base Docker Image](#2-build-the-base-docker-image-optional-if-use-prebuilt-base-docker-image)
    - [3. Install the VirtualBox Extension Pack Manually](#3-install-the-virtualbox-extension-pack-manually-optional)
    - [4. Change entrypoint.sh as Needed](#4-change-entrypointsh-as-needed)
    - [5. Build the Main Docker Image](#5-build-the-main-docker-image)
    - [6. Run the Main Docker with Port Forwarding](#6-run-the-main-docker-with-port-forwarding)
- [Final steps](#final-steps-for-both-approaches)
  - [See the Output with RDP](#see-the-output-with-rdp-optional)
  - [Run broadcastComputorTestnet & Other Scripts](#run-broadcastcomputortestnet--other-scripts)
  - [Run auto_tick.py for Consistent Ticks](#run-auto_tickpy-for-consistent-ticks)

# System Recommendations

## Host Machine Requirements
- **Linux**: A desktop environment is required (not just a server installation). This setup won't work on a headless Ubuntu server without a display manager, as you need a graphical environment to see the output or connect remotely to the virtual Qubic system running inside Docker.
  
  Example for Ubuntu Server: Install at least xubuntu-desktop with lightdm, which is a light display manager better suited for Xfce, LXQt or minimal setups:
  ```bash
  sudo apt update
  sudo apt install xubuntu-desktop lightdm
  ```

## Remote Connection Options
If you're connecting to the Qubic node from a remote machine, you'll need appropriate RDP client software:

- **Windows**: Use the built-in Remote Desktop Connection
- **macOS**: Install XQuartz and freerdp:
  ```bash
  brew install freerdp
  # XQuartz provides an XServer for macOS:
  brew install --cask xquartz
  ```
- **Linux**: Install freerdp as shown in the "See the Output with RDP" section below

# Quick Approach with run.sh

## Prerequisites

1. Docker (with --privileged support).
2. VirtualBox (7.1.x) installed on the host, ensuring kernel modules are loaded.
3. A pre-built Qubic.vhd. See the Qubic-Node.md docs for how to create it.
4. Optional: Ep<epoch>.zip, Qubic.efi, spectrum.000 if you need to update the VHD for your testnet.

## Run ./run.sh
Use run.sh to launch everything with a single command:

```commandline
./run.sh --epoch <EPOCH_NUMBER> --vhd <QUBIC_VHD> --port <PORT> --memory <MEMORY_MB> --cpus <CPUS> [--epzip <EP_ZIP>] [--efi <QUBIC_EFI>] [--spectrum <SPECTRUM_000>]
```
where:

1. `EPOCH_NUMBER` (e.g. 145)
2. `QUBIC_VHD` (e.g. /home/user/some/path/Qubic.vhd)
3. `PORT` (e.g. 31841)
4. `MEMORY_MB` (e.g. 120243) – memory in MB
5. `CPUS` (e.g. 29) – how many CPU cores
6. `EP_ZIP` (optional) – full path to [e|E]p<epoch>.zip
7. `QUBIC_EFI` (optional) – full path to Qubic.efi
8. `SPECTRUM_000` (optional) – full path to spectrum.000

## Example

```commandline
./run.sh --epoch 145 --vhd /home/user/some/path/Qubic.vhd --port 31841 --memory 120243 --cpus 29 \
  --epzip /home/user/epfiles/Ep145.zip \
  --efi /home/user/efi/Qubic.efi \
  --spectrum /home/user/000/spectrum.000
```

What Happens:
1. `prepare_vhd.sh` mounts and updates your .vhd with epoch files, EFI, spectrum if provided.
2. Builds the `qubic-docker` image.
3. Runs a container that:
  * Publishes `port 31841` so other nodes can connect.
  * Publishes `port 5000` for VRDE/RDP.
  * Mounts your local Qubic.vhd into `/qubic/Qubic.vhd` inside the container.
  * Sets memory/CPUs for the VirtualBox VM.

## Important: **Version Compatibility**
* The Dockerfile uses VirtualBox 7.1.
* Your host’s VirtualBox kernel modules must also be 7.1 (or a compatible 7.1.x) to avoid errors (e.g., rc=-1912 in hardened mode).
* If your host is not on 7.1, and you can't change the Vbox version in your host, see Manual Approach below to build a matching version inside the docker.

# Manual Approach 

If You Need a VBox version in your docker to match the host or you just need the manual steps and build the docker by yourself.

## Preparation Steps

### 1. VHD epoch increment preperation

If your `Qubic.vhd` does **not** already contain the correct epoch files, run the `prepare_vhd.sh` script:

```bash
./prepare_vhd.sh <EPOCH_NUMBER> <Qubic.vhd> [<EpXXX.zip>] [<Qubic.efi>] [<spectrum.000>]
```

- `EPOCH_NUMBER` **and** `Qubic.vhd` are **required**.
- `EpXXX.zip`, `Qubic.efi`, and `spectrum.000` are **optional**—if not provided, the script will skip them.

This script will do the `losetup` to mount the VHD, remove old epoch/system files, optionally copy `Ep*.zip`, `Qubic.efi`, and `spectrum.000` if you provide them, then unmount.

### 2. Build the **Base Docker** Image (Optional if use prebuilt base docker image)

**Important**: Skip this step if you use the prebuilt docker image [ghcr.io/icyblob/vbox-with-extpack:latest](https://github.com/users/icyblob/packages/container/package/vbox-with-extpack)

Inside the `base_docker/` directory, there is a `Dockerfile`. This base Dockerfile typically installs VirtualBox but **does not** install the Extension Pack. You can build it like so:

```bash
cd base_docker
docker build -t vbox-base .
```

### 3. Install the VirtualBox Extension Pack **Manually** (Optional)

**Important**: Skip this step if you use the prebuilt docker image [ghcr.io/icyblob/vbox-with-extpack:latest](https://github.com/users/icyblob/packages/container/package/vbox-with-extpack)

The purpose of installing VirtualBox Extension Pack is to view the Qubic Node's runtime output line by line, and to interact with the Qubic Node from the host machine. Skip this step if you don't want to interact with the VM instance or view its outputs.

Because the Extension Pack license must be accepted interactively, you need to:

1. Run a container from `vbox-base`:
   ```bash
   docker run --privileged -it vbox-base bash
   ```
2. Inside this container, download the matching Extension Pack (same version as VirtualBox):
   ```bash
   VBoxManage --version
   # Suppose it's 7.1.4
   wget https://download.virtualbox.org/virtualbox/7.1.4/Oracle_VM_VirtualBox_Extension_Pack-7.1.4.vbox-extpack

   VBoxManage extpack install --replace Oracle_VM_VirtualBox_Extension_Pack-7.1.4.vbox-extpack
   # Accept the license here
   ```
3. Confirm it’s installed:
   ```bash
   VBoxManage list extpacks
   # Should show the extension pack
   ```
4. In another terminal, commit this container to a new image:
   ```bash
   docker ps  # find the running container ID that you have installed the Extension Pack
   docker commit <container-id> vbox-with-extpack
   ```

Now you have an image named `vbox-with-extpack` with VirtualBox + Extension Pack installed.

### 4. Change `entrypoint.sh` as Needed

If you need different ports for testnet, or different memory/CPU allocation, modify `entrypoint.sh` accordingly.

### 5. Build the Main Docker Image

At the top of your main `Dockerfile` (in the root of this repo) you should include the manual image built from the previous step:

```dockerfile
FROM vbox-with-extpack:latest
```

Alternatively, you can use the prebuilt image here [ghcr.io/icyblob/vbox-with-extpack:latest](https://github.com/users/icyblob/packages/container/package/vbox-with-extpack)

```dockerfile
FROM ghcr.io/icyblob/vbox-with-extpack:latest
```

If you skipped step 3 and don't want to interact with the VM instance and view its outputs, then just use:

```dockerfile
FROM vbox-base
```

You can now build it:

```bash
docker build -t qubic-docker .
```

### 6. Run the Main Docker with Port Forwarding

To run your container:

```bash
docker run --privileged -it -p 31841:31841/tcp -p 5000:5000/tcp -v $(pwd):/qubic qubic-docker
```

- `-p 31841:31841` forwards the node’s port so external connections can reach it. Change this port forwarding if needed.
- `-p 5000:5000` allows VRDE (RDP) at port 5000 if you want to see the VM console. Only available if you installed the VirtualBox Extension Pack instructed above.
- `-v $(pwd):/qubic` mounts your host working directory (with `Qubic.vhd`, scripts, etc.) into the container.

# Final steps (for both approaches)

Both the approach to use ./run.sh or the manual docker build will need these additional steps.

## See the Output with RDP (Optional)

### For Linux hosts
Install `xfreerdp`:

```bash
sudo apt update && sudo apt install -y freerdp2-x11
```

### Connecting from any OS
Connect to the VM using RDP:

```bash
# Linux/macOS with freerdp
xfreerdp /v:127.0.0.1:5000 /u: /p: /cert:ignore

# Windows: use Remote Desktop Connection to connect to 127.0.0.1:5000
```

This should show you the headless VM console, assuming the Extension Pack is installed and VRDE is enabled in `entrypoint.sh`. Now you can even interact with the VM output as if you're running the VM from your host machine. Any keyboard inputs like Esc, F2, F4, F9, etc. will be sent to the VM in the docker.

## Run `broadcastComputorTestnet` & Other Scripts

From your **host** or another machine (depending on your network setup), you can connect to the Qubic node:

```bash
./broadcastComputorTestnet <node_ip> <epoch_number> <node port>
```

Change your node port accordingly, ie. 31841.

## Run `auto_tick.py` for Consistent Ticks

The `auto_tick.py` script ensures ticks happen consistently and seamlessly. Adjust its configuration (e.g., main/aux if you have single node or main/main if you have multiple nodes) and run it:

```bash
python3 auto_tick.py -node_ips <list of node ips separated by commas> -node_ports <node port> -ticks_per_epoch <ticks per epoch, depends on your settings when building the Qubic.efi>
```

If you’re running **one** node, remember to run the echo script on the other machine to keep it ticking. Contact the Qubic team for the echo script.
