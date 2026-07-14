# Contributing to rules_odin

## Development Setup

1. Install [Bazelisk](https://github.com/bazelbuild/bazelisk); it selects the
   version pinned by `.bazelversion`.
2. Clone `https://github.com/hguerra/rules_odin.git` and enter the checkout.
3. Run `bazel build //...` and `bazel test //...`.

## Project Structure

```
rules_odin/
├── odin/                  # Main Starlark rules
│   ├── defs.bzl           # Public API
│   ├── toolchain.bzl      # Toolchain provider + rule
│   ├── extensions.bzl     # bzlmod module extension
│   ├── repositories.bzl   # Repository rules
│   └── private/           # Internal implementation
├── e2e/                   # Hermetic integration contracts and runner
├── examples/               # Manually runnable GitHub dependency tutorials
└── .github/workflows/     # CI pipelines
```

## Running Tests

```bash
# Build everything
bazel build //...

# Run every hermetic end-to-end contract (POSIX shell and Git required)
./e2e/check.sh

# Run a live tutorial with real GitHub dependencies
cd examples/singlemodule && bazel test //...
```

## Adding a New Odin Version

1. Get the release SHA256 hashes from the GitHub API:
   ```bash
   curl -s https://api.github.com/repos/odin-lang/Odin/releases/latest | jq '.assets[] | {name, digest}'
   ```
2. Add entries to `odin/private/versions.bzl`
3. Run `./e2e/check.sh` and the relevant tutorial commands
4. Submit a PR

## Code Style

- Use [Buildifier](https://github.com/bazelbuild/buildtools) for formatting `.bzl` and `BUILD` files
- Follow the [Bazel Starlark style guide](https://bazel.build/rules/deploying)

## Releasing

Releases are cut by tagging a commit:

```bash
git tag v0.x.0
git push origin v0.x.0
```

The current CI creates a GitHub Release. BCR publication is a separate,
reviewed operation and must not be claimed until its publication workflow and
registry metadata exist.
