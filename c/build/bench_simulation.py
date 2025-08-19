#!/usr/bin/env python3

import wandb
import time
import sys
import subprocess
import uuid
import os
import argparse

def get_git_commit_hash():
    try:
        # Get the full commit hash
        result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                              capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Benchmark miniWeather implementations')
    parser.add_argument('--case', type=str, help='Specify the test case name')
    parser.add_argument('executables', nargs='+', help='Executable files to benchmark')
    
    args = parser.parse_args()

    # Login to W&B using API key from environment variable
    wandb_api_key = os.getenv("WANDB_API_KEY")
    if wandb_api_key:
        wandb.login(key=wandb_api_key)
    else:
        print("Warning: WANDB_API_KEY environment variable not set")

    # Initialize a new W&B run with unique name
    run_id = str(uuid.uuid4())
    config = {
        "commit_hash": get_git_commit_hash(),
    }
    
    if args.case:
        config["case"] = args.case
    else:
        print("please pass in the --case argument")
        exit(1)


    wandb.init(
        project="miniWeather",
        name=f"{args.case}",
        config=config,
        reinit=True
    )
    

    results = []
    
    for exec_name in args.executables:
        start_time = time.time()
        subprocess.run(f"mpirun -np 1 --bind-to none --map-by slot ./{exec_name}", shell=True)
        end_time = time.time()

        subprocess.run(["mv", "output.nc", f'{exec_name}.nc'])
        elapsed_time = end_time - start_time
        results.append([exec_name.split('_')[0], elapsed_time])
        print(f'{exec_name} finished with {elapsed_time} sec')

    # Sort results by execution time (fastest to slowest)
    # results.sort(key=lambda x: x[1])
    
    # Log as a table for better visualization
    table = wandb.Table(data=results, columns=["implementation", "execution_time"])
    wandb.log({"benchmark_results": wandb.plot.bar(table, "implementation", "execution_time", 
                                                   title="Execution Time by Implementation")})

    wandb.finish()
