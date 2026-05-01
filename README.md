# Improved Nano Syntax Highlighting

[![install-test](https://github.com/mofii/nano-syntax-highlighting/actions/workflows/install-test.yml/badge.svg?branch=main)](https://github.com/mofii/nano-syntax-highlighting/actions/workflows/install-test.yml)
[![release](https://img.shields.io/github/v/release/mofii/nano-syntax-highlighting?label=release&color=blue)](https://github.com/mofii/nano-syntax-highlighting/releases/latest)
[![license](https://img.shields.io/github/license/mofii/nano-syntax-highlighting)](LICENSE)

Drop-in syntax highlighting for ~130 languages and file formats in
[GNU nano][nano] 6.0+. Cross-platform installer (macOS / Linux), with
a sandboxed install-script test harness, automated semantic releases,
and CI on both OSes.

## About this fork

This is the third in the chain
[scopatz/nanorc][scopatz] →
[galenguyer/nano-syntax-highlighting][galenguyer] → this repo. It
exists to keep the project moving: the upstream installer didn't work
on macOS without `wget`, and the fix wasn't adopted there. While the
doors were open this fork also picked up idempotent re-installs,
GNU vs. BSD `sed` handling, action-version upkeep via Dependabot,
branch protection, and a Conventional-Commit release flow. Issues
and PRs here are reviewed.

## Requirements

GNU nano 6.0 or newer (released December 2021). Older nano expects
different colour names and directives than this repository ships;
if you're on an older nano, use
[galenguyer/nano-syntax-highlighting][galenguyer] instead — it
still maintains the legacy `pre-*` branches.

## Install

### Automatic (recommended)

Pipe the installer to your shell:

```sh
curl -fsSL https://raw.githubusercontent.com/mofii/nano-syntax-highlighting/main/install.sh | bash
```

Or with `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/mofii/nano-syntax-highlighting/main/install.sh | bash
```

The installer:

1. Downloads the
   [latest release](https://github.com/mofii/nano-syntax-highlighting/releases/latest)
   and unpacks the syntax files into `~/.nano/`.
2. Wires up `~/.nano/`-style includes into `~/.nanorc`.

That's it — open a file in nano and you should see colour. No further
configuration step is required.

#### Lite mode

If you want this fork's syntaxes inserted with *lower* precedence than
nano's stock ones (so upstream definitions win on conflict), pass `-l`:

```sh
curl -fsSL https://raw.githubusercontent.com/mofii/nano-syntax-highlighting/main/install.sh | bash -s -- -l
```

### Manual

Clone the repo somewhere on your machine:

```sh
git clone https://github.com/mofii/nano-syntax-highlighting.git ~/.nano-syntax-highlighting
```

Then add one of the following to your `~/.nanorc` (or `/etc/nanorc`
for system-wide):

```nanorc
# Include all syntaxes (recommended)
include "~/.nano-syntax-highlighting/src/*.nanorc"

# Or include the prebuilt manifest (one include line per syntax)
include "~/.nano-syntax-highlighting/src/nanorc"

# Or pick specific languages
include "~/.nano-syntax-highlighting/src/c.nanorc"
include "~/.nano-syntax-highlighting/src/python.nanorc"
```

Pick whichever clone path suits you (`~/.nano-syntax-highlighting/`
above is just a default that doesn't collide with the automatic
installer's `~/.nano/`).

## Contributing

PRs welcome. The short version:

- **Add a new syntax**: drop `<lang>.nanorc` into [`src/`](src/),
  then run `tools/include-list-gen.sh` to refresh `src/nanorc`.
- **Test locally**: `tools/test-install.sh` exercises the installer
  end-to-end in a sandboxed `$HOME` (covers `unzip`/`wget`/`curl`
  guards, idempotent re-install, and lite mode).
- **PR titles** must be Conventional Commits (`feat:`, `fix:`,
  `chore:`, …); see [`CONTRIBUTING.md`](CONTRIBUTING.md) for the
  full conventions, the version-bump table, and the required CI
  checks before merge.

## Acknowledgements

Built on the work of:

- [scopatz/nanorc][scopatz] — original repository.
- [galenguyer/nano-syntax-highlighting][galenguyer] — predecessor
  fork that carried the project through 2024.
- The [GNU nano editor][nano], whose stock files are the reference
  for several syntaxes here.

[scopatz]: https://github.com/scopatz/nanorc
[galenguyer]: https://github.com/galenguyer/nano-syntax-highlighting
[nano]: https://www.nano-editor.org
