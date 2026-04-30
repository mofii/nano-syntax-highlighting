#!/bin/bash
set -e

REPO="mofii/nano-syntax-highlighting"

# check for unzip before we continue
if ! command -v unzip >/dev/null 2>&1; then
  echo 'unzip is required but was not found. Install unzip first and then run this script again.' >&2
  exit 1
fi

# check for a download tool; prefer wget, fall back to curl
if command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
elif command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
else
  echo 'Either wget or curl is required but neither was found. Install one of them and then run this script again.' >&2
  exit 1
fi

# download URL into FILE using whichever tool is available
_download() {
  out="$1"
  url="$2"
  case "$DOWNLOADER" in
    wget) wget -O "$out" "$url" ;;
    curl) curl -fL -o "$out" "$url" ;;
  esac
}

# fetch URL contents to stdout, quietly; empty output on HTTP error
_fetch() {
  url="$1"
  case "$DOWNLOADER" in
    wget) wget -qO- "$url" ;;
    curl) curl -fsSL "$url" ;;
  esac
}

# resolve the archive URL: prefer the latest published GitHub release
# (vX.Y.Z), fall back to the main branch tip if the API call fails
_resolve_archive_url() {
  tag=$(_fetch "https://api.github.com/repos/${REPO}/releases/latest" \
        | awk -F'"' '/"tag_name":/ {print $4; exit}')
  if [ -n "$tag" ]; then
    echo "https://github.com/${REPO}/archive/refs/tags/${tag}.zip"
    return
  fi
  echo "Could not resolve latest release; falling back to main branch tip." >&2
  echo "https://github.com/${REPO}/archive/refs/heads/main.zip"
}

_fetch_sources() {
  url=$(_resolve_archive_url)

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  tmpzip="${tmpdir}/nanorc.zip"

  mkdir -p ~/.nano/
  cd ~/.nano/

  _download "$tmpzip" "$url"
  unzip -tq "$tmpzip"

  # archive root is "<repo>-<ref>" — for tags GitHub strips a leading "v",
  # so derive it from the zip itself instead of guessing
  dir=$(unzip -Z -1 "$tmpzip" | head -1 | cut -d/ -f1)
  unzip -oq "$tmpzip"
  # only copy the syntax files and the includes manifest — skip readme,
  # license, tool/, .github/, etc. cp (rather than mv) merges into an
  # existing ~/.nano/, so re-running install.sh doesn't fail on tool/.
  # -P preserves symlinks (gitcommit.nanorc -> git.nanorc, etc.).
  cp -P "${dir}"/*.nanorc "${dir}"/nanorc ./
  rm -rf "${dir}"
}

_update_nanorc() {
  touch "${NANORC_FILE}"
  # add all includes from ~/.nano/nanorc if they're not already there.
  # -F: literal match (include lines contain '.', '*' which are regex metachars)
  # -x: whole-line match (avoid partial-line false positives)
  while read -r inc; do
      if ! grep -qxF "$inc" "${NANORC_FILE}"; then
          echo "$inc" >> "$NANORC_FILE"
      fi
  done < ~/.nano/nanorc
}

_update_nanorc_lite() {
  touch "${NANORC_FILE}"
  # Insert our include line above the system-wide one. Use a tmp file
  # rather than `sed -i` so the same syntax works on GNU sed (Linux) and
  # BSD sed (macOS), which disagree on whether -i takes an argument.
  tmp=$(mktemp)
  sed '/include "\/usr\/share\/nano\/\*\.nanorc"/i\
include "~/.nano/*.nanorc"
' "${NANORC_FILE}" > "$tmp"
  mv "$tmp" "${NANORC_FILE}"
}


NANORC_FILE=~/.nanorc

case "$1" in
 -l|--lite)
   UPDATE_LITE=1
 ;;
 -h|--help)
   echo "Install script for nanorc syntax highlights (requires nano 6.0+)."
   echo "Call with -l or --lite to update .nanorc with secondary precedence to existing .nanorc includes"
   exit 0
 ;;
esac

_fetch_sources
if [ "$UPDATE_LITE" ]; then
  _update_nanorc_lite
else
  _update_nanorc
fi
