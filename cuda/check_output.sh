#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 )); then
  echo "Usage: $0 EXECUTABLE MASS_TOLERANCE ENERGY_TOLERANCE [LAUNCHER ...]" >&2
  exit 2
fi

executable=$1
mass_tolerance=$2
energy_tolerance=$3
shift 3

if [[ ! -x "$executable" ]]; then
  echo "Executable not found or not executable: $executable" >&2
  exit 2
fi

output_file=$(mktemp)
trap 'rm -f "$output_file"' EXIT

if (( $# > 0 )); then
  "$@" "$executable" >"$output_file"
else
  "$executable" >"$output_file"
fi

mass_change=$(awk '/d_mass:/ { value=$2 } END { print value }' "$output_file")
energy_change=$(awk '/d_te:/ { value=$2 } END { print value }' "$output_file")

if [[ -z "$mass_change" || -z "$energy_change" ]]; then
  echo "The executable did not report d_mass and d_te:" >&2
  cat "$output_file" >&2
  exit 1
fi

awk -v value="$mass_change" -v tolerance="$mass_tolerance" 'BEGIN {
  if (value != value || value == "NaN") exit 1
  magnitude = value < 0 ? -value : value
  exit !(magnitude < tolerance)
}' || {
  echo "Mass change $mass_change exceeds tolerance $mass_tolerance" >&2
  exit 1
}

awk -v value="$energy_change" -v tolerance="$energy_tolerance" 'BEGIN {
  if (value != value || value == "NaN" || value >= 0) exit 1
  magnitude = value < 0 ? -value : value
  exit !(magnitude < tolerance)
}' || {
  echo "Energy change $energy_change must be negative and within tolerance $energy_tolerance" >&2
  exit 1
}
