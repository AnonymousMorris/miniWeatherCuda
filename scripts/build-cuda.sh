#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/build-cuda.sh BUILD_NAME NX NZ SIM_TIME OUT_FREQ [CMAKE_OPTION ...]

Configure and build a CUDA miniWeather executable for the GPU attached to the
container. Additional CMake options can override defaults or select a data case.

Example:
  ./scripts/build-cuda.sh thermal 1024 512 78.125 1 \
    -DDATA_SPEC=DATA_SPEC_THERMAL
EOF
}

if (( $# < 5 )); then
  usage >&2
  exit 2
fi

BUILD_NAME=$1
NX=$2
NZ=$3
SIM_TIME=$4
OUT_FREQ=$5
shift 5

if [[ ! "$BUILD_NAME" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]]; then
  printf 'error: BUILD_NAME must contain only letters, numbers, dots, dashes, and underscores\n' >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
SOURCE_DIR="${PROJECT_ROOT}/cuda"
BUILD_DIR="${SOURCE_DIR}/build/${BUILD_NAME}"

MPICXX=${MPICXX:-$(command -v mpicxx || true)}
NVCC=${NVCC:-$(command -v nvcc || true)}
CUDA_HOST_COMPILER=${CUDA_HOST_COMPILER:-$(command -v g++ || true)}
CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES:-native}
JOBS=${JOBS:-$(nproc)}

[[ -n "$MPICXX" ]] || { printf 'error: mpicxx was not found\n' >&2; exit 1; }
[[ -n "$NVCC" ]] || { printf 'error: nvcc was not found\n' >&2; exit 1; }
[[ -n "$CUDA_HOST_COMPILER" ]] || { printf 'error: g++ was not found\n' >&2; exit 1; }
command -v cmake >/dev/null 2>&1 || { printf 'error: cmake was not found\n' >&2; exit 1; }

MPI_COMPILE_FLAGS=$("$MPICXX" --showme:compile)
MPI_LINK_FLAGS=$("$MPICXX" --showme:link)

if [[ -n "${PNETCDF_ROOT:-}" && -f "${PNETCDF_ROOT}/include/pnetcdf.h" ]]; then
  PNETCDF_COMPILE_FLAGS="-I${PNETCDF_ROOT}/include"
  PNETCDF_LINK_FLAGS="-L${PNETCDF_ROOT}/lib -Wl,-rpath,${PNETCDF_ROOT}/lib -lpnetcdf"
else
  PNETCDF_COMPILE_FLAGS="-I/usr/include"
  PNETCDF_LINK_FLAGS="-lpnetcdf"
fi

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_CXX_COMPILER="$MPICXX" \
  -DCMAKE_CUDA_COMPILER="$NVCC" \
  -DCMAKE_CUDA_HOST_COMPILER="$CUDA_HOST_COMPILER" \
  -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" \
  "-DCMAKE_CUDA_FLAGS=-DNO_INFORM ${MPI_COMPILE_FLAGS} ${PNETCDF_COMPILE_FLAGS}" \
  "-DCXXFLAGS=-O3 -DNO_INFORM ${PNETCDF_COMPILE_FLAGS}" \
  "-DLDFLAGS=${PNETCDF_LINK_FLAGS}" \
  "-DMPI_LINK_FLAGS=${MPI_LINK_FLAGS}" \
  "-DCUDA_LINK_FLAGS=-lcudart ${MPI_LINK_FLAGS}" \
  -DNX="$NX" \
  -DNZ="$NZ" \
  -DSIM_TIME="$SIM_TIME" \
  -DOUT_FREQ="$OUT_FREQ" \
  "$@"

cmake --build "$BUILD_DIR" --parallel "$JOBS" --target cuda

printf '\nBuilt %s\n' "${BUILD_DIR}/cuda"
