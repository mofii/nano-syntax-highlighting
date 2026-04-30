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

# resolve an archive URL for the given ref:
#   - "master" → latest published GitHub release (vX.Y.Z), with a graceful
#     fallback to the master branch tip if the API call fails
#   - any "pre-X.Y" branch → branch tip (those legacy branches aren't tagged)
_resolve_archive_url() {
  br="$1"
  if [ "$br" = "master" ]; then
    tag=$(_fetch "https://api.github.com/repos/${REPO}/releases/latest" \
          | awk -F'"' '/"tag_name":/ {print $4; exit}')
    if [ -n "$tag" ]; then
      echo "https://github.com/${REPO}/archive/refs/tags/${tag}.zip"
      return
    fi
    echo "Could not resolve latest release; falling back to master branch tip." >&2
  fi
  echo "https://github.com/${REPO}/archive/refs/heads/${br}.zip"
}

_fetch_sources() {
  br=$(_find_suitable_branch)
  url=$(_resolve_archive_url "$br")

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
  unzip -o "$tmpzip"
  mv "${dir}"/* ./
  rm -rf "${dir}"
}

_update_nanorc() {
  touch $NANORC_FILE
  # add all includes from ~/.nano/nanorc if they're not already there
  while read -r inc; do
      if ! grep -q "$inc" "${NANORC_FILE}"; then
          echo "$inc" >> "$NANORC_FILE"
      fi
  done < ~/.nano/nanorc
}

_update_nanorc_lite() {
  sed -i '/include "\/usr\/share\/nano\/\*\.nanorc"/i include "~\/.nano\/*.nanorc"' "${NANORC_FILE}"
}

_version_str_to_num() {
  if [ -z "$1" ]; then
    return
  fi
  echo -n "$1" | awk -F . '{printf("%d%02d%02d", $1, $2, $3)}'
}

_find_suitable_branch() {
  # find the branch that is suitable for local nano
  verstr=$(nano --version 2>/dev/null | awk '/GNU nano/ {print ($3=="version")? $4: substr($5,2)}')
  ver=$(_version_str_to_num "$verstr")
  if [ -z "$ver" ]; then
    echo "Cannot determine nano's version, fallback to master" >&2
    echo "master"
    return
  fi
  branches=(
    pre-6.0
    pre-5.0
    pre-4.5
    pre-2.9.5
    pre-2.6.0
    pre-2.3.3
    pre-2.1.6
  )
  target="master"
  # find smallest branch that is larger than ver
  for b in "${branches[@]}"; do
    num=$(_version_str_to_num "${b#*pre-}")
    if (( ver < num )); then
      target="${b}"
    else
      break
    fi
  done
  echo "$target"
}


NANORC_FILE=~/.nanorc

case "$1" in
 -l|--lite)
   UPDATE_LITE=1
 ;;
 --find_suitable_branch)
  _find_suitable_branch
  exit 0
 ;;
 -h|--help)
   echo "Install script for nanorc syntax highlights"
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
