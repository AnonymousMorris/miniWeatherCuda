# CUDA reference tests

These tests run five 20-second CUDA simulations and compare the final `dens`, `uwnd`, `wwnd`, and `theta` fields in `output.nc` with saved OpenMP results.

Covered specifications:

- `DATA_SPEC_COLLISION`
- `DATA_SPEC_THERMAL`
- `DATA_SPEC_GRAVITY_WAVES`
- `DATA_SPEC_DENSITY_CURRENT`
- `DATA_SPEC_INJECTION`

Install [uv](https://docs.astral.sh/uv/) and run through the CUDA build. `uv` creates and caches the test environment automatically from the dependency metadata in `compare.py`.

```bash
cd cuda
cmake --preset local
cmake --build --preset local --parallel
ctest --preset local
```

The simulations use a `100 x 50` grid and compare only the final frame. OpenMP is not run during testing.
