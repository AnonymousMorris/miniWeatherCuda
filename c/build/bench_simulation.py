#!/usr/bin/env python3

import wandb
import time
import sys
import subprocess
import uuid
import os

def get_git_commit_hash():
    try:
        # Get the full commit hash
        result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                              capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

# Login to W&B using API key from environment variable
wandb_api_key = os.getenv("WANDB_API_KEY")
if wandb_api_key:
    wandb.login(key=wandb_api_key)
else:
    print("Warning: WANDB_API_KEY environment variable not set")

# Initialize a new W&B run with unique name
run_id = str(uuid.uuid4())
wandb.init(
    project="miniWeather",
    name=f"benchmark-{run_id[:8]}",
    config={
        "commit_hash": get_git_commit_hash(),
        "run_id": run_id
    },
    reinit=True
)

# Enable system monitoring
wandb.log({"system": "monitoring_enabled"})


if __name__ == "__main__":
    results = []
    
    for exec_name in sys.argv[1:]:
        start_time = time.time()
        subprocess.run([f"./{exec_name}"])
        end_time = time.time()

        elapsed_time = end_time - start_time
        results.append([exec_name, elapsed_time])
        print(f'{exec_name} finished with {elapsed_time} sec')

    # Sort results by execution time (fastest to slowest)
    results.sort(key=lambda x: x[1])
    
    # Log as a table for better visualization
    table = wandb.Table(data=results, columns=["implementation", "execution_time"])
    wandb.log({"benchmark_results": wandb.plot.bar(table, "implementation", "execution_time", 
                                                   title="Execution Time by Implementation")})

wandb.finish()
