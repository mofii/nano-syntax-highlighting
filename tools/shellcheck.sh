#!/bin/sh
# Shellcheck the project's shell scripts.
set -eu

base=$(cd "$(dirname "$0")/.." && pwd)

shellcheck \
    "$base/install.sh" \
    "$base/tools/include-list-gen.sh" \
    "$base/tools/shellcheck.sh" \
    "$base/tools/test-install.sh"
