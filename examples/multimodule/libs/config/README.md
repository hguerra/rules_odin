# Config library module

This module downloads `toml_parser` and exposes `@example_config//:config`.

```sh
# Enter the independently runnable library module.
cd rules_odin/examples/multimodule/libs/config
# Resolve this module's Bzlmod dependency graph.
bazel mod deps
# Download every dependency required by the library target.
bazel fetch //...
# Compile the library target.
bazel build //...
# This library exposes source inputs to consumers and produces no standalone binary.
# Prove that the resolved graph works using only the local Bazel cache.
bazel test --nofetch //...
# Remove generated Bazel outputs for this module.
bazel clean
```

There are no test targets in this library-only tutorial. Its consumer test is
in `../../apps/example`.
