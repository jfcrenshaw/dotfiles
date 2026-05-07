# ceci on NERSC — launchers and parsl

## Launcher choice

| Launcher | When to use |
|---|---|
| `mini` | Local dev; inside an interactive `salloc` on NERSC |
| `parsl` | NERSC batch — parsl submits a Slurm sub-job per stage |

`mini` is a subprocess runner: it's not a batch submitter and cannot queue jobs itself.
`parsl` is a full workflow manager that integrates with Slurm; use it when you want ceci to handle batch submission for you.

## Site configs

`site:` in the pipeline YAML tells ceci how to launch each stage's processes.

### `local` — single machine

```yaml
launcher:
  name: mini
  interval: 3   # seconds between completion polls

site:
  name: local
  max_threads: 8
```

Works on a laptop or on a login node for tiny test runs.
Stages with `nprocess > 1` use `mpirun` (or `mpiexec`); ensure MPI is available.

### `nersc-interactive` — inside `salloc`

```yaml
launcher:
  name: mini
  interval: 3

site:
  name: nersc-interactive
  max_threads: 32
```

Start an allocation first:
```bash
salloc -N 2 -C cpu -q interactive -t 2:00:00 -A m1727
```

Then run `ceci pipeline.yml` from the login shell that has `$SLURM_JOB_ID` set.
Ceci launches each stage with `srun -n <nprocess>`, which places tasks across the allocated compute nodes.
The mini launcher polls for completions; `interval` controls the poll period in seconds.

### `nersc-batch` — parsl submits Slurm jobs

```yaml
launcher:
  name: parsl

site:
  name: nersc-batch
  queue: regular        # debug | regular | premium
  account: m1727        # your Slurm repo (no _g suffix for CPU)
  max_jobs: 5           # maximum simultaneous Slurm jobs
  walltime: 3600        # seconds per sub-job
  constraint: cpu       # "cpu" or "gpu"; maps to -C flag
```

You run `ceci pipeline.yml` from an **sbatch script** (or an interactive node).
Parsl submits a separate Slurm job for each stage; stages that can run in parallel share the `max_jobs` budget.
Parsl writes its own logs under `runinfo/` in the working directory — check there for sub-job stderr.

**Minimal sbatch wrapper for a parsl pipeline:**
```bash
#!/bin/bash
#SBATCH -J ceci-pipeline
#SBATCH -A m1727
#SBATCH -C cpu
#SBATCH -q regular
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -c 4              # just for the ceci coordinator; workers get their own jobs
#SBATCH -t 08:00:00
#SBATCH -o logs/slurm-%j.out
#SBATCH -e logs/slurm-%j.err

source activate /global/common/software/<project>/envs/<name>
srun -n 1 ceci pipeline.yml
```

## Per-stage resource requests

For any site that submits sub-jobs, set resources per stage in the pipeline YAML:

```yaml
stages:
  - name: HeavyStage
    nprocess: 128          # MPI ranks (= Slurm --ntasks)
    threads_per_process: 1 # OMP threads per rank
    nodes: 1               # Slurm -N

  - name: LightStage
    nprocess: 1
    threads_per_process: 4
    nodes: 1
```

On `nersc-interactive`, `nprocess` drives `srun -n <nprocess>` directly.
On `nersc-batch`, `nodes` and `nprocess` map to `#SBATCH -N` and `#SBATCH --ntasks` in the sub-job.

## Parsl gotchas

1. **Parsl must be installed** in the same environment as ceci.
   Install with `pip install parsl`; check `python -c "import parsl"`.

2. **Parsl workers inherit the environment** from the submitting process.
   Activate your conda/venv **before** calling `ceci pipeline.yml`, otherwise worker jobs may see a different Python or missing packages.

3. **`runinfo/` grows unbounded** across pipeline restarts.
   Each `ceci` invocation appends a new `runinfo/<N>/` directory.
   Clean it up or set `PARSL_RUNDIR` to a `$PSCRATCH` path before long runs.

4. **Stage walltime includes queue wait time** from parsl's perspective.
   If a sub-job is still queued when the `walltime` clock expires, parsl kills it.
   Use `walltime` conservatively (not `debug` limits) for production stages.

5. **`max_jobs` is a soft cap**, not a guarantee.
   Parsl may submit fewer jobs if the DAG has no ready stages.
   Set `max_jobs` to match your allocation's job-submission budget, not the number of stages.

6. **GPU stages need the `_g` repo and `constraint: gpu`.**
   Per-stage GPU resource override is not natively supported in ceci's parsl site config.
   Run GPU and CPU stages in separate pipelines, or use `site: nersc-interactive` with a GPU allocation.

7. **`nersc-interactive` requires `$SLURM_JOB_ID` to be set.**
   If you run `ceci` from a login node with `site: nersc-interactive`, `srun` will fail with "no allocation" unless you are already inside an `salloc` session.
