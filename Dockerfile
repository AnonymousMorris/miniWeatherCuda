# syntax=docker/dockerfile:1

FROM nvcr.io/nvidia/cuda:13.3.1-devel-ubuntu26.04

ARG BUILD_JOBS=4

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      cuda-nsight-systems-13-3 \
      git \
      m4 \
      openssh-client \
      perl \
      pkg-config \
      python3 \
      python3-venv \
      tmux \
 && rm -rf /var/lib/apt/lists/*

# Install the test runner used by the CUDA reference tests.
RUN python3 -m venv /opt/uv \
 && /opt/uv/bin/pip install --no-cache-dir uv==0.12.5

ENV PATH="/opt/uv/bin:${PATH}"

# Build CUDA-aware Open MPI 4.1.8.
ADD --checksum=sha256:fb41086bbed9300baa2f3d7572491facfe5257412fa524ec5a396aa9101d5c62 \
    https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.8.tar.gz \
    /tmp/openmpi.tar.gz

RUN mkdir /tmp/openmpi \
 && tar -xzf /tmp/openmpi.tar.gz --strip-components=1 -C /tmp/openmpi \
 && cd /tmp/openmpi \
 && ./configure \
      --prefix=/opt/openmpi \
      --with-cuda=/usr/local/cuda \
      --enable-mpi-fortran=no \
      --enable-oshmem=no \
 && make -j"${BUILD_JOBS}" \
 && make install \
 && cd / \
 && rm -rf /tmp/openmpi /tmp/openmpi.tar.gz

ENV OPENMPI_ROOT=/opt/openmpi \
    PATH="/opt/openmpi/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/openmpi/lib:${LD_LIBRARY_PATH}"

# Build PNetCDF 1.14.1 against the CUDA-aware Open MPI installation.
ADD --checksum=sha256:6f0f7221006c211fce9ddd2c008796b8c69dd717b2ad1be0b4027fc328fd3220 \
    https://parallel-netcdf.github.io/Release/pnetcdf-1.14.1.tar.gz \
    /tmp/pnetcdf.tar.gz

RUN mkdir /tmp/pnetcdf \
 && tar -xzf /tmp/pnetcdf.tar.gz --strip-components=1 -C /tmp/pnetcdf \
 && cd /tmp/pnetcdf \
 && MPICC=/opt/openmpi/bin/mpicc \
    MPICXX=/opt/openmpi/bin/mpicxx \
    CC=/opt/openmpi/bin/mpicc \
    CXX=/opt/openmpi/bin/mpicxx \
    ./configure \
      --prefix=/opt/pnetcdf \
      --disable-cxx \
      --disable-fortran \
      --enable-shared \
      --disable-static \
 && make -j"${BUILD_JOBS}" \
 && make install \
 && cd / \
 && rm -rf /tmp/pnetcdf /tmp/pnetcdf.tar.gz

ENV PNETCDF_ROOT=/opt/pnetcdf \
    PATH="/opt/pnetcdf/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/pnetcdf/lib:${LD_LIBRARY_PATH}"

# Catch accidental use of a non-CUDA-aware Open MPI build.
RUN ompi_info --parsable -l 9 --all \
 | grep -q 'mpi_built_with_cuda_support:value:true'

# Install the same pinned Tmux plugins used by the bundled configuration.
ARG TPM_COMMIT=e261deb1b47614eed3400089ce7197dc68acc4eb
ARG TMUX_ONEDARK_THEME_COMMIT=3607ef889a47dd3b4b31f66cda7f36da6f81b85c
ARG TMUX_RESURRECT_COMMIT=cff343cf9e81983d3da0c8562b01616f12e8d548
ARG TMUX_SENSIBLE_COMMIT=25cb91f42d020f675bb0a2ce3fbd3a5d96119efa

RUN set -eux; \
    install_plugin() { \
      name="$1"; \
      repository="$2"; \
      commit="$3"; \
      destination="/root/.config/tmux/plugins/${name}"; \
      git init -q "$destination"; \
      git -C "$destination" remote add origin "$repository"; \
      git -C "$destination" fetch --depth 1 origin "$commit"; \
      git -C "$destination" checkout -q --detach FETCH_HEAD; \
    }; \
    install_plugin tpm https://github.com/tmux-plugins/tpm.git "$TPM_COMMIT"; \
    install_plugin tmux-onedark-theme https://github.com/odedlaz/tmux-onedark-theme.git "$TMUX_ONEDARK_THEME_COMMIT"; \
    install_plugin tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect.git "$TMUX_RESURRECT_COMMIT"; \
    install_plugin tmux-sensible https://github.com/tmux-plugins/tmux-sensible.git "$TMUX_SENSIBLE_COMMIT"

COPY --chmod=0644 docker/tmux.conf /root/.config/tmux/tmux.conf

# Application source is cloned at instance startup so code changes do not
# require rebuilding this dependency image.
WORKDIR /workspace
