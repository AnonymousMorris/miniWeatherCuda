#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/build-cuda.sh BUILD_NAME NX NZ SIM_TIME OUT_FREQ [--debug] [CMAKE_OPTION ...]

Configure and build a CUDA miniWeather executable for the GPU attached to the
container. Additional CMake options can override defaults or select a data case.

Options:
  --debug  Add optimized device line information for Nsight Compute and keep
           NVCC intermediates, including source-annotated PTX, under the build
           directory. This does not use -G or disable compiler optimizations.

Examples:
  ./scripts/build-cuda.sh thermal 1024 512 78.125 1 \
    -DDATA_SPEC=DATA_SPEC_THERMAL
  ./scripts/build-cuda.sh thermal-ncu 1024 512 78.125 1 --debug
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

DEBUG_BUILD=0
CMAKE_OPTIONS=()
while (( $# > 0 )); do
  case "$1" in
    --debug)
      DEBUG_BUILD=1
      ;;
    --)
      shift
      CMAKE_OPTIONS+=("$@")
      break
      ;;
    *)
      CMAKE_OPTIONS+=("$1")
      ;;
  esac
  shift
done

if [[ ! "$BUILD_NAME" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]]; then
  printf 'error: BUILD_NAME must contain only letters, numbers, dots, dashes, and underscores\n' >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
SOURCE_DIR="${PROJECT_ROOT}/cuda"
BUILD_DIR="${SOURCE_DIR}/build/${BUILD_NAME}"
NVCC_KEEP_DIR="${BUILD_DIR}/nvcc-intermediates"

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

CUDA_COMPILE_FLAGS="-DNO_INFORM ${MPI_COMPILE_FLAGS} ${PNETCDF_COMPILE_FLAGS}"
if (( DEBUG_BUILD )); then
  mkdir -p -- "$NVCC_KEEP_DIR"
  CUDA_COMPILE_FLAGS+=" --generate-line-info --source-in-ptx --keep --keep-dir=${NVCC_KEEP_DIR}"
  printf 'Nsight Compute source correlation enabled\n'
  printf 'NVCC intermediates: %s\n' "$NVCC_KEEP_DIR"
else
  rm -rf -- "$NVCC_KEEP_DIR"
fi

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_CXX_COMPILER="$MPICXX" \
  -DCMAKE_CUDA_COMPILER="$NVCC" \
  -DCMAKE_CUDA_HOST_COMPILER="$CUDA_HOST_COMPILER" \
  -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" \
  "-DCMAKE_CUDA_FLAGS=${CUDA_COMPILE_FLAGS}" \
  "-DCXXFLAGS=-O3 -DNO_INFORM ${PNETCDF_COMPILE_FLAGS}" \
  "-DLDFLAGS=${PNETCDF_LINK_FLAGS}" \
  "-DMPI_LINK_FLAGS=${MPI_LINK_FLAGS}" \
  "-DCUDA_LINK_FLAGS=-lcudart ${MPI_LINK_FLAGS}" \
  -DNX="$NX" \
  -DNZ="$NZ" \
  -DSIM_TIME="$SIM_TIME" \
  -DOUT_FREQ="$OUT_FREQ" \
  "${CMAKE_OPTIONS[@]}"

cmake --build "$BUILD_DIR" --parallel "$JOBS" --target cuda

printf '\nBuilt %s\n' "${BUILD_DIR}/cuda"
