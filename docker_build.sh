#!/usr/bin/env bash
set -euo pipefail

: "${DOCKERHUB_USER:?Set DOCKERHUB_USER to your Docker Hub username}"
IMAGE_TAG=${IMAGE_TAG:-cuda12.6.3}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

docker build --tag "${DOCKERHUB_USER}/miniweather:${IMAGE_TAG}" "$SCRIPT_DIR"
