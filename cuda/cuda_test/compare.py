#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.*"
# dependencies = [
#   "netCDF4==1.7.4",
#   "numpy==2.5.2",
# ]
# ///

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

import netCDF4
import numpy as np


FIELDS = ("dens", "uwnd", "wwnd", "theta")


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Compare a CUDA miniWeather simulation with an OpenMP reference."
    )
    parser.add_argument("case", help="Reference case name")
    parser.add_argument("executable", type=Path, help="CUDA executable to run")
    parser.add_argument("references", type=Path, help="JSON reference file")
    return parser.parse_args()


def load_references(path):
    with path.open(encoding="utf-8") as reference_file:
        return json.load(reference_file)


def run_simulation(executable, work_directory):
    launcher = shlex.split(os.environ.get("TEST_MPI_COMMAND", ""))
    command = launcher + [str(executable.resolve())]
    result = subprocess.run(
        command,
        cwd=work_directory,
        text=True,
        capture_output=True,
    )

    if result.returncode == 0:
        return True

    print(result.stdout, file=sys.stderr)
    print(result.stderr, file=sys.stderr)
    return False


def validate_metadata(output, references):
    expected = {
        "x dimension": references["nx"],
        "z dimension": references["nz"],
        "final simulation time": references["sim_time"],
    }
    actual = {
        "x dimension": len(output.dimensions["x"]),
        "z dimension": len(output.dimensions["z"]),
        "final simulation time": float(output.variables["t"][-1]),
    }

    valid = True
    for name in expected:
        if not np.isclose(actual[name], expected[name]):
            print(
                f"Unexpected {name}: actual={actual[name]}, expected={expected[name]}",
                file=sys.stderr,
            )
            valid = False
    return valid


def compare_field(case, name, actual, expected, references):
    try:
        np.testing.assert_allclose(
            actual,
            expected,
            atol=references["absolute_tolerance"],
            rtol=references["relative_tolerance"],
        )
    except AssertionError as error:
        print(f"{case} {name}:\n{error}", file=sys.stderr)
        return False

    maximum_difference = np.abs(actual - expected).max()
    print(f"{case} {name}: max difference={maximum_difference:.3e}")
    return True


def compare_output(output_path, case, references):
    if not output_path.is_file():
        print(f"Simulation did not create {output_path}", file=sys.stderr)
        return False

    case_reference = references["cases"][case]
    with netCDF4.Dataset(output_path) as output:
        results = [validate_metadata(output, references)]
        for name in FIELDS:
            actual = np.asarray(output.variables[name][-1])
            expected = np.asarray(case_reference[name])
            results.append(compare_field(case, name, actual, expected, references))
    return all(results)


def main():
    arguments = parse_arguments()
    references = load_references(arguments.references)
    if arguments.case not in references["cases"]:
        print(f"Unknown reference case: {arguments.case}", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as directory:
        work_directory = Path(directory)
        if not run_simulation(arguments.executable, work_directory):
            return 1
        passed = compare_output(
            work_directory / "output.nc",
            arguments.case,
            references,
        )
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
