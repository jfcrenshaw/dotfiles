#!/bin/bash
# check_quota.sh — show home + scratch quotas plus accessible CFS project quotas.
# Run this BEFORE a large write. Lustre/GPFS quota errors come back as cryptic
# write failures, not clear messages.

set -u

echo "=== myquota (HOME, PSCRATCH) ==="
if command -v myquota >/dev/null 2>&1; then
  myquota
else
  echo "  myquota not on PATH (are you on a Perlmutter login or compute node?)"
fi

echo
echo "=== CFS project quotas (groups you belong to) ==="
groups=$(id -Gn "$USER")
shown=0
for g in $groups; do
  if [ -d "/global/cfs/cdirs/$g" ]; then
    if command -v prjquota >/dev/null 2>&1; then
      out=$(prjquota "$g" 2>/dev/null)
      if [ -n "$out" ]; then
        echo "--- $g ---"
        echo "$out" | sed 's/^/  /'
        shown=$((shown+1))
      fi
    fi
  fi
done
[ $shown -eq 0 ] && echo "  (no CFS project quotas reported — try \`prjquota <project>\` directly)"

echo
echo "=== CFS user-area sizes (where you have a personal subdir) ==="
for d in /global/cfs/cdirs/*/users/$USER; do
  [ -d "$d" ] || continue
  size=$(du -sh --apparent-size "$d" 2>/dev/null | awk '{print $1}')
  printf "  %-60s %s\n" "$d" "${size:-?}"
done

echo
echo "Tip: \$PSCRATCH inode quota is usually the limiting factor for sims/checkpoints,"
echo "     not bytes. Watch the INODE_PCT column above."
