# Single BUILD file tutorial

This is the simplest layout: one `MODULE.bazel`, one lockfile, and one root
`BUILD.bazel`. It uses nonrecursive, fail-on-empty globs for application and
test source discovery while downloading two real GitHub Odin dependencies.

## Setup

Install [Bazelisk](https://github.com/bazelbuild/bazelisk), then run:

```sh
# Clone the ruleset and its runnable tutorials.
git clone https://github.com/hguerra/rules_odin.git
# Enter the single-BUILD-file tutorial root.
cd rules_odin/examples/singlebuildfile
# Confirm that Bazelisk selected the pinned Bazel version.
bazel --version
```

`MODULE.bazel` uses `git_override` because `rules_odin` is not in BCR yet. The
override pins the fork to a full commit. Remove it after BCR publication and
keep `bazel_dep(name = "rules_odin", version = "0.2.0")`.

## Download dependencies

```sh
# Resolve the Bzlmod dependency graph.
bazel mod deps
# Download every dependency required by the tutorial targets.
bazel fetch //...
```

The `odin_deps.github` declarations download `toml_parser` and `simpleenv`.

## Build, run, and test

```sh
# Compile the application and test targets.
bazel build //...
# List the generated application executable.
ls -lh bazel-bin/config_example
# Run the configuration application.
bazel run //:config_example
# Execute the deterministic Odin test.
bazel test //...
```

Expected output:

```text
development name=odin-example port=8080
```

## Verify cached dependencies and clean

```sh
# Prove that tests can run using only the local Bazel cache.
bazel test --nofetch //...
# Remove generated Bazel outputs for this tutorial.
bazel clean
```
