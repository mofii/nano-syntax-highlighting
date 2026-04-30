#!/bin/sh
# Regenerate ../src/nanorc with one `include "~/.nano/<file>.nanorc"` line per
# syntax file under src/. The output order is the glob order, which we force
# to byte-wise via LC_ALL=C so the file is identical regardless of the
# contributor's locale.
set -eu

LC_ALL=C
export LC_ALL

src="$(cd "$(dirname "$0")/../src" && pwd)"

# rm -f so the script is idempotent even on a fresh checkout where
# the manifest may not exist yet (or was deleted by hand).
rm -f "$src/nanorc"

for n in "$src"/*.nanorc; do
    # glob guard: if no .nanorc files match, the loop var holds the
    # literal "*.nanorc"; -e on it returns false and we skip.
    [ -e "$n" ] || continue
    printf 'include "~/.nano/%s"\n' "$(basename "$n")" >> "$src/nanorc"
done
