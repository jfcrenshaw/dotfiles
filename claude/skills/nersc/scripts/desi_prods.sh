#!/bin/bash
# desi_prods.sh — survey DESI internal productions and the current frontier.
# Read-only.

set -u
redux=/global/cfs/cdirs/desi/spectro/redux

if [ ! -d "$redux" ]; then
  echo "DESI redux dir not visible: $redux"
  echo "Are you in the desi group? (id -Gn)"
  exit 1
fi

echo "=== Most-recently-touched productions (top 15) ==="
ls -1dt "$redux"/*/ 2>/dev/null | head -15 | while read d; do
  name=$(basename "$d")
  mtime=$(stat -c %y "$d" 2>/dev/null | cut -d' ' -f1)
  printf "  %-30s mtime=%s\n" "$name" "${mtime:-?}"
done

echo
echo "=== Mountain-named releases (a–z) ==="
# Heuristic: single-word, lowercase, looks like a mountain. Not exhaustive.
for name in fuji guadalupe himalayas iron jura kibo loa matterhorn nevado olympus; do
  d="$redux/$name"
  if [ -e "$d" ]; then
    target=$(readlink -f "$d" 2>/dev/null)
    mtime=$(stat -c %y "$d" 2>/dev/null | cut -d' ' -f1)
    if [ "$target" != "$d" ]; then
      printf "  %-12s -> %s   mtime=%s\n" "$name" "$target" "${mtime:-?}"
    else
      printf "  %-12s (live)  mtime=%s\n" "$name" "${mtime:-?}"
    fi
  fi
done

echo
echo "=== Public releases (under \$DESI_ROOT/public) ==="
ls /global/cfs/cdirs/desi/public/ 2>/dev/null | grep -E '^(dr|edr)' | sed 's/^/  /'

echo
echo "Current shell SPECPROD: ${SPECPROD:-(unset)}"
[ -n "${SPECPROD:-}" ] && [ ! -d "$redux/$SPECPROD" ] && \
  echo "  WARNING: \$DESI_SPECTRO_REDUX/$SPECPROD does not exist."
