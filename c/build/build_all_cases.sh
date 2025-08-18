#!/bin/bash

# Build script for all DATA_SPEC cases
# This script builds the miniWeather application with all supported data specification cases

echo "Building miniWeather for all DATA_SPEC cases..."

CASES=("collision" "thermal" "gravity" "density_current" "injection")
BUILD_DIR="$(pwd)"
RESULTS_DIR="${BUILD_DIR}/case_results"

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Clean any previous builds
echo "Cleaning previous builds..."
./cmake_clean.sh 2>/dev/null || true

for case in "${CASES[@]}"; do
    echo "========================================="
    echo "Building case: ${case}"
    echo "========================================="
    
    # Clean before each build
    ./cmake_clean.sh 2>/dev/null || true
    
    # Build the case
    if [ -f "./my_cmake_scripts/cmake_andes_gnu_cpu_${case}.sh" ]; then
        cd "${BUILD_DIR}"
        if bash -c "source ./my_cmake_scripts/cmake_andes_gnu_cpu_${case}.sh"; then
            echo "CMake configuration successful for ${case}"
            if make -j$(nproc); then
                echo "Build successful for ${case}"
                
                # Create case-specific directory and copy executables
                CASE_DIR="${RESULTS_DIR}/${case}"
                mkdir -p "${CASE_DIR}"
                
                # Copy all executables to case-specific directory
                for exe in serial mpi openmp openacc cuda; do
                    if [ -f "${exe}" ]; then
                        cp "${exe}" "${CASE_DIR}/${exe}_${case}"
                        echo "Copied ${exe} -> ${CASE_DIR}/${exe}_${case}"
                    fi
                    if [ -f "${exe}_test" ]; then
                        cp "${exe}_test" "${CASE_DIR}/${exe}_test_${case}"
                        echo "Copied ${exe}_test -> ${CASE_DIR}/${exe}_test_${case}"
                    fi
                done
                
                echo "SUCCESS: ${case} case built and executables saved to ${CASE_DIR}"
            else
                echo "ERROR: Make failed for ${case}"
            fi
        else
            echo "ERROR: CMake configuration failed for ${case}"
        fi
    else
        echo "ERROR: CMake script not found for ${case}"
    fi
    
    echo ""
done

echo "========================================="
echo "Build Summary"
echo "========================================="
echo "All case executables saved to: ${RESULTS_DIR}"
echo ""
echo "Available executables by case:"
for case in "${CASES[@]}"; do
    CASE_DIR="${RESULTS_DIR}/${case}"
    if [ -d "${CASE_DIR}" ]; then
        echo "  ${case}:"
        ls -1 "${CASE_DIR}" | sed 's/^/    /'
    else
        echo "  ${case}: Build failed"
    fi
done

echo ""
echo "Build completed!"