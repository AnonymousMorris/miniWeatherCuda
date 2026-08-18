#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./upload.sh INSTANCE_ID FILE

Upload FILE from /home/morris/code/miniWeatherCuda to the same relative path
under /workspace/miniweather on a running Vast.ai instance.

FILE may be an absolute path inside the local project or a path relative to the
local project root.

Examples:
  ./upload.sh 48007681 cuda/miniWeather_mpi_cuda.cu
  ./upload.sh 48007681 /home/morris/code/miniWeatherCuda/cuda/CMakeLists.txt
EOF
}

if (( $# != 2 )); then
  usage >&2
  exit 2
fi

INSTANCE_ID=$1
FILE_ARGUMENT=$2
LOCAL_PROJECT_ROOT=/home/morris/code/miniWeatherCuda
REMOTE_PROJECT_ROOT=/workspace/miniweather

if [[ ! "$INSTANCE_ID" =~ ^[1-9][0-9]*$ ]]; then
  printf 'error: INSTANCE_ID must be a positive integer\n' >&2
  exit 2
fi

for command_name in vastai python3 ssh scp sha256sum awk realpath stat; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'error: required command was not found: %s\n' "$command_name" >&2
    exit 1
  }
done

LOCAL_PROJECT_ROOT=$(realpath -e -- "$LOCAL_PROJECT_ROOT")
if [[ "$FILE_ARGUMENT" == /* ]]; then
  LOCAL_CANDIDATE=$FILE_ARGUMENT
else
  LOCAL_CANDIDATE="${LOCAL_PROJECT_ROOT}/${FILE_ARGUMENT}"
fi
LOCAL_FILE=$(realpath -e -- "$LOCAL_CANDIDATE") || {
  printf 'error: file does not exist: %s\n' "$LOCAL_CANDIDATE" >&2
  exit 1
}

[[ -f "$LOCAL_FILE" ]] || {
  printf 'error: path is not a regular file: %s\n' "$LOCAL_FILE" >&2
  exit 1
}
case "$LOCAL_FILE" in
  "${LOCAL_PROJECT_ROOT}"/*) ;;
  *)
    printf 'error: file must be inside the local project root: %s\n' "$LOCAL_PROJECT_ROOT" >&2
    exit 1
    ;;
esac

RELATIVE_PATH=${LOCAL_FILE#"${LOCAL_PROJECT_ROOT}/"}
REMOTE_FILE="${REMOTE_PROJECT_ROOT}/${RELATIVE_PATH}"
REMOTE_DIR=${REMOTE_FILE%/*}
REMOTE_TEMP="${REMOTE_FILE}.upload-$$"
LOCAL_MODE=$(stat -c '%a' "$LOCAL_FILE")
VASTAI_SSH_KEY=${VASTAI_SSH_KEY:-"${HOME}/.ssh/vast_ai"}
KNOWN_HOSTS_DIR=${XDG_CACHE_HOME:-"${HOME}/.cache"}/miniweather
KNOWN_HOSTS_FILE="${KNOWN_HOSTS_DIR}/vastai-known-hosts-${INSTANCE_ID}"

[[ -f "$VASTAI_SSH_KEY" ]] || {
  printf 'error: Vast.ai SSH key was not found: %s\n' "$VASTAI_SSH_KEY" >&2
  exit 1
}

mkdir -p "$KNOWN_HOSTS_DIR"
chmod 0700 "$KNOWN_HOSTS_DIR"

SSH_URL=$(vastai ssh-url "$INSTANCE_ID")
SSH_PARTS=$(python3 - "$SSH_URL" <<'PY'
import sys
from urllib.parse import urlparse

url = urlparse(sys.argv[1])
if url.scheme != "ssh" or not url.username or not url.hostname or not url.port:
    raise SystemExit(f"invalid Vast.ai SSH URL: {sys.argv[1]}")
print(url.username, url.hostname, url.port, sep="\t")
PY
)
IFS=$'\t' read -r SSH_USER SSH_HOST SSH_PORT <<<"$SSH_PARTS"
SSH_TARGET="${SSH_USER}@${SSH_HOST}"
SSH_OPTIONS=(
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}"
  -i "$VASTAI_SSH_KEY"
)

read -r REMOTE_DIR_QUOTED REMOTE_FILE_QUOTED REMOTE_TEMP_QUOTED < <(
  python3 - "$REMOTE_DIR" "$REMOTE_FILE" "$REMOTE_TEMP" <<'PY'
import shlex
import sys

print(*(shlex.quote(value) for value in sys.argv[1:]), sep="\t")
PY
)

ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" "$SSH_TARGET" \
  "mkdir -p -- $REMOTE_DIR_QUOTED"

remote_temp_exists=0
cleanup_remote_temp() {
  if (( remote_temp_exists )); then
    ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" "$SSH_TARGET" \
      "rm -f -- $REMOTE_TEMP_QUOTED" >/dev/null 2>&1 || true
  fi
}
trap cleanup_remote_temp EXIT

LOCAL_SHA256=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')
remote_temp_exists=1
scp -P "$SSH_PORT" "${SSH_OPTIONS[@]}" \
  "$LOCAL_FILE" "${SSH_TARGET}:${REMOTE_TEMP}"

REMOTE_SHA256=$(
  ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" "$SSH_TARGET" \
    "sha256sum -- $REMOTE_TEMP_QUOTED" | awk '{print $1}'
)
if [[ "$REMOTE_SHA256" != "$LOCAL_SHA256" ]]; then
  printf 'error: checksum mismatch after upload\n' >&2
  printf '       local:  %s\n' "$LOCAL_SHA256" >&2
  printf '       remote: %s\n' "$REMOTE_SHA256" >&2
  exit 1
fi

ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" "$SSH_TARGET" \
  "chmod '$LOCAL_MODE' $REMOTE_TEMP_QUOTED && mv -f -- $REMOTE_TEMP_QUOTED $REMOTE_FILE_QUOTED"
remote_temp_exists=0

FINAL_SHA256=$(
  ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" "$SSH_TARGET" \
    "sha256sum -- $REMOTE_FILE_QUOTED" | awk '{print $1}'
)
if [[ "$FINAL_SHA256" != "$LOCAL_SHA256" ]]; then
  printf 'error: checksum mismatch after installing the remote file\n' >&2
  exit 1
fi

printf 'Uploaded %s\n' "$LOCAL_FILE"
printf '       to instance %s:%s\n' "$INSTANCE_ID" "$REMOTE_FILE"
printf 'SHA-256: %s\n' "$LOCAL_SHA256"
