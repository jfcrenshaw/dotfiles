# NERSC QOSes (Perlmutter)

Slurm on Perlmutter selects a queue via `-q NAME`. The constraint (`-C cpu` or `-C gpu`) selects the node type. **CPU and GPU have separate QOS namespaces** — a CPU job uses `regular`/`shared`/`debug`/`interactive`, a GPU job uses `gpu_regular`/`gpu_shared`/`gpu_debug`/`gpu_interactive`. Mixing them up is a common pre-flight error (`sbatch -C gpu -q regular ...` will fail).

CPU QOSes:

| QOS | Use | Notes |
|---|---|---|
| `interactive` | Interactive `salloc`, ~4 h cap | Limited concurrency per user; for development |
| `debug` | Quick test runs, ~30 min cap | High priority, small max-nodes |
| `regular` | Default production | The workhorse |
| `shared` | Partial CPU node | Charge prorated by cores; small jobs only |
| `preempt` | Cheap, restartable | Can be preempted mid-run |
| `overrun` | Out-of-allocation | Free, lowest priority |

GPU QOSes (mirror the above but with `gpu_` prefix):

| QOS | Use |
|---|---|
| `gpu_interactive` | Interactive GPU `salloc` |
| `gpu_debug` | Short GPU test runs |
| `gpu_regular` | Default GPU production |
| `gpu_shared` | Partial GPU node (1–3 of 4 GPUs) |
| `gpu_preempt` | Cheap, restartable GPU |

Charge factors and exact wall-time/node limits change. **Check live values** with `scontrol show partition <name>`, `sacctmgr show qos format=Name,MaxWall,Priority`, or via <https://iris.nersc.gov> for the running cost.

## Picking a QOS

- *Editing/debugging code, want a shell:* `interactive` (CPU) or `gpu_interactive` (GPU).
- *Need to verify "does this script even start":* `debug` / `gpu_debug` (cap is plenty).
- *Real work:* `regular` / `gpu_regular`. Almost always.
- *Long-running checkpointable training:* `preempt` / `gpu_preempt` — significantly cheaper but the OS may reclaim the node. Use `--open-mode=append` and write checkpoints frequently.
- *Out of allocation but need to finish something:* `overrun` (free, but lowest priority — may sit days).

## Limits to remember

- Per-user concurrent job limits exist per QOS — `sacctmgr show qos format=Name,MaxJobsPerUser,MaxSubmitJobsPerUser` shows them.
- The "default" QOS in your association is what `salloc`/`sbatch` use if you don't pass `-q`. Check with `sacctmgr -nP show assoc user=$USER format=Account,QOS,DefaultQOS`.
