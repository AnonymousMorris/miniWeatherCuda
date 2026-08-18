# miniWeather CUDA

This directory contains the standalone CUDA copy of miniWeather. Its source and CMake structure intentionally stay close to the CUDA target under `c/`.

## Local build

The local preset supplies this workstation's MPI, PNetCDF, CUDA, and GCC 15 settings:

```bash
cd cuda
cmake --preset local
cmake --build --preset local --parallel
```

Run the conservation and golden-reference tests:

```bash
ctest --preset local
```

The reference tests run 20-second collision, thermal, gravity-wave, density-current, and injection simulations and compare their final output fields with saved OpenMP results. See [`cuda_test/README.md`](cuda_test/README.md) for details.

Run with one MPI rank:

```bash
cd build/local
mpirun -n 1 ./cuda
```

The simulation writes `output.nc` in the directory from which it is launched.

## Simulation parameters

Override the compile-time settings during configuration:

```bash
cmake --preset local \
  -DNX=400 \
  -DNZ=200 \
  -DSIM_TIME=1000 \
  -DOUT_FREQ=100 \
  -DDATA_SPEC=DATA_SPEC_GRAVITY_WAVES
cmake --build --preset local --parallel
```

Supported data specifications are:

- `DATA_SPEC_COLLISION`
- `DATA_SPEC_THERMAL`
- `DATA_SPEC_GRAVITY_WAVES`
- `DATA_SPEC_DENSITY_CURRENT`
- `DATA_SPEC_INJECTION`

The CUDA implementation supports multiple MPI ranks when built and run with a CUDA-aware MPI implementation.

## Other systems

As with the scripts under `c/build/`, provide machine-specific values for:

- `CMAKE_CUDA_HOST_COMPILER`
- `CXXFLAGS`
- `LDFLAGS`
- `MPI_LINK_FLAGS`
- `CUDA_FLAGS`
- `CUDA_LINK_FLAGS`

You can add a machine-specific configure preset or pass these as `-D` options to CMake.
