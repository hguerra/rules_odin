# rules_odin

[![Check](https://github.com/hguerra/rules_odin/actions/workflows/check.yaml/badge.svg)](https://github.com/hguerra/rules_odin/actions/workflows/check.yaml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/v1/github.com/hguerra/rules_odin/badge)](https://securityscorecards.dev/viewer/?uri=github.com/hguerra/rules_odin)

Bazel rules for the [Odin programming language](https://odin-lang.org/).

## Overview

`rules_odin` provides hermetic Bazel build rules for Odin, a data-oriented systems programming language. The ruleset automatically downloads and manages the Odin compiler toolchain, requiring no system-wide Odin installation.

## Features

- Hermetic Odin toolchain management (no system install required)
- `odin_binary` rule for compiling executables
- `odin_library` rule for sharing packages via collection imports
- `odin_collection` rule for nested external source collections
- `odin_test` rule for running `@(test)`-annotated Odin procedures
- Transitive Odin library dependencies
- Checksum-verified HTTP and exact-commit Git dependencies through Bzlmod
- bzlmod-first (no WORKSPACE file needed)
- Multi-platform support: Linux (x86-64, ARM64), macOS (x86-64, ARM64), Windows (x86-64)
- Bazel 9.2.0

## Quick Start

Install [Bazelisk](https://github.com/bazelbuild/bazelisk), clone the fork, and
run `bazel --version`. Bazelisk reads `.bazelversion` and downloads Bazel 9.2.0.

Until the module is published in BCR, add this root-only override immediately
after `bazel_dep`:

```starlark
git_override(
    module_name = "rules_odin",
    remote = "https://github.com/hguerra/rules_odin.git",
    commit = "<last commit hash>",
)
```

The commit must be a full immutable revision. After BCR publication, remove the
override and retain only `bazel_dep`.

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_odin", version = "0.2.0")

odin = use_extension("@rules_odin//odin:extensions.bzl", "odin")
odin.toolchain(odin_version = "dev-2026-06")
use_repo(odin, "odin_toolchains")

register_toolchains("@odin_toolchains//:all")
```

Then in your `BUILD.bazel`:

```starlark
load("@rules_odin//odin:defs.bzl", "odin_binary", "odin_library", "odin_test")

odin_library(
    name = "greetings",
    srcs = glob(["lib/*.odin"]),
)

odin_binary(
    name = "hello",
    srcs = glob(["hello/*.odin"]),
    deps = [":greetings"],
)

odin_test(
    name = "greetings_test",
    srcs = glob(["tests/*.odin"]),
    deps = [":greetings"],
)
```

Import the library in your Odin code using the collection name (the `odin_library` target name) and the package directory name:

```odin
import greetings "greetings:lib"  // collection:name → lib/ directory
```

## Rules

### `odin_binary`

Compiles an Odin package (directory of `.odin` files) into an executable.

| Attribute              | Type        | Default      | Description                                     |
| ---------------------- | ----------- | ------------ | ----------------------------------------------- |
| `srcs`                 | label_list  | **required** | Odin source files (must share a package)        |
| `deps`                 | label_list  | `[]`         | `odin_library` targets to import as collections |
| `optimization`         | string      | `"none"`     | One of: none, minimal, speed, size, aggressive  |
| `debug`                | bool        | `True`       | Include debug symbols                           |
| `defines`              | string_dict | `{}`         | Compile-time `-define:` values                  |
| `extra_compiler_flags` | string_list | `[]`         | Additional flags passed to `odin build`         |
| `vet`                  | bool        | `False`      | Enable `-vet` checks                            |

### `odin_library`

Groups Odin source files into a library that can be imported by `odin_binary` targets via Odin's collection system. The library's target name becomes the collection name.

| Attribute | Type       | Default      | Description                                   |
| --------- | ---------- | ------------ | --------------------------------------------- |
| `srcs`    | label_list | **required** | Odin source files (must share a package)      |
| `deps`    | label_list | `[]`         | Direct Odin libraries propagated transitively |

### `odin_collection`

Aggregates every declared `.odin` file beneath one collection root without
compiling the external source as a separate artifact. It is primarily generated
by `odin_deps`; consumers normally depend on the generated target instead of
calling this rule directly.

| Attribute         | Type       | Default      | Description                                 |
| ----------------- | ---------- | ------------ | ------------------------------------------- |
| `srcs`            | label_list | **required** | Nested Odin source files                    |
| `collection_root` | string     | **required** | Normalized root containing collection paths |

### `odin_test`

Compiles and runs Odin tests using the built-in test runner. Source files must contain at least one procedure annotated with `@(test)`. The test binary is compiled at build time (cacheable) and executed by Bazel's test runner.

| Attribute              | Type        | Default      | Description                                     |
| ---------------------- | ----------- | ------------ | ----------------------------------------------- |
| `srcs`                 | label_list  | **required** | Odin source files with `@(test)` procedures     |
| `deps`                 | label_list  | `[]`         | `odin_library` targets to import as collections |
| `optimization`         | string      | `"none"`     | One of: none, minimal, speed, size, aggressive  |
| `debug`                | bool        | `True`       | Include debug symbols                           |
| `defines`              | string_dict | `{}`         | Compile-time `-define:` values (see below)      |
| `extra_compiler_flags` | string_list | `[]`         | Additional flags passed to the Odin compiler    |
| `vet`                  | bool        | `False`      | Enable `-vet` checks                            |

**Test runner defines** (passed via `defines`):

| Key                            | Default    | Description                           |
| ------------------------------ | ---------- | ------------------------------------- |
| `ODIN_TEST_FANCY`              | `false`    | ANSI progress display (auto-disabled) |
| `ODIN_TEST_THREADS`            | `0` (auto) | Worker thread count                   |
| `ODIN_TEST_NAMES`              | —          | Comma-separated test filter           |
| `ODIN_TEST_RANDOM_SEED`        | random     | Fixed seed for reproducibility        |
| `ODIN_TEST_FAIL_ON_BAD_MEMORY` | `false`    | Treat memory leaks as failures        |
| `ODIN_TEST_LOG_LEVEL`          | `info`     | Minimum log level                     |

## External Odin dependencies

The `odin_deps` module extension presents hosted archives and Git repositories
through the same target contract: `@<name>//:<name>`.

The common GitHub declaration needs only a repository and immutable commit:

```starlark
odin_deps = use_extension("@rules_odin//odin:deps_extensions.bzl", "odin_deps")
odin_deps.github(
    commit = "10aee3739d1a144efe79e95d8a094e9c1563bb03",
    name = "toml_parser",
    repository = "Up05/toml_parser",
)
use_repo(odin_deps, "toml_parser")
```

`gitlab` has the same attributes and accepts nested `group/project` slugs.
Exactly one of `commit` and `tag` is required. Tags are resolved to full commits
before materialization. If `sha256` is omitted, Bazel computes it on first
resolution and records the checksum-bearing generated repository specification
in `MODULE.bazel.lock`. Commit that file and use `--lockfile_mode=error` in CI.
An explicit, independently reviewed `sha256` remains supported.

Use the concise Git alias when an archive is unavailable or Git authentication
is required:

```starlark
odin_deps.git(
    commit = "10aee3739d1a144efe79e95d8a094e9c1563bb03",
    name = "toml_parser",
    url = "https://github.com/Up05/toml_parser.git",
)
use_repo(odin_deps, "toml_parser")
```

All tags accept `source_subdir` and `package_path`; the latter defaults to
`name`. The existing `http_archive` and `git_repository` tags remain available
for advanced control. Low-level HTTP requires exactly one of `sha256` or
SHA-256 SRI `integrity`, while low-level Git requires a lowercase full commit.
Branches, submodules, Git LFS, patches, and caller commands are not supported.

The extension returns root dependency metadata so `bazel mod tidy` can maintain
`use_repo`. Bzlmod still requires each generated repository to be imported into
the consuming root module.

`strip_prefix` and `strip_components` use the Bazel 9.2 repository API.

The generated repository downloads or checks out upstream source under Bazel's
external-repository area, then creates a private staging link at
`odin_deps/<package_path>`. This path is not created in the consumer worktree,
is not a clone destination users manage, and is not a public API. The generated
`odin_collection` recursively declares the staged Odin sources and exposes only
`@name//:name`.

### Private repositories

No tag accepts a token, password, key, credential command, header pattern, or
environment-variable name.

- `github(..., private = True)` uses only `api.github.com` bearer auth.
- `gitlab(..., private = True)` uses only `gitlab.com` bearer auth.
- `auth = "netrc_basic"` reads a matching host with login and password from
  `.netrc`.
- `auth = "github_bearer"` is restricted to `api.github.com`.
- `auth = "gitlab_bearer"` is restricted to `gitlab.com`.
- Private Git HTTPS uses the system Git credential helper. Private Git SSH uses
  the system SSH agent or read-only deploy key and managed `known_hosts`.

Authenticated HTTP rejects `.netrc` `default` entries. CI should create an
owner-readable ephemeral `.netrc`, use a short-lived read-only token, and remove
the file even after failure. Git CI must set `GIT_TERMINAL_PROMPT=0`; never
disable SSH host-key checking. Do not expose private dependencies to untrusted
pull-request jobs or untrusted remote caches/executors.

For GitHub Actions, use a short-lived GitHub App installation token on a manual
or otherwise trusted event. The opt-in workflow in
`.github/workflows/private-dependencies.yaml` is inert until its placeholder
configuration is supplied through protected repository variables and secrets.

### Repository layouts and cache behavior

Prefer one root `MODULE.bazel` for an `apps/` and `libs/` monorepo. It owns one
override, toolchain graph, extension usage, and lockfile. Use multiple modules
only when applications or libraries need independent versions, release
boundaries, dependency graphs, and lockfiles; every independently invoked root
must own its overrides and toolchain registration.

Run `bazel mod deps --lockfile_mode=error` in CI to reject unexpected lock
changes. Run `bazel fetch //...` once, then `bazel test --nofetch //...` to
verify that the local repository cache is sufficient. Git repositories require
system Git and do not have the archive repository-cache advantages. Provider
convenience tags place their calculated checksum in the generated repository
specification; low-level HTTP declarations continue to require the checksum in
`MODULE.bazel` itself.

## Supported Odin Versions

| Version     | Status    |
| ----------- | --------- |
| dev-2026-06 | Supported |
| dev-2026-05 | Supported |

See [COMPATIBILITY.md](COMPATIBILITY.md) for the full version matrix.

## Requirements

- Bazel 9.2.0
- **Linux**: `clang` or `gcc` (for linking)
- **macOS**: Xcode Command Line Tools
- **Windows**: MSVC "Desktop development with C++" workload

## Fork development

The dependency extension is maintained in
`https://github.com/hguerra/rules_odin` while preserving the compatible Bazel
module name `rules_odin`. Keep the original project as the read-only `upstream`
remote and the fork as writable `origin`:

```sh
git remote rename origin upstream
git remote add origin git@github.com:hguerra/rules_odin.git
git fetch upstream
git rebase upstream/main
```

Review upstream changes and rerun the complete Bazel/e2e matrix before pushing
the rebased feature branch. Do not change the module name or resolve upstream
and fork copies in the same module graph.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Tutorials

Run [examples/singlebuildfile](examples/singlebuildfile/README.md) for one root
BUILD file, or [examples/multibuildfile](examples/multibuildfile/README.md) for
layer BUILD packages under one module.
[examples/multimodule](examples/multimodule/README.md) remains the advanced
independent-module topology. The tutorials download real GitHub Odin
dependencies, then build, run, test, and validate the local cache.

## License

Apache License 2.0 - see [LICENSE](LICENSE).
