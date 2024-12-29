#!/usr/bin/env bash
set -e

VM_NAME="Qubic"
VHD_FILE="${VHD_FILE:-/qubic/Qubic.vhd}"
PORT="${PORT:-31841}"
MEMORY="${MEMORY:-61440}"  # in MB (60 GB default)
CPUS="${CPUS:-8}"

echo " Qubic Docker Entrypoint"
echo " VM_NAME     = $VM_NAME"
echo " VHD_FILE    = $VHD_FILE"
echo " PORT        = $PORT"
echo " MEMORY (MB) = $MEMORY"
echo " CPUS        = $CPUS"

# 1. Remove old VM if it exists
VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true

# 2. Create new VM
VBoxManage createvm --name "$VM_NAME" --ostype "Other_64" --register

# 3. Basic settings
VBoxManage modifyvm "$VM_NAME" \
  --memory "$MEMORY" \
  --cpus "$CPUS" \
  --firmware efi \
  --nic1 nat \
  --nictype1 virtio

# 4. Forward Qubic's main port (31841) or any ports for your testnet node. Change this if needed
VBoxManage modifyvm "$VM_NAME" \
  --natpf1 "qubic-port,tcp,,${PORT},,${PORT}"
  
# 5. Enable VRDE (RDP) on port 5000, no auth
VBoxManage modifyvm "$VM_NAME" \
  --vrde on \
  --vrdeaddress 0.0.0.0 \
  --vrdeport 5000 \
  --vrdeauthtype null

# 6. Add storage and attach Qubic.vhd to an IDE controller
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
VBoxManage storageattach "$VM_NAME" \
  --storagectl "IDE Controller" \
  --port 0 \
  --device 0 \
  --type hdd \
  --medium "$VHD_FILE"

# 7. Print VM info
echo "Dumping VM info before start:"
VBoxManage showvminfo "$VM_NAME" --details

# 8. Start VM in headless mode
echo "Starting VM '$VM_NAME' in headless mode with VRDE on port 5000 ..."
VBoxHeadless --startvm "$VM_NAME" --vrde on

# Keep container alive
tail -f /dev/null
