#!/usr/bin/env bash
set -e

TOTAL_ARGS=$#
if [[ $TOTAL_ARGS -lt 5 ]]; then
  echo "ERROR: At least 5 arguments are required."
  echo "Usage: $0 <EPOCH_NUMBER> <QUBIC_VHD> <PORT> <MEMORY_GB> <CPUS> [EP_ZIP] [QUBIC_EFI] [SPECTRUM_000]"
  exit 1
fi
if [[ $TOTAL_ARGS -gt 8 ]]; then
  echo "ERROR: At most 8 arguments allowed."
  echo "Usage: $0 <EPOCH_NUMBER> <QUBIC_VHD> <PORT> <MEMORY_GB> <CPUS> [EP_ZIP] [QUBIC_EFI] [SPECTRUM_000]"
  exit 1
fi

# Required arguments
EPOCH_NUMBER="$1"      # e.g. 140
QUBIC_VHD="$2"         # e.g. /home/user/Qubic.vhd
PORT="$3"              # e.g. 31841
MEMORY_GB="$4"         # e.g. 60
CPUS="$5"              # e.g. 8

# Optional arguments (default to empty)
EP_ZIP="${6:-}"        # e.g. /home/user/Ep140.zip
QUBIC_EFI="${7:-}"     # e.g. /home/user/Qubic.efi
SPECTRUM_000="${8:-}"  # e.g. /home/user/spectrum.000

echo " LAUNCH QUBIC"
echo " EPOCH_NUMBER       = $EPOCH_NUMBER"
echo " QUBIC_VHD          = $QUBIC_VHD"
echo " PORT               = $PORT"
echo " MEMORY_GB          = $MEMORY_GB"
echo " CPUS               = $CPUS"
echo " EP_ZIP             = ${EP_ZIP:-<none>}"
echo " QUBIC_EFI          = ${QUBIC_EFI:-<none>}"
echo " SPECTRUM_000       = ${SPECTRUM_000:-<none>}"

if [[ ! -x "./prepare_vhd.sh" ]]; then
  echo "ERROR: prepare_vhd.sh not found or not executable in current directory."
  exit 1
fi

echo "Running prepare_vhd.sh..."
./prepare_vhd.sh "$EPOCH_NUMBER" "$QUBIC_VHD" "$EP_ZIP" "$QUBIC_EFI" "$SPECTRUM_000"

echo "Building Docker image 'qubic-docker'..."
docker build -t qubic-docker .

echo "Running container on PORT $PORT, with $MEMORY_GB GB memory, $CPUS CPUs..."

docker run --privileged -it \
  -p "5000:5000/tcp" \
  -p "${PORT}:${PORT}/tcp" \
  -e VHD_FILE="/qubic/Qubic.vhd" \
  -e PORT="${PORT}" \
  -e MEMORY="${MEMORY_GB}" \
  -e CPUS="${CPUS}" \
  -v "${QUBIC_VHD}:/qubic/Qubic.vhd" \
  qubic-docker
