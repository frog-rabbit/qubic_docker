#!/usr/bin/env bash
set -e

#############################################################################
# USAGE:
#
#   ./run.sh --epoch <EPOCH_NUMBER> --vhd <QUBIC_VHD> \
#       --port <PORT> --memory <MEMORY_MB> --cpus <CPUS> \
#       [--epzip <EpXXX.zip>] [--efi <Qubic.efi>] [--spectrum <spectrum.000>]
#
# EXAMPLE:
#   ./run.sh --epoch 140 --vhd /home/user/Qubic.vhd \
#       --port 31841 --memory 60 --cpus 8 \
#       --epzip /home/user/Ep140.zip \
#       --efi /home/user/Qubic.efi \
#       --spectrum /home/user/spectrum.000
#############################################################################

EPOCH_NUMBER=""
QUBIC_VHD=""
PORT=""
MEMORY_MB=""
CPUS=""
EP_ZIP=""
QUBIC_EFI=""
SPECTRUM_000=""

# Parsing flags
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --epoch)
      EPOCH_NUMBER="$2"
      shift 2
      ;;
    --vhd)
      QUBIC_VHD="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --memory)
      MEMORY_MB="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --epzip)
      EP_ZIP="$2"
      shift 2
      ;;
    --efi)
      QUBIC_EFI="$2"
      shift 2
      ;;
    --spectrum)
      SPECTRUM_000="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 --epoch <EPOCH_NUMBER> --vhd <QUBIC_VHD> --port <PORT> --memory <MEMORY_MB> --cpus <CPUS> [--epzip <EpXXX.zip>] [--efi <Qubic.efi>] [--spectrum <spectrum.000>]"
      exit 1
      ;;
  esac
done

# Validate required flags
if [[ -z "$EPOCH_NUMBER" || -z "$QUBIC_VHD" || -z "$PORT" || -z "$MEMORY_MB" || -z "$CPUS" ]]; then
  echo "ERROR: Missing required flags. Must provide: --epoch, --vhd, --port, --memory, --cpus"
  echo "Usage: $0 --epoch <EPOCH_NUMBER> --vhd <QUBIC_VHD> --port <PORT> --memory <MEMORY_MB> --cpus <CPUS> [--epzip <EpXXX.zip>] [--efi <Qubic.efi>] [--spectrum <spectrum.000>]"
  exit 1
fi

# summary
echo "=================== LAUNCH QUBIC ==================="
echo " EPOCH_NUMBER       = $EPOCH_NUMBER"
echo " QUBIC_VHD          = $QUBIC_VHD"
echo " PORT               = $PORT"
echo " MEMORY_MB          = $MEMORY_MB"
echo " CPUS               = $CPUS"
echo " EP_ZIP             = ${EP_ZIP:-<none>}"
echo " QUBIC_EFI          = ${QUBIC_EFI:-<none>}"
echo " SPECTRUM_000       = ${SPECTRUM_000:-<none>}"
echo "===================================================="

if [[ ! -x "./prepare_vhd.sh" ]]; then
  echo "ERROR: prepare_vhd.sh not found or not executable in current directory."
  exit 1
fi

echo "Running prepare_vhd.sh..."
./prepare_vhd.sh \
  --epoch "$EPOCH_NUMBER" \
  --vhd "$QUBIC_VHD" \
  ${EP_ZIP:+ --epzip "$EP_ZIP"} \
  ${QUBIC_EFI:+ --efi "$QUBIC_EFI"} \
  ${SPECTRUM_000:+ --spectrum "$SPECTRUM_000"}

echo "Building Docker image 'qubic-docker'..."
docker build -t qubic-docker .

echo "Running container on PORT $PORT, with $MEMORY_MB GB memory, $CPUS CPUs..."

docker run --privileged -it \
  -p "5000:5000/tcp" \
  -p "${PORT}:${PORT}/tcp" \
  -e VHD_FILE="/qubic/Qubic.vhd" \
  -e PORT="${PORT}" \
  -e MEMORY="${MEMORY_MB}" \
  -e CPUS="${CPUS}" \
  -v "${QUBIC_VHD}:/qubic/Qubic.vhd" \
  qubic-docker