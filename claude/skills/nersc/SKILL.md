---
name: nersc
description: How to work productively at NERSC. Covers Slurm job submission and QOS selection (salloc/sbatch/srun, --account, --qos, --constraint), filesystem strategy (HOME/CFS/PSCRATCH/COMMUNITY) and quotas, login-vs-compute discipline, NERSC-specific gotchas (mandatory --account, GPU repo `_g` suffix, $PSCRATCH purge policy, srun for everything that runs on compute, login-node CPU caps), module/conda environment setup, and DESI-spectroscopy conventions on top of all that. The current flagship system is **Perlmutter** (CPU = AMD Milan, GPU = 4× A100/node) and the examples are written for it; the durable conventions (account/repo model, IRIS, CFS, JupyterHub, $PSCRATCH purge) carry across system upgrades. Use this skill whenever `$NERSC_HOST` is set, the user runs Slurm commands, touches `/global/cfs`, `/pscratch`, `/global/common/software`, works with `module load`, or does anything DESI-related — even if NERSC / Perlmutter isn't named explicitly.
---

# Working at NERSC

You're helping a user at **NERSC**, the DOE supercomputing center at LBL. The current flagship is **Perlmutter** (CPU + 4× A100 GPU) and the examples below are written for it; node names, constraints (`-C cpu`/`-C gpu`), and the `$PSCRATCH` mount may change with the next system, but the NERSC-wide conventions — account/repo model, QOS naming, CFS, IRIS, JupyterHub — carry across.

Hard rules: **never run real work on a login node**, **always pass `--account=<repo>`** (Slurm jobs without it die), **prefer `$PSCRATCH` for big I/O**, and **use `srun`** to launch anything inside an allocation that should land on compute.

Action-oriented; jump to the section that fits. Bundled scripts in `scripts/`, deeper reference in `references/`. DESI conventions are at the bottom — most users in this environment are doing DESI spectroscopy.

## Where am I? (always do this first)

```bash
scripts/where_am_i.sh        # this skill's helper
# or manually:
hostname                                          # login* = login node
echo "JOB=$SLURM_JOB_ID  CPUS=$SLURM_CPUS_ON_NODE GPUS=$SLURM_GPUS_ON_NODE"
echo "NERSC_HOST=$NERSC_HOST"
sacctmgr -nP show assoc user="$USER" format=Account,QOS
```

If `hostname` matches `login*` and `$SLURM_JOB_ID` is empty, you're on a **login node** — fine for editing, git, `module avail`, light Python, small file ops. Do not run sustained compute, multi-core, or big-memory work there. Login nodes throttle CPU and are shared with hundreds of other users; jobs that misbehave can be killed without warning.

## Choosing how to launch a job

| Situation | Use |
|---|---|
| Quick interactive work, debugging                 | `salloc -q interactive` (CPU) or `-q gpu_interactive` (GPU) |
| Short test runs (≤30 min), high priority          | `-q debug` / `-q gpu_debug` |
| Long-running interactive (Jupyter, tmux)          | [JupyterHub](https://jupyter.nersc.gov) — survives SSH disconnects |
| Batch / fire-and-forget                           | `sbatch -q regular` / `-q gpu_regular` |
| Many parameter variants                           | `sbatch --array=1-N` |
| Cheap, restartable, can be preempted              | `-q preempt` / `-q gpu_preempt` |
| Out of allocation but need to finish              | `-q overrun` (free, lowest priority) |

### `salloc` patterns

```bash
# CPU debug (Milan, 128 logical cores, 512 GB/node)
salloc -N 1 -C cpu -q interactive -t 60 -A <repo>

# GPU debug (Milan + 4× A100; -A must be the *_g version of your repo)
salloc -N 1 -C gpu -q gpu_interactive -t 60 -A <repo>_g --gpus=4

# Shared partial CPU node (cheaper for small jobs; CPU only)
salloc -N 1 -C cpu -q shared -c 16 --mem=32G -t 2:00:00 -A <repo>
```

### `sbatch` boilerplate

```bash
#!/bin/bash
#SBATCH -J jobname
#SBATCH -A REPO                       # CPU repo; or REPO_g for GPU. WITHOUT THIS THE JOB FAILS.
#SBATCH -C cpu                        # or `gpu`; add `&hbm80g` for 80 GB A100 only
#SBATCH -q regular                    # CPU: interactive|debug|regular|shared|preempt|overrun  GPU: gpu_interactive|gpu_debug|gpu_regular|gpu_shared|gpu_preempt
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -c 128                        # CPU cores per task (full node = 128 on cpu, 32 on gpu host CPU)
#SBATCH --gpus-per-node=4             # gpu jobs only; 4 A100s/node
#SBATCH -t 04:00:00                   # HH:MM:SS — Slurm has a default but ALWAYS set it
#SBATCH -o logs/slurm-%j.out
#SBATCH -e logs/slurm-%j.err
#SBATCH --open-mode=append            # safe under preempt requeue

module load python
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export MPICH_GPU_SUPPORT_ENABLED=1    # GPU jobs only; required for GPU-aware MPI

srun -n $SLURM_NTASKS python myscript.py ...
```

A ready-to-edit copy is at [`templates/job.sbatch`](templates/job.sbatch). For partition/QOS tradeoffs see [`references/qos.md`](references/qos.md); for GPU specifics see [`references/gpu.md`](references/gpu.md).

### Always launch with `srun` from inside a job

This is the NERSC-specific thing that bites people coming from other Slurm sites: a bare `python foo.py` inside an `sbatch` script runs on the head compute node only and ignores most of the resource request. `srun -n $SLURM_NTASKS ...` is what places tasks across the allocation, sets up GPU binding, and is the only thing that gives you the resource accounting you asked for. Even for single-task jobs, `srun` is the right habit — it's free and correct.

## Filesystems — where to write what

| Path | Var | Purpose | Backup | Quota / Retention |
|---|---|---|---|---|
| `/global/homes/<l>/<user>` | `$HOME` | Code, dotfiles, venvs. Slow metadata under load. | Snapshots + tape | 40 GB / 1M inodes |
| `/pscratch/sd/<l>/<user>` | `$PSCRATCH` (alias `$SCRATCH`) | **Big I/O, intermediate outputs, training data, sims.** Lustre. | None | ~20 TB / 10M inodes; **purged after inactivity** (currently ~8 weeks; verify with `myquota` / NERSC docs) |
| `/global/cfs/cdirs/<project>` | `$CFS` for the prefix | Project-shared data, durable. GPFS. | Snapshots vary by project | Per-project quota |
| `/global/common/software/<project>` | — | Read-only shared software install. Fast for many small reads (env activation, `import`). | — | Read-only on compute |
| Per-job `$TMPDIR` | `$TMPDIR` | Per-node temp; auto-cleaned on job exit. | — | RAM-backed; small |

**Default outputs to `$PSCRATCH`** unless the user specifies otherwise — that's where the I/O budget lives, and `$HOME` will run out of inodes quickly if you write nightly logs/checkpoints there. Move keepers to a CFS project dir before the purge window.

Quota check:

```bash
scripts/check_quota.sh        # this skill's helper
# or:
myquota
prjquota <project>            # CFS project quotas
```

More detail: [`references/filesystems.md`](references/filesystems.md).

## Modules and Python environments

NERSC uses Cray's `module` system (Lmod underneath). `module avail`, `module load X`. Don't `pip install` into a system Python — make a venv or conda env that lives on `$HOME` or (better, for fast import) on `/global/common/software/<project>/...`.

```bash
# Personal conda env (Mambaforge), placed on common-software for fast import
module load python
mamba create -p /global/common/software/<project>/envs/<name> python=3.12
source activate /global/common/software/<project>/envs/<name>

# Or: a venv (lighter)
python -m venv $HOME/.venvs/<name>
source $HOME/.venvs/<name>/bin/activate
```

Always check `echo $PYTHONPATH` after activation — a `PYTHONPATH` set in `~/.bashrc` is *prepended* to every Python and silently overrides venv installs.

## Common gotchas

These bite everyone at least once on Perlmutter:

1. **`--account` is mandatory** for Slurm jobs. No default. Without it, `sbatch`/`salloc` errors out. GPU jobs need the `_g`-suffixed repo (e.g. `m1234_g`), not the CPU one.

2. **`srun` is required to actually use the allocation.** Bare `python` inside `sbatch` runs on the head node only. Always wrap the work in `srun`.

3. **Login nodes throttle CPU.** Anything multi-minute / multi-core / >a few GB belongs in `salloc`/`sbatch`. Symptom of forgetting: a job that's "just slow" — it isn't slow, it's being throttled.

4. **`$PSCRATCH` is purged.** Check the policy on your account; assume ~8 weeks of inactivity. Touch keepers (`touch -a`) or move them to CFS.

5. **`$HOME` inode limit (1M) is the silent killer**, not space. Tools that drop millions of small files (pip caches, tarball extractions, conda) fill inodes long before bytes. Symptom: cryptic `No space left on device` with `df -h` showing free space.

6. **`module load` on the login node ≠ on compute.** Allocations get a fresh environment unless you propagate it (`#SBATCH --export=ALL` is the default, but be explicit if it matters). Best practice: `module load` *inside* the sbatch script.

7. **Preempt and overrun jobs can restart** mid-run. Use `--open-mode=append` and write idempotent code if you choose those QOSes.

8. **CFS metadata operations are slow** under load — avoid `find` or `ls -R` over million-file directories. Use Globus or `tar` for bulk moves.

9. **GPU-aware MPI needs `export MPICH_GPU_SUPPORT_ENABLED=1`** in the job script. Without it, `MPI_Send` of GPU buffers will silently corrupt or crash.

10. **Don't bypass safety hooks** (`git commit --no-verify`, `pip install --break-system-packages`, etc.). Diagnose the root cause.

More edge cases: [`references/gotchas.md`](references/gotchas.md).

## Surviving SSH disconnects

`salloc` interactive shells die when SSH closes. Two patterns that survive:

```bash
# 1. Detach the work from the shell, inside an salloc:
setsid nohup srun -n 1 python -u long_job.py > logs/job.log 2>&1 < /dev/null &
echo "PID=$!"

# 2. Use sbatch to begin with — fully detached.
```

For long *interactive* sessions (Jupyter, an editor) use NERSC's [JupyterHub](https://jupyter.nersc.gov) — it spawns its own Slurm job and persists across browser disconnects.

## Git and GitHub workflows at NERSC

```bash
module load gh                       # may not exist; alternatively install via conda
gh auth login                        # browser-based OAuth
git config --global user.name  "Your Name"
git config --global user.email "you@..."
ssh-keygen -t ed25519                # for push (paste pub key into GitHub)
ssh -T git@github.com
```

Patterns that work well on the cluster:
- `gh pr checkout <N>` to test a teammate's branch in the real NERSC environment (matches production better than their laptop).
- Long edit/commit loops via tmux on the login node, or via JupyterHub terminal.
- Confirm before push / force-push / history-rewrite — those need explicit user authorization.

See [`references/git-on-nersc.md`](references/git-on-nersc.md) for extended workflows.

## DESI spectroscopy at NERSC

Most users in this environment work on DESI. The DESI software stack is loaded via `module load desimodules/<tag>` (often already in `~/.bashrc`).

Key environment (set by `desimodules`):

| Var | Purpose |
|---|---|
| `DESI_ROOT=/global/cfs/cdirs/desi` | Top of the DESI CFS area |
| `DESI_SPECTRO_DATA=$DESI_ROOT/spectro/data` | Raw nightly data, `NIGHT/EXPID/` |
| `DESI_SPECTRO_REDUX=$DESI_ROOT/spectro/redux` | Processed productions (one subdir per `SPECPROD`) |
| `SPECPROD` | Current production label — set per task |
| `DESI_TARGET=$DESI_ROOT/target` | Targeting / fiberassign inputs |
| `DESI_SURVEYOPS=$DESI_ROOT/survey/ops/surveyops/trunk` | Survey ops trunk |

**Mountain releases** (alphabetical, internal): fuji → guadalupe → himalayas → iron → jura → kibo → loa → **matterhorn** (current internal as of 2026-04). Public-release map: `fuji`=EDR, `guadalupe`+`iron`=DR1, `kibo`+`loa`=DR2. `himalayas` and `jura` are frozen but never went public. `daily` is the rolling pipeline output. Verify the current frontier with `scripts/desi_prods.sh`.

Layout under `$DESI_SPECTRO_REDUX/<SPECPROD>/`:
- `exposures/NIGHT/EXPID/` — frame, sframe, cframe, sky, fiberflat per exposure.
- `tiles/cumulative/TILEID/LASTNIGHT/` — coadded spectra and redshifts per tile.
- `healpix/<survey>/<program>/<hp//100>/<hp>/` — healpix-coadded spectra (better for sample-level work).
- `zcatalog/` — concatenated redshift catalogs.
- `tilepix.fits`, `exposures-<SPECPROD>.fits`, `tiles-<SPECPROD>.fits` — top-level indices.

For file/HDU/column specifics, the **authoritative reference** is the [DESI data model](https://desidatamodel.readthedocs.io/en/latest/). Use `desispec.io.read_spectra` / `read_frame` rather than hand-rolling FITS reads — it handles the multi-arm coadd structure and unit conventions correctly. `fitsio` (in the stack) is preferred over `astropy.io.fits` for big tables on Perlmutter.

DESI compute repos: `desi` (CPU) and `desi_g` (GPU). DESI-internal output area: `$DESI_ROOT/users/$USER/` (group-writable, not purged). For sims/intermediate I/O, use `$PSCRATCH/desi/...`.

More: [`references/desi.md`](references/desi.md).

## Bundled scripts

Available under `scripts/`:

| Script | What it does |
|---|---|
| `where_am_i.sh`     | Login vs compute, `$NERSC_HOST`, allocation state, available repos. Run first. |
| `check_quota.sh`    | `myquota` plus CFS project quotas you have access to. Run **before** large writes. |
| `desi_prods.sh`     | Most-recently-touched DESI productions and the current "mountain" release. Identifies what `SPECPROD` should plausibly be. |

Run any of them directly: `scripts/check_quota.sh`. No dependencies beyond a NERSC shell.

## When you're not sure

- Authoritative docs: <https://docs.nersc.gov/>
- Status / outages: <https://www.nersc.gov/live-status/motd/>
- IRIS (account/repo dashboard): <https://iris.nersc.gov>
- JupyterHub: <https://jupyter.nersc.gov>
- Open a ticket: <https://help.nersc.gov> or `accounts@nersc.gov` for account issues
- DESI data model: <https://desidatamodel.readthedocs.io>
