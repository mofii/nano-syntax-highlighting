#!/usr/bin/env bash
# Exercise install.sh in an isolated $HOME with a minimal $PATH so we can
# verify the wget/curl detection logic (and the unzip guard) without
# touching the real ~/.nanorc or ~/.nano.
#
# Use bash, not zsh: this is a bash script and should be invoked as
#   ./tool/test-install.sh
# (the shebang picks the right interpreter). Pasting the body into an
# interactive zsh session will break on `#` comments and `(...)` tokens
# because zsh treats those as glob qualifiers unless `interactive_comments`
# is set.
#
# Usage:
#   tool/test-install.sh [-l|--lite] [--keep] [--quiet]
#     -l, --lite   pass -l through to install.sh in scenarios 1-5
#                  (the dedicated lite scenario at the end always runs -l)
#     --keep       keep the temp $HOME and $PATH dirs for post-mortem
#     --quiet      suppress install.sh stdout/stderr (still shows exit code
#                  and resulting .nanorc)

set -u

INSTALL_ARGS=()
KEEP=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    -l|--lite) INSTALL_ARGS+=("-l") ;;
    --keep)    KEEP=1 ;;
    --quiet)   QUIET=1 ;;
    -h|--help)
      sed -n '2,19p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

BASE="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$BASE/install.sh"

if [[ ! -x "$INSTALL" ]]; then
  echo "cannot find executable install.sh at $INSTALL" >&2
  exit 1
fi

# Build a minimal bin dir with everything install.sh needs EXCEPT wget/curl.
# We toggle wget/curl in and out per scenario by adding/removing symlinks.
TESTBIN=$(mktemp -d -t nanorc-testbin.XXXXXX)
for t in bash sh awk grep sed unzip mkdir mv rm rmdir touch cp ln cat echo \
         dirname basename nano tr cut head tail env mktemp printf chmod; do
  src=$(command -v "$t" 2>/dev/null) || continue
  ln -sf "$src" "$TESTBIN/$t"
done

HOMES=()

cleanup() {
  # `${arr[@]+"${arr[@]}"}` only expands when the array is non-empty.
  # Required for bash 3.2 (macOS) which otherwise errors under `set -u`
  # when expanding an empty array.
  if (( KEEP )); then
    echo
    echo "KEEP: leaving TESTBIN=$TESTBIN"
    for h in ${HOMES[@]+"${HOMES[@]}"}; do echo "KEEP: leaving HOME=$h"; done
  else
    rm -rf "$TESTBIN"
    for h in ${HOMES[@]+"${HOMES[@]}"}; do rm -rf "$h"; done
  fi
}
trap cleanup EXIT

FAIL=0

# Run install.sh in a fresh sandbox $HOME and return its exit code via the
# global RUN_RC. `extra=()` lets the caller append per-scenario flags
# without touching the global INSTALL_ARGS.
run_install() {
  local home="$1"; shift
  local extra=("$@")
  if (( QUIET )); then
    HOME="$home" PATH="$TESTBIN" bash "$INSTALL" \
      ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"} \
      ${extra[@]+"${extra[@]}"} >/dev/null 2>&1
    RUN_RC=$?
  else
    HOME="$home" PATH="$TESTBIN" bash "$INSTALL" \
      ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"} \
      ${extra[@]+"${extra[@]}"}
    RUN_RC=$?
  fi
}

run_scenario() {
  local label="$1" expect="$2"
  local home
  home=$(mktemp -d -t nanorc-home.XXXXXX)
  HOMES+=("$home")

  echo
  echo "=============================================================="
  echo "  $label   (expect exit $expect)"
  echo "=============================================================="

  run_install "$home"

  echo "--- exit=$RUN_RC ---"
  if [[ -f "$home/.nanorc" ]]; then
    echo "--- resulting \$HOME/.nanorc has $(wc -l <"$home/.nanorc" | tr -d ' ') lines ---"
  else
    echo "--- no \$HOME/.nanorc written ---"
  fi

  if [[ "$RUN_RC" -ne "$expect" ]]; then
    echo "FAIL: $label expected exit $expect, got $RUN_RC" >&2
    FAIL=1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# 1. Missing unzip (early guard at the top of install.sh).
rm -f "$TESTBIN/unzip"
run_scenario "no unzip" 1
have unzip && ln -sf "$(command -v unzip)" "$TESTBIN/unzip"

# 2. Neither wget nor curl.
rm -f "$TESTBIN/wget" "$TESTBIN/curl"
run_scenario "no wget, no curl" 1

# 3. curl only.
if have curl; then
  ln -sf "$(command -v curl)" "$TESTBIN/curl"
  run_scenario "curl only" 0
else
  echo "SKIP: curl not installed on this host"
fi

# 4. wget only.
rm -f "$TESTBIN/curl"
if have wget; then
  ln -sf "$(command -v wget)" "$TESTBIN/wget"
  run_scenario "wget only" 0
else
  echo "SKIP: wget not installed on this host; can't exercise wget-only path"
fi

# 5. Both present. install.sh prefers wget.
have curl && ln -sf "$(command -v curl)" "$TESTBIN/curl"
have wget && ln -sf "$(command -v wget)" "$TESTBIN/wget"
if have wget && have curl; then
  run_scenario "both (wget preferred)" 0
else
  echo "SKIP: need both wget and curl for the 'both' scenario"
fi

# 6. Re-install in the same $HOME. Guards against regressions of the
#    "mv: cannot move ... tool/ exists" / sed "in-place" failures that
#    surfaced the second time install.sh ran against an existing ~/.nano.
if have wget && have curl; then
  reinstall_home=$(mktemp -d -t nanorc-home.XXXXXX)
  HOMES+=("$reinstall_home")
  echo
  echo "=============================================================="
  echo "  re-install (run twice in same \$HOME)"
  echo "=============================================================="
  run_install "$reinstall_home";  rc1=$RUN_RC
  run_install "$reinstall_home";  rc2=$RUN_RC
  echo "--- first run exit=$rc1, second run exit=$rc2 ---"
  if (( rc1 != 0 || rc2 != 0 )); then
    echo "FAIL: re-install expected both exits 0, got $rc1 then $rc2" >&2
    FAIL=1
  fi
else
  echo "SKIP: need both wget and curl for the 're-install' scenario"
fi

# 7. Lite mode. Seeds a stock-style ~/.nanorc, then runs install.sh -l,
#    then asserts the include line was inserted. This is the only scenario
#    that exercises _update_nanorc_lite, which uses sed in a way that
#    differs subtly between GNU (Linux) and BSD (macOS) — running on
#    both runners in CI is what protects against that regressing.
if have wget && have curl; then
  lite_home=$(mktemp -d -t nanorc-home.XXXXXX)
  HOMES+=("$lite_home")
  echo 'include "/usr/share/nano/*.nanorc"' > "$lite_home/.nanorc"
  echo
  echo "=============================================================="
  echo "  lite mode (-l)"
  echo "=============================================================="
  run_install "$lite_home" -l
  echo "--- exit=$RUN_RC ---"
  if (( RUN_RC != 0 )); then
    echo "FAIL: lite mode expected exit 0, got $RUN_RC" >&2
    FAIL=1
  elif ! grep -qxF 'include "~/.nano/*.nanorc"' "$lite_home/.nanorc"; then
    echo "FAIL: lite mode did not insert 'include \"~/.nano/*.nanorc\"' line" >&2
    echo "--- resulting \$HOME/.nanorc: ---"
    cat "$lite_home/.nanorc"
    FAIL=1
  fi
else
  echo "SKIP: need both wget and curl for the 'lite mode' scenario"
fi

echo
if (( FAIL )); then
  echo "RESULT: at least one scenario failed"
  exit 1
fi
echo "RESULT: all scenarios passed"
