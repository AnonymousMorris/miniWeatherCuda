#!/bin/bash

module load gcc/10.3.0 parallel-netcdf cmake

export TEST_MPI_COMMAND="mpirun -n 1"

./cmake_clean.sh

cmake -DCMAKE_CXX_COMPILER=mpic++                                                     \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5                                              \
      -DCXXFLAGS="-Ofast -march=native -DNO_INFORM -std=c++11 -I${OLCF_PARALLEL_NETCDF_ROOT}/include"   \
      -DLDFLAGS="-L${OLCF_PARALLEL_NETCDF_ROOT}/lib -lpnetcdf"                        \
      -DOPENMP_FLAGS="-fopenmp"                                                       \
      -DOPENACC_FLAGS="-fopenacc"                                                     \
      -DNX=200                                                                        \
      -DNZ=100                                                                        \
      -DDATA_SPEC="DATA_SPEC_GRAVITY_WAVES"                                           \
      -DSIM_TIME=1000                                                                 \
      ..
