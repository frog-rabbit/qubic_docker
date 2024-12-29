#!/usr/bin/env bash
set -e

#############################################################################
# USAGE
#
#   ./prepare_vhd.sh <EPOCH_NUMBER> <Qubic.vhd> \
#       [<EpXXX.zip>] [<Qubic.efi>] [<spectrum.000>]
#
# EXAMPLES
#
#   1) Minimum required:
#      ./prepare_vhd.sh 140 /home/myuser/qubic-files/Qubic.vhd
#
#   2) With optional files:
#      ./prepare_vhd.sh 140 /home/myuser/qubic-files/Qubic.vhd \
#         /home/myuser/qubic-files/Ep140.zip \
#         /home/myuser/qubic-files/Qubic.efi \
#         /home/myuser/qubic-files/spectrum.000
#############################################################################

# 1. Parse args
EPOCH_NUMBER="$1"
VHD_PATH="$2"
EPOCH_ZIP="$3"      # optional
EFI_FILE="$4"       # optional
SPECTRUM_FILE="$5"  # optional
NO_CLEAN="$6"       # optional

# 2. Check required args
if [[ -z "$EPOCH_NUMBER" || -z "$VHD_PATH" ]]; then
  echo "Usage: $0 <EPOCH_NUMBER> <Qubic.vhd> [Ep<epoch>.zip] [Qubic.efi] [spectrum.000]"
  exit 1
fi

# 3. Mount directory
MOUNT_DIR="/mnt/qubic"
sudo mkdir -p "$MOUNT_DIR"

echo "=========================================="
echo " Preparing Qubic VHD"
echo " EPOCH_NUMBER = $EPOCH_NUMBER"
echo " VHD_PATH     = $VHD_PATH"
echo " EPOCH_ZIP    = ${EPOCH_ZIP:-<not provided>}"
echo " EFI_FILE     = ${EFI_FILE:-<not provided>}"
echo " SPECTRUM_FILE= ${SPECTRUM_FILE:-<not provided>}"
echo " NO_CLEAN= ${NO_CLEAN:-<not provided>}"
echo " Mount point  = $MOUNT_DIR"
echo "=========================================="

# 4. Create loop device with partition scanning
if [[ ! -f "$VHD_PATH" ]]; then
  echo "ERROR: VHD file not found: $VHD_PATH"
  exit 1
fi

LOOP_DEVICE=$(sudo losetup -f --show --partscan "$VHD_PATH")
echo "Loop device is: $LOOP_DEVICE"

PARTITION="${LOOP_DEVICE}p1"

# 5. Mount the partition
echo "Mounting to $MOUNT_DIR..."
sudo mount "$PARTITION" "$MOUNT_DIR"

# 6. (Optional) Remove old score/system files unless NO_CLEAN is set
if [[ -n "$NO_CLEAN" ]]; then
  echo "NO_CLEAN is set. Skipping removal of score.* and system* files..."
else
  echo "Removing old score.* and system* files (ignore errors if missing)..."
  sudo rm -f "$MOUNT_DIR"/score.* "$MOUNT_DIR"/system* 2>/dev/null || true
fi

# 7. (Optional) Copy Qubic.efi
if [[ -n "$EFI_FILE" && -f "$EFI_FILE" ]]; then
  echo "Copying Qubic.efi from $EFI_FILE..."
  sudo cp "$EFI_FILE" "$MOUNT_DIR/efi/boot/"
else
  echo "No EFI_FILE provide or file not found; skip Qubic.efi copy..."
fi

# 8. (Optional) Copy and unzip Ep<epoch>.zip
if [[ -n "$EPOCH_ZIP" && -f "$EPOCH_ZIP" ]]; then
  ZIP_BASENAME="$(basename "$EPOCH_ZIP")"
  echo "Copying epoch ZIP: $EPOCH_ZIP..."
  sudo cp "$EPOCH_ZIP" "$MOUNT_DIR/"
  
  echo "Unzip $ZIP_BASENAME to $MOUNT_DIR..."
  sudo unzip -o "$MOUNT_DIR/$ZIP_BASENAME" -d "$MOUNT_DIR/"

  echo "Removing older epochs (1..$((EPOCH_NUMBER-1)))..."
  for n in $(seq 1 $((EPOCH_NUMBER-1))); do
    sudo rm -f "$MOUNT_DIR"/*.$((EPOCH_NUMBER - n)) 2>/dev/null || true
  done
else
  echo "No EPOCH_ZIP provided or file not found; skipping epoch unzip..."
fi

# 9. (Optional) Copy spectrum.000 as spectrum.<EPOCH_NUMBER>
if [[ -n "$SPECTRUM_FILE" && -f "$SPECTRUM_FILE" ]]; then
  echo "Copying $SPECTRUM_FILE to $MOUNT_DIR/spectrum.$EPOCH_NUMBER..."
  sudo cp "$SPECTRUM_FILE" "$MOUNT_DIR/spectrum.$EPOCH_NUMBER"
else
  echo "No SPECTRUM_FILE provided or file not found; skipping spectrum copy..."
fi

# 10. Unmount and detach
echo "Unmounting $MOUNT_DIR..."
sudo umount "$MOUNT_DIR"

echo "Detaching loop device $LOOP_DEVICE..."
sudo losetup -d "$LOOP_DEVICE"

echo "=========================================="
echo "VHD modification completed!"
