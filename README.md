# Qubic Testnet Docker

This repository contains files necessary for launching a Qubic testnet node **inside a Docker**.

## File Structure

```
.
├── auto_tick.py
├── base_docker
│   └── Dockerfile
├── broadcastComputorTestnet
├── Dockerfile
├── entrypoint.sh
├── Ep<epoch number>.zip # Or any Ep*.zip for your epoch. Must match pattern [e|E]p<epoch>.zip
├── libfourq-qubic.so
├── prepare_vhd.sh
├── qubic-cli
├── Qubic.efi
├── Qubic.vhd
├── README.md
└── spectrum.000
```

**Important**: In addition to the files in this repo, you must also have:

1. A **pre-built** `Qubic.vhd` disk image. See [Qubic-Node.md](https://github.com/XARKUR/Qubic/blob/main/Qubic-Node.md) for detailed tutorials. This vhd file must contain the efi directory and all the contract, universe and spectrum files.
2. The **compiled** `qubic-cli` and its library `libfourq-qubic.so`.
3. The `broadcastComputorTestnet` binary. (Not packaged here—contact the Qubic team if you need it.)
4. An **epoch file** in the pattern `[e|E]p<epoch number>.zip`. For example, `Ep140.zip`.
5. A **pre-compiled** `Qubic.efi` suitable for your hardware or custom setup.
6. A **testnet-only** `spectrum.000` file (contact the Qubic team for testnet spectrums and seeds).

Prepare all the necessary files listed here and copy them into this repo.

---

## Preparation Steps

### 1. VHD epoch increment preperation

If your `Qubic.vhd` does **not** already contain the correct epoch files, run the `prepare_vhd.sh` script:

```bash
./prepare_vhd.sh <EPOCH_NUMBER> <Qubic.vhd> [<EpXXX.zip>] [<Qubic.efi>] [<spectrum.000>]
```

- `EPOCH_NUMBER` **and** `Qubic.vhd` are **required**.
- `EpXXX.zip`, `Qubic.efi`, and `spectrum.000` are **optional**—if not provided, the script will skip them.

This script will do thr `losetup` to mount the VHD, remove old epoch/system files, optionally copy `Ep*.zip`, `Qubic.efi`, and `spectrum.000` if you provide them, then unmount.

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

### 7. See the Output with RDP (Optional)

Install `xfreerdp` on your host:

```bash
sudo apt update && sudo apt install -y freerdp2-x11
```

Then connect:

```bash
xfreerdp /v:127.0.0.1:5000 /u: /p: /cert:ignore
```

This should show you the headless VM console, assuming the Extension Pack is installed and VRDE is enabled in `entrypoint.sh`. Now you can even interact with the VM output as if you're running the VM from your host machine. Any keyboard inputs like Esc, F2, F4, F9, etc. will be sent to the VM in the docker.

### 8. Run `broadcastComputorTestnet` & Other Scripts

From your **host** or another machine (depending on your network setup), you can connect to the Qubic node:

```bash
broadcastComputorTestnet <node_ip> <epoch_number> <node port>
```

Change your node port accordingly, ie. 31841.

### 9. Run `auto_tick.py` for Consistent Ticks

The `auto_tick.py` script ensures ticks happen consistently and seamlessly. Adjust its configuration (e.g., main/aux if you have single node or main/main if you have multiple nodes) and run it:

```bash
python3 auto_tick.py -node_ips <list of node ips separated by commas> -node_ports <node port> -ticks_per_epoch <ticks per epoch, depends on your settings when building the Qubic.efi>
```

If you’re running **one** node, remember to run the echo script on the other machine to keep it ticking. Contact the Qubic team for the echo script.
