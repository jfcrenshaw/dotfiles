#!/bin/bash
# where_am_i.sh — orient on Perlmutter: login vs compute, allocation state, repos.
# Safe to run anywhere; read-only.

set -u

host=$(hostname)
case "$host" in
  login*|perlmutter*login*) class="LOGIN — do not run compute here" ;;
  nid*)                     class="compute" ;;
  *)                        class="(unknown — assume login)" ;;
esac

printf "Node:         %s   (%s)\n" "$host" "$class"
printf "NERSC_HOST:   %s\n" "${NERSC_HOST:-(unset)}"
printf "User / home:  %s   %s\n" "$USER" "${HOME:-?}"

if [ -n "${SLURM_JOB_ID:-}" ]; then
  printf "Allocation:   JOB=%s  QOS=%s  ACCOUNT=%s\n" \
      "$SLURM_JOB_ID" "${SLURM_JOB_QOS:-?}" "${SLURM_JOB_ACCOUNT:-?}"
  printf "  Nodes:      %s   tasks/node=%s\n" "${SLURM_JOB_NUM_NODES:-?}" "${SLURM_NTASKS_PER_NODE:-?}"
  printf "  CPUs:       per-node=%s  per-task=%s\n" "${SLURM_CPUS_ON_NODE:-?}" "${SLURM_CPUS_PER_TASK:-?}"
  printf "  GPUs:       %s\n" "${SLURM_GPUS_ON_NODE:-${SLURM_GPUS:-(none/cpu node)}}"
  printf "  Time left:  %s\n" "$(squeue -h -j $SLURM_JOB_ID -o '%L' 2>/dev/null || echo ?)"
else
  printf "Allocation:   none — not in a Slurm job. Use salloc/sbatch for compute.\n"
fi

echo
echo "Repos / QOS associations (sacctmgr):"
if command -v sacctmgr >/dev/null 2>&1; then
  sacctmgr -nP show assoc user="$USER" format=Account,QOS,DefaultQOS 2>/dev/null \
    | sort -u | sed 's/^/  /'
else
  echo "  sacctmgr not on PATH — try after `module load slurm` or on a login node."
fi

echo
echo "Loaded modules (top 8):"
module list 2>&1 | sed 's/^/  /' | head -10
