#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/profile.sh EXECUTABLE [PROGRAM_ARG ...]

Profile an executable with Nsight Systems through Open MPI.

Environment variables:
  MPI_RANKS       Number of MPI ranks to launch (default: 1)
  PROFILE_OUTPUT  Output path prefix (default: profiles/miniweather-BUILD_NAME)

Example:
  ./scripts/profile.sh ./cuda/build/1024x512/cuda
  MPI_RANKS=2 PROFILE_OUTPUT="$PWD/profiles/two-ranks" \
    ./scripts/profile.sh ./cuda/build/1024x512/cuda
EOF
}

if (( $# == 0 )); then
  usage >&2
  exit 2
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

executable=$1
shift

if [[ ! -f "$executable" ]]; then
  printf 'error: executable does not exist: %s\n' "$executable" >&2
  exit 1
fi
if [[ ! -x "$executable" ]]; then
  printf 'error: file is not executable: %s\n' "$executable" >&2
  exit 1
fi

command -v nsys >/dev/null 2>&1 || {
  printf 'error: nsys was not found on PATH\n' >&2
  exit 1
}
command -v mpirun >/dev/null 2>&1 || {
  printf 'error: mpirun was not found on PATH\n' >&2
  exit 1
}
command -v realpath >/dev/null 2>&1 || {
  printf 'error: realpath was not found on PATH\n' >&2
  exit 1
}

MPI_RANKS=${MPI_RANKS:-1}
if [[ ! "$MPI_RANKS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'error: MPI_RANKS must be a positive integer\n' >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
executable=$(realpath -- "$executable")
build_name=$(basename -- "$(dirname -- "$executable")")
PROFILE_OUTPUT=${PROFILE_OUTPUT:-"${PROJECT_ROOT}/profiles/miniweather-${build_name}"}
mkdir -p -- "$(dirname -- "$PROFILE_OUTPUT")"

mpi_command=(mpirun)
if (( EUID == 0 )); then
  mpi_command+=(--allow-run-as-root)
fi
mpi_command+=(-n "$MPI_RANKS" "$executable" "$@")

printf 'Profiling: %s\n' "$executable"
printf 'MPI ranks: %s\n' "$MPI_RANKS"
printf 'Output prefix: %s\n' "$PROFILE_OUTPUT"

nsys profile \
  --trace=cuda,nvtx,osrt,mpi \
  --mpi-impl=openmpi \
  --cpuctxsw=none \
  --stats=true \
  --force-overwrite=true \
  --output="$PROFILE_OUTPUT" \
  "${mpi_command[@]}"
