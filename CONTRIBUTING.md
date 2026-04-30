# Contributing

Thanks for the interest! A few notes for anyone opening a PR.

## PR titles must be Conventional Commits

PR titles are linted by [`amannn/action-semantic-pull-request`][1] and become
the squashed commit on `main`, which [release-please][2] reads to compute the
next version. Format:

```
<type>[optional scope]: <subject in lowercase>
```

Allowed types: `feat`, `fix`, `chore`, `docs`, `ci`, `refactor`, `test`,
`perf`, `style`, `build`, `revert`.

## Versioning

| Title                                                                         | Version bump      |
| ----------------------------------------------------------------------------- | ----------------- |
| `fix: ...`                                                                    | patch (`x.y.Z`)   |
| `feat: ...`                                                                   | minor (`x.Y.0`)   |
| `feat!: ...` *or* `BREAKING CHANGE:` in the body                              | major (`X.0.0`)   |
| `chore`, `docs`, `ci`, `refactor`, `test`, `perf`, `style`, `build`, `revert` | none (no release) |

## Local development

```bash
# Lint shell scripts (requires shellcheck)
tool/shellcheck.sh

# Exercise install.sh end-to-end in a sandbox $HOME
tool/test-install.sh

# Regenerate the includes manifest after adding a new *.nanorc
tool/include-list-gen.sh
```

## Merge flow

`main` is protected. PRs need all five checks green (`lint`, `shellcheck`,
`installer-sync`, `test-install (ubuntu-latest)`,
`test-install (macos-latest)`) and merge as a squash. The source branch is
auto-deleted on merge.

[1]: https://github.com/marketplace/actions/semantic-pull-request
[2]: https://github.com/googleapis/release-please-action
