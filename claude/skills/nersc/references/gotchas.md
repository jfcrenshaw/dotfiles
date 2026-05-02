# NERSC gotchas — extended (current system: Perlmutter)

The 10 in `SKILL.md` are the load-bearing ones. This file collects the long tail.

## Slurm / accounting

- **GPU repo suffix is `_g`**, not `gpu` or `-gpu`. `-A m1234_g` for GPU jobs, `-A m1234` for CPU. Each is allocated separately at IRIS.
- **Mixing CPU and GPU work in one job** charges against whichever repo is in `-A`. Don't run a GPU step under a CPU repo — it'll fail or charge incorrectly.
- **`shared` QOS is CPU-only.** GPU work must take a whole node (or use MIG, which Perlmutter doesn't currently expose).
- **Job arrays**: `--array=1-1000%50` runs 1000 tasks with at most 50 concurrent. Useful for self-throttling on a busy queue.
- **`scontrol show job <ID>` on a pending job** tells you *why* it's pending (Resources, Priority, AssocGrpCPURunMinutesLimit, …). Read this before assuming the queue is "just slow."
- **`sqs`** is NERSC's friendlier `squeue` — shows your jobs and projected start times. `sqs -h` for options.

## srun and binding

- A bare command inside `sbatch` runs only on the head compute node. **Always `srun`**.
- `srun --cpu-bind=cores` for CPU jobs that care about NUMA locality. Without binding, kernel migration can hurt large-OMP perf 30–50%.
- For GPU jobs, `srun --gpu-bind=single:1 ...` if you have one rank per GPU. Otherwise the default usually works.
- `srun` from a **login node** (no allocation) submits a tiny one-node job with default everything — usually a misuse. If you meant to test a command on compute, `salloc` first.

## Modules & environment

- `module load <X>` on a login node *does not* automatically apply on compute. Either `--export=ALL` (the default) plus the same modules in your shell at submit time, or — better — `module load` *inside* the sbatch script.
- `module purge && module load PrgEnv-gnu` is the right reset for a clean Cray PE state.
- The `cpe/<version>` module pins the entire programming environment. If a colleague's build doesn't reproduce, mismatched `cpe` versions are a likely culprit.
- `module spider <X>` searches all available modules including hidden ones; `module avail` only shows currently-loadable.

## Python environments

- `module load python` gives the NERSC-curated stack. Fine for many uses.
- `module load conda` gives Mambaforge — the right base for personal envs.
- **Place envs on `/global/common/software/<project>/envs/<name>`** for fast import; activation from `$HOME` can be 10–30× slower under metadata load.
- **Always `unset PYTHONPATH`** before activating a new env if you have one set in `~/.bashrc`. It's prepended to `sys.path` and silently overrides venv installs.
- `pip install --user` writes to `$HOME/.local` and is a recipe for conflicting installs across envs. Always install *into* the active venv/conda env.

## Filesystems

- `$HOME` inode quota (1M) trips before the byte quota for most workflows. `du --inodes -d 1 $HOME | sort -n | tail` to find what's filling it.
- **Don't `cp -r` between filesystems for >GB data** — use `tar | tar` over a pipe, or Globus for >100 GB. Better metadata behavior.
- Lustre `$PSCRATCH` write performance depends on stripe count for big files; `lfs setstripe -c 8 <dir>` *before* writing into a directory sets the stripe for new files in that dir.
- CFS project dirs may have group-write-only permissions; check `ls -ld <dir>` before being surprised by a permission denied. Use `chmod g+s <dir>` on a personal subdir to set the group sticky bit so files inherit the project group.

## Networking & external

- **Compute nodes have no internet** by default. `pip install` from inside a job fails; do it from a login node.
- For deliberate compute-node egress (e.g. WandB), use `--network=...` proxy environment variables documented at NERSC. Or pre-stage everything before submit.
- Globus is the supported tool for fast inter-site transfers; `scp`/`rsync` from a login node works for under-100-GB-ish.

## Shell hygiene

- `~/.bashrc` runs for non-interactive shells too — it loads on every Slurm job. Heavy ops (eval-ing slow commands, loading 30 modules) tax startup time on every srun. Keep it lean.
- `~/.bash_profile` for *interactive* login shell things; `~/.bashrc` for things that should also apply in scripts.
