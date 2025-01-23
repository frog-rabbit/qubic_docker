#!/usr/bin/env bash
set -e

#############################################################################
# USAGE
#
#   ./prepare_vhd.sh --epoch <EPOCH_NUMBER> --vhd <Qubic.vhd> \
#       [--epzip <EpXXX.zip>] [--efi <Qubic.efi>] [--spectrum <spectrum.000>] [--no-clean]
#
# EXAMPLES
#
#   1) Minimum required:
#      ./prepare_vhd.sh --epoch 140 --vhd /path/to/Qubic.vhd
#
#   2) With optional files:
#      ./prepare_vhd.sh --epoch 140 --vhd /home/myuser/Qubic.vhd \
#         --epzip /home/myuser/Ep140.zip \
#         --efi /home/myuser/Qubic.efi \
#         --spectrum /home/myuser/spectrum.000
#
#   3) If you do NOT want to remove old score/system files, add --no-clean falg:
#      ./prepare_vhd.sh --epoch 140 --vhd /some/path/Qubic.vhd \
#         --epzip /some/path/Ep140.zip \
#         --efi /some/path/Qubic.efi \
#         --spectrum /some/path/spectrum.000 \
#         --no-clean
#############################################################################

# Default (empty) variables
EPOCH_NUMBER=""
VHD_PATH=""
EPOCH_ZIP=""
EFI_FILE=""
SPECTRUM_FILE=""
NO_CLEAN=""  # If set, skip removing score/system files

# Parsing the flags
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --epoch)
      EPOCH_NUMBER="$2"
      shift 2
      ;;
    --vhd)
      VHD_PATH="$2"
      shift 2
      ;;
    --epzip)
      EPOCH_ZIP="$2"
      shift 2
      ;;
    --efi)
      EFI_FILE="$2"
      shift 2
      ;;
    --spectrum)
      SPECTRUM_FILE="$2"
      shift 2
      ;;
    --no-clean)
      NO_CLEAN="1"
      shift 1
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check required
if [[ -z "$EPOCH_NUMBER" || -z "$VHD_PATH" ]]; then
  echo "ERROR: Missing required flags --epoch or --vhd"
  echo "Usage: $0 --epoch <EPOCH_NUMBER> --vhd <Qubic.vhd> [--epzip <EpXXX.zip>] [--efi <Qubic.efi>] [--spectrum <spectrum.000>] [--no-clean]"
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
echo " NO_CLEAN     = ${NO_CLEAN:-<not provided>}"
echo "=========================================="

# 4. Ensure VHD exists
if [[ ! -f "$VHD_PATH" ]]; then
  echo "ERROR: VHD file not found: $VHD_PATH"
  exit 1
fi

LOOP_DEVICE=""
PARTITION=""

cleanup() {
  set +e  # don't stop on errors in cleanup
  if mountpoint -q "$MOUNT_DIR"; then
    echo "Unmounting $MOUNT_DIR..."
    sudo umount "$MOUNT_DIR"
  fi
  if [[ -n "$LOOP_DEVICE" ]]; then
    echo "Detaching loop device $LOOP_DEVICE..."
    sudo losetup -d "$LOOP_DEVICE" 2>/dev/null || true
  fi
}

# Trap EXIT so cleanup always runs, even on error or script exit
trap cleanup EXIT

LOOP_DEVICE=$(sudo losetup -f --show --partscan "$VHD_PATH")
echo "Loop device is: $LOOP_DEVICE"

PARTITION="${LOOP_DEVICE}p1"

echo "Mounting $PARTITION to $MOUNT_DIR..."
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
  sudo cp "$EFI_FILE" "$MOUNT_DIR/efi/boot/Qubic.efi"
else
  echo "No valid --efi file provided; skipping Qubic.efi copy..."
fi

if [[ -n "$EPOCH_ZIP" && -f "$EPOCH_ZIP" ]]; then
  echo "Removing old contract/universe/spectrum from $MOUNT_DIR..."
  sudo rm -f "$MOUNT_DIR"/contract* "$MOUNT_DIR"/universe* "$MOUNT_DIR"/spectrum* 2>/dev/null || true

  ZIP_BASENAME="$(basename "$EPOCH_ZIP")"
  echo "Copying epoch ZIP: $EPOCH_ZIP to $MOUNT_DIR..."
  sudo cp "$EPOCH_ZIP" "$MOUNT_DIR/"

  echo "Unzipping $ZIP_BASENAME..."
  sudo unzip -o "$MOUNT_DIR/$ZIP_BASENAME" -d "$MOUNT_DIR/"

  echo "Removing older epochs (1..$((EPOCH_NUMBER-1)))..."
  for n in $(seq 1 $((EPOCH_NUMBER-1))); do
    sudo rm -f "$MOUNT_DIR"/*.$((EPOCH_NUMBER - n)) 2>/dev/null || true
  done
else
  echo "No valid --epzip file provided; skipping contract/universe replacement and epoch unzip..."
fi

# 9. (Optional) Copy spectrum.000 as spectrum.<EPOCH_NUMBER>
if [[ -n "$SPECTRUM_FILE" && -f "$SPECTRUM_FILE" ]]; then
  echo "Copying $SPECTRUM_FILE to $MOUNT_DIR/spectrum.$EPOCH_NUMBER..."
  sudo cp "$SPECTRUM_FILE" "$MOUNT_DIR/spectrum.$EPOCH_NUMBER"
else
  echo "No valid --spectrum file provided; skipping spectrum copy..."
fi

echo "VHD modification completed successfully. Will unmount/detach on exit."