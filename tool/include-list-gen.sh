#!/bin/sh
# Regenerate ../nanorc with one `include "~/.nano/<file>.nanorc"` line per
# syntax file in the repo root. The output order is the glob order, which
# we force to byte-wise via LC_ALL=C so the file is identical regardless
# of the contributor's locale.
set -eu

LC_ALL=C
export LC_ALL

base="$(cd "$(dirname "$0")/.." && pwd)"

# rm -f so the script is idempotent even on a fresh checkout where
# nanorc may not exist yet (or was deleted by hand).
rm -f "$base/nanorc"

for n in "$base"/*.nanorc; do
    # glob guard: if no .nanorc files match, the loop var holds the
    # literal "*.nanorc"; -e on it returns false and we skip.
    [ -e "$n" ] || continue
    printf 'include "~/.nano/%s"\n' "$(basename "$n")" >> "$base/nanorc"
done
