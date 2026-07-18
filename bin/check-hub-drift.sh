#!/usr/bin/env bash
# Cross-region hub-appset drift check.
# The hubs/<region>/appsets/ files are intentionally duplicated per region for
# readability (plain YAML, no templating). Their ONLY allowed difference is the
# region token itself. This check normalizes the region token away and fails if
# any other byte differs — duplication without the possibility of drift.
set -euo pipefail
cd "$(dirname "$0")/.."

regions=()
for d in hubs/*/appsets; do
  regions+=("$(basename "$(dirname "$d")")")
done
[ "${#regions[@]}" -ge 2 ] || { echo "only ${#regions[@]} region(s) — nothing to compare"; exit 0; }

norm() {  # $1=region $2=file → normalized content on stdout
  # replace the region token (word-bounded, case-insensitive) with REGION
  sed -E "s/\b${1}\b/REGION/gI" "$2"
}

base="${regions[0]}"
rc=0
for f in hubs/"$base"/appsets/*.yaml; do
  name=$(basename "$f")
  for r in "${regions[@]:1}"; do
    other="hubs/$r/appsets/$name"
    if [ ! -f "$other" ]; then
      echo "DRIFT: $other missing (exists for $base)"; rc=1; continue
    fi
    if ! diff -u <(norm "$base" "$f") <(norm "$r" "$other") > /tmp/drift.$$ 2>&1; then
      echo "DRIFT: hubs/$base/appsets/$name vs hubs/$r/appsets/$name differ beyond the region token:"
      cat /tmp/drift.$$; rc=1
    fi
  done
done
# also catch files that exist in other regions but not in base
for r in "${regions[@]:1}"; do
  for f in hubs/"$r"/appsets/*.yaml; do
    [ -f "hubs/$base/appsets/$(basename "$f")" ] || { echo "DRIFT: $f missing in $base"; rc=1; }
  done
done
rm -f /tmp/drift.$$
[ $rc -eq 0 ] && echo "OK: ${#regions[@]} regions' appsets identical modulo region token"
exit $rc
