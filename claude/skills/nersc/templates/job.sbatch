#!/bin/bash
# NERSC Slurm template (current system: Perlmutter). Fill in or remove every <<...>>.
#
# Submit with:    sbatch job.sbatch
# Check status:   squeue -u $USER
# Live monitor:   sqs ; or: scontrol show job <JOBID>

#SBATCH -J <<JOBNAME>>
#SBATCH -A <<REPO>>                    # CPU repo (e.g. m1727). For GPU use the *_g version.
#SBATCH -C cpu                         # `cpu` = Milan; `gpu` = Milan + 4× A100. Add `&hbm80g` to require 80 GB GPUs.
#SBATCH -q regular                     # CPU: interactive|debug|regular|shared|preempt|overrun
                                       # GPU: gpu_interactive|gpu_debug|gpu_regular|gpu_shared|gpu_preempt
#SBATCH -N 1                           # nodes
#SBATCH --ntasks-per-node=1            # MPI ranks per node
#SBATCH -c 128                         # cpus per task. cpu node = 128 logical; gpu host CPU = 32 (1 socket, 64 logical)
##SBATCH --gpus-per-node=4             # uncomment for GPU jobs
#SBATCH --mem=0                        # 0 = whole-node memory. For shared QOS, set explicitly.
#SBATCH -t 04:00:00                    # HH:MM:SS — always set explicitly
#SBATCH -o logs/slurm-%j.out
#SBATCH -e logs/slurm-%j.err
#SBATCH --open-mode=append             # safe under preempt requeue
#SBATCH --mail-type=END,FAIL
##SBATCH --mail-user=<<EMAIL>>

set -euo pipefail
mkdir -p logs

# --- environment ---
module load python                     # or your stack: `module load <your-modules>`
# source activate /global/common/software/<project>/envs/<name>

# --- runtime hygiene ---
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-1}
# GPU jobs only:
# export MPICH_GPU_SUPPORT_ENABLED=1
# export SLURM_CPU_BIND="cores"

# --- the work ---
# ALWAYS launch real work via srun, not bare python/mpiexec.
srun -n $SLURM_NTASKS python myscript.py "$@"
