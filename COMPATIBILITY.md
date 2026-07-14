# Compatibility

Supported version matrix for `rules_odin`.

## Bazel Versions

| Bazel Version | Status    | Notes               |
| ------------- | --------- | ------------------- |
| 9.2.0         | Supported | Required and tested |

Earlier fork commits remain available to Bazel 7/8 users, but new releases do
not maintain or test compatibility with those Bazel versions.

## Odin Compiler Versions

| Odin Version | Status    | Notes                     |
| ------------ | --------- | ------------------------- |
| dev-2026-06  | Supported | Default toolchain version |
| dev-2026-05  | Supported |                           |

## Platforms

| Platform         | Status    | CI Tested | Notes                                          |
| ---------------- | --------- | --------- | ---------------------------------------------- |
| Linux (x86_64)   | Supported | Yes       | ubuntu-24.04                                   |
| Linux (arm64)    | Supported | Yes       | ubuntu-24.04-arm                               |
| macOS (arm64)    | Supported | Yes       | macos-latest (Apple Silicon)                   |
| macOS (x86_64)   | Untested  | No        | Toolchain entry exists, no CI runner available |
| Windows (x86_64) | Supported | Yes       | windows-latest                                 |

## Build System

| System                | Status        | Notes                |
| --------------------- | ------------- | -------------------- |
| bzlmod (MODULE.bazel) | Supported     | Primary, recommended |
| WORKSPACE             | Not supported |                      |

## Dependency extension

`odin_deps` is Bzlmod-only. HTTP materialization uses Bazel's built-in
downloader and does not require Git, curl, Python, or a system Odin compiler.
Git materialization requires a system `git` executable and external HTTPS or
SSH credential configuration. The generated repository layout is tested with
Bazel 9.2.0 through the public operating-system matrix. Both `strip_prefix` and
`strip_components` use the Bazel 9.2 repository API.

Single-module monorepos are the recommended topology. Independent modules in a
single Git repository are supported when each module root owns its lockfile,
overrides, extension visibility, and toolchain registration.

## Host Requirements

rules_odin downloads the Odin compiler hermetically, but the **linker** must be
available on the host:

| Platform | Required Host Tool                                  |
| -------- | --------------------------------------------------- |
| Linux    | `clang` (via system package manager)                |
| macOS    | Xcode Command Line Tools (`xcode-select --install`) |
| Windows  | MSVC Build Tools (Visual Studio)                    |
