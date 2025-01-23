#!/usr/bin/env bash
set -e

#############################################################################
# USAGE:
#
#   ./zip_epoch_files.sh --epoch <EPOCH_NUMBER> --vhd <path/to/Qubic.vhd> \
#       [--out <path/to/output.zip>]
#
# EXAMPLE:
#   ./zip_epoch_files.sh --epoch 140 --vhd /home/user/Qubic.vhd \
#       --out /home/user/Ep140.zip
#
# If you omit --out, it defaults to "./Ep<EPOCH_NUMBER>.zip"
#############################################################################

# Default variables
EPOCH_NUMBER=""
VHD_PATH=""
ZIP_OUT=""

# Parse flags
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
    --out)
      ZIP_OUT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 --epoch <EPOCH_NUMBER> --vhd <Qubic.vhd> [--out <EpXXX.zip>]"
      exit 1
      ;;
  esac
done

# Validate required flags
if [[ -z "$EPOCH_NUMBER" || -z "$VHD_PATH" ]]; then
  echo "ERROR: Missing required flags. Must provide --epoch and --vhd"
  echo "Usage: $0 --epoch <EPOCH_NUMBER> --vhd <Qubic.vhd> [--out <EpXXX.zip>]"
  exit 1
fi

# If no --out was provided, default to Ep<EPOCH_NUMBER>.zip in current directory
if [[ -z "$ZIP_OUT" ]]; then
  ZIP_OUT="Ep${EPOCH_NUMBER}.zip"
fi

# Print summary
echo "=========================================="
echo " ZIPPING QUBIC EPOCH FILES"
echo " EPOCH_NUMBER  = $EPOCH_NUMBER"
echo " VHD_PATH      = $VHD_PATH"
echo " OUTPUT ZIP    = $ZIP_OUT"
echo "=========================================="

# Check that VHD exists
if [[ ! -f "$VHD_PATH" ]]; then
  echo "ERROR: VHD file not found at $VHD_PATH"
  exit 1
fi

# Setup mount directory and cleanup trap
MOUNT_DIR="/mnt/qubic-zip"
sudo mkdir -p "$MOUNT_DIR"

LOOP_DEVICE=""
PARTITION=""

cleanup() {
  set +e  # Don't stop on errors in cleanup
  if mountpoint -q "$MOUNT_DIR"; then
    echo "Unmounting $MOUNT_DIR..."
    sudo umount "$MOUNT_DIR"
  fi
  if [[ -n "$LOOP_DEVICE" ]]; then
    echo "Detaching loop device $LOOP_DEVICE..."
    sudo losetup -d "$LOOP_DEVICE" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Create loop device with partition scanning
LOOP_DEVICE=$(sudo losetup -f --show --partscan "$VHD_PATH")
echo "Loop device is: $LOOP_DEVICE"

PARTITION="${LOOP_DEVICE}p1"

echo "Mounting $PARTITION to $MOUNT_DIR..."
sudo mount "$PARTITION" "$MOUNT_DIR"

# Gather all contract/universe/spectrum.*.EPOCH_NUMBER files
# We'll collect files named:
#   contract*.<EPOCH_NUMBER>
#   universe.<EPOCH_NUMBER>
#   spectrum.<EPOCH_NUMBER>
# in the mount directory
echo "Searching for contract/universe/spectrum for epoch $EPOCH_NUMBER in $MOUNT_DIR..."

FILES_TO_ZIP=()

# contract???.<EPOCH_NUMBER> (like contract0000.140, etc.)
while IFS= read -r -d '' f; do
  FILES_TO_ZIP+=("$f")
done < <(find "$MOUNT_DIR" -maxdepth 1 -type f -name "contract*.$EPOCH_NUMBER" -print0 2>/dev/null || true)

# universe.<EPOCH_NUMBER>
if [[ -f "$MOUNT_DIR/universe.$EPOCH_NUMBER" ]]; then
  FILES_TO_ZIP+=("$MOUNT_DIR/universe.$EPOCH_NUMBER")
fi

# spectrum.<EPOCH_NUMBER>
if [[ -f "$MOUNT_DIR/spectrum.$EPOCH_NUMBER" ]]; then
  FILES_TO_ZIP+=("$MOUNT_DIR/spectrum.$EPOCH_NUMBER")
fi

if [[ ${#FILES_TO_ZIP[@]} -eq 0 ]]; then
  echo "No epoch files found for EPOCH_NUMBER=$EPOCH_NUMBER in $MOUNT_DIR"
  echo "Exiting without creating zip."
  exit 0
fi

# Zip them up
echo "Creating zip archive: $ZIP_OUT"
# We'll cd to the mount directory so the zip doesn't store absolute paths
pushd "$MOUNT_DIR" >/dev/null

# Build an array of relative filenames
REL_FILES=()
for f in "${FILES_TO_ZIP[@]}"; do
  # each f is /mnt/qubic-zip/<filename>
  # we want just <filename>
  basename_f=$(basename "$f")
  REL_FILES+=("$basename_f")
done

# We'll do a zip command (requires "zip" installed).
sudo zip -r -9 "$ZIP_OUT" "${REL_FILES[@]}"

# Move the resulting zip from $MOUNT_DIR/<ZIP_OUT> to the original working dir (or anywhere).
popd >/dev/null

# The zip file ends up in $MOUNT_DIR/<ZIP_OUT>.
# We'll copy it back to the user directory:
sudo cp "$MOUNT_DIR/$ZIP_OUT" "$ZIP_OUT"
echo "Created zip at: $ZIP_OUT"

echo "Done."