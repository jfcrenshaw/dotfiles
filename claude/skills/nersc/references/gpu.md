# NERSC GPU specifics (current system: Perlmutter)

Perlmutter's GPU nodes have **4× NVIDIA A100** + 1× AMD Milan CPU + 256 GB DDR4. There are two A100 generations on the system: 40 GB and 80 GB HBM. Most jobs don't care; ML training that's HBM-bound does.

## Constraints

| Want | `-C` value |
|---|---|
| Any GPU node                  | `gpu` |
| 80 GB A100 only               | `gpu&hbm80g` |
| (Don't pin GPU model)         | `gpu` (the scheduler chooses) |

## Allocation patterns

```bash
# 1 node, all 4 GPUs (typical training run)
salloc -C gpu -N 1 --gpus-per-node=4 -c 32 -t 4:00:00 -A <repo>_g -q gpu_interactive

# Multi-node multi-GPU (data-parallel)
sbatch -C gpu -N 4 --ntasks-per-node=4 --gpus-per-node=4 --gpus-per-task=1 \
       -c 32 -t 12:00:00 -A <repo>_g -q gpu_regular myjob.sbatch

# 1 GPU, single-process, debugging
salloc -C gpu -N 1 --gpus-per-node=1 -c 8 -t 1:00:00 -A <repo>_g -q gpu_debug
```

## CPU/GPU ratio

GPU host CPU = AMD Milan 64-core (128 logical), but only **32 cores per node are available** to the job (the rest is reserved for system/network). One typical placement: 4 ranks × 8 CPUs each × 1 GPU each = `--ntasks-per-node=4 -c 8 --gpus-per-task=1`.

## GPU-aware MPI

```bash
export MPICH_GPU_SUPPORT_ENABLED=1
```

Set this when you want to pass GPU pointers directly to `MPI_Send`/`MPI_Recv`. Without it, GPU-buffer MPI calls silently corrupt or crash. The Cray MPICH on Perlmutter supports it; mainline OpenMPI does not — check `mpicc --version`.

## NCCL

For PyTorch/DDP and similar, use NCCL. The defaults usually work, but for multi-node Perlmutter:

```bash
export NCCL_NET_GDR_LEVEL=PHB        # PCIe host bridge fallback when needed
export NCCL_CROSS_NIC=1              # Slingshot multi-NIC
export NCCL_SOCKET_IFNAME=hsn        # Slingshot HSN
export NCCL_IB_HCA=^mlx5_0           # exclude management NIC if present
```

NERSC publishes a recommended set in their PyTorch docs; check there before tuning by hand.

## Common mistakes

- Forgetting `_g` suffix on the account → job runs but charges wrong (or fails to start).
- `--gpus=4` without `-N 1` → can spread across nodes unpredictably. Use `--gpus-per-node=4`.
- One rank, 4 GPUs, no model parallelism → CUDA device 0 only; the other 3 idle. Either set `CUDA_VISIBLE_DEVICES` per rank or use `--gpus-per-task`.
- Running a JAX/PyTorch script that calls `torch.cuda.is_available()` from the **login node** → returns False (login nodes have no GPU). Move to compute first.
- `nvidia-smi` from inside an `sbatch` script without `srun` → shows the head node's GPUs only, not what your tasks see.

## Diagnostics

```bash
srun nvidia-smi                                        # what each rank sees
srun --gpu-bind=verbose,single:1 nvidia-smi -L         # confirm 1:1 GPU binding
sacct -j <JOBID> -o JobID,State,ExitCode,MaxRSS,Elapsed
seff <JOBID>                                           # post-hoc efficiency report
```
