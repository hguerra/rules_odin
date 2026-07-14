# Application module

This module uses `local_path_override` for the sibling `example_config` module
and downloads `simpleenv` from GitHub. Both it and the library module retain
their own `rules_odin` `git_override` until BCR publication.

```sh
# Enter the independently runnable application module.
cd rules_odin/examples/multimodule/apps/example
# Resolve this module's Bzlmod dependency graph.
bazel mod deps
# Download every dependency required by the application targets.
bazel fetch //...
# Compile the application and test targets.
bazel build //...
# List the generated application executable.
ls -lh bazel-bin/example
# Run the application executable.
bazel run //:example
# Execute the deterministic application test.
bazel test //...
# Prove that tests can run using only the local Bazel cache.
bazel test --nofetch //...
# Remove generated Bazel outputs for this module.
bazel clean
```

Expected output:

```text
development name=odin-example port=8080
```
