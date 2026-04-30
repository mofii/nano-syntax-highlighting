#!/bin/sh
# Shellcheck the project's shell scripts.
set -eu

base=$(cd "$(dirname "$0")/.." && pwd)

shellcheck \
    "$base/install.sh" \
    "$base/tool/include-list-gen.sh" \
    "$base/tool/shellcheck.sh" \
    "$base/tool/test-install.sh"
