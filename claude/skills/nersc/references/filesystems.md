# NERSC filesystems

NERSC's current flagship (Perlmutter) mounts several distinct tiers; using the wrong one is the most common cause of mysterious slowness, lost work, or lockouts. Quick decision tree:

- **Editing code, configs, dotfiles, small notebooks** → `$HOME`.
- **Big intermediate I/O, training data, sim outputs, checkpoints** → `$PSCRATCH`.
- **Project-shared data you want to keep** → CFS (`/global/cfs/cdirs/<project>`).
- **Shared software / conda envs / packages many users import** → `/global/common/software/<project>`.
- **Per-job temp** → `$TMPDIR`.

## The tiers in detail

### `$HOME` = `/global/homes/<l>/<user>` (also reachable as `/global/u2/...`)

- 40 GB / 1M inodes per user.
- GPFS with snapshots and offsite tape backup. Recoverable if you `rm` something important.
- **Slow under heavy concurrent metadata load.** Don't write logs from a 1000-rank job here.
- Inode pressure from pip/conda caches is the typical failure mode — the byte quota will look fine while writes fail.
- Persistent: never purged.

### `$PSCRATCH` (alias `$SCRATCH`) = `/pscratch/sd/<l>/<user>`

- ~20 TB / 10M inodes per user (current; check `myquota`).
- Lustre. Built for big parallel I/O. The right place for HDF5/FITS sim outputs, training datasets, intermediate artifacts.
- **Purged after inactivity.** Policy has changed over time; current is roughly 8 weeks of no `atime` activity. Move keepers to CFS or `touch` them periodically. `myquota` shows the policy in effect.
- Stripe count can matter for very large files (`lfs setstripe` / `lfs getstripe`). For most workloads the default is fine; for >100 GB single files, increase the stripe count.

### CFS = `/global/cfs/cdirs/<project>` (Community File System)

- GPFS, durable, shared per project. Quotas are per-project, not per-user.
- Fast for streaming, slow for million-file `find`/`ls -R`.
- Each project's structure is project-defined. DESI for example uses `$DESI_ROOT/spectro/redux/<SPECPROD>/...`.
- `prjquota <project>` shows the project's quota.
- Some projects have writable user areas at `/global/cfs/cdirs/<project>/users/<user>/`. These are persistent and are the right home for "outputs I want to keep but don't fit in $HOME."

### `/global/common/software/<project>`

- Read-only on compute nodes (nominally writable from login from project members).
- Optimized for many small reads — perfect for conda/venv environments. Activating a 200-MB env from `$HOME` can take seconds; from `/global/common/software` it's near-instant.
- The right place to install shared Python/conda environments your group will use.

### `$TMPDIR`

- Per-job, per-node. Auto-cleaned when the job ends.
- Backed by RAM on Perlmutter — *small* (a few GB). Don't write multi-GB outputs here.
- Best for ephemeral workspaces (untar, sort, etc.).

## Common mistakes

- Writing checkpoints to `$HOME` from a multi-node training job → inode exhaustion within a week.
- Putting a conda env on `$PSCRATCH` → the env itself gets purged.
- Trying to share something between two users via `$HOME` → the *other* user can't read it. Use CFS or `/global/common/software/<project>`.
- Big `find /global/cfs/...` → CFS metadata server pressure for *everyone* on the project. Use Globus/`tar` for bulk operations.

## Useful commands

```bash
myquota                       # HOME + SCRATCH
prjquota <project>            # CFS project
df -h $PSCRATCH               # raw filesystem
lfs quota -hu $USER $PSCRATCH # Lustre user quota detail
lfs getstripe <file>          # how is this Lustre file striped?
```
