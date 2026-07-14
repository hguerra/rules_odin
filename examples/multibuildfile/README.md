# Multiple BUILD files tutorial

This tutorial has one module root and three Bazel packages. Each package uses a
nonrecursive fail-on-empty glob, so source and test files are discovered without
combining distinct Odin packages.

```sh
# Enter the tutorial's single module root.
cd rules_odin/examples/multibuildfile
# Resolve the Bzlmod dependency graph.
bazel mod deps
# Download every dependency required by the tutorial targets.
bazel fetch //...
# Compile the library, application, and test packages.
bazel build //...
# List the generated application executable.
ls -lh bazel-bin/apps/example/config_example
# Run the application package.
bazel run //apps/example:config_example
# Execute the deterministic configuration test.
bazel test //...
# Prove that tests can run using only the local Bazel cache.
bazel test --nofetch //...
# Remove generated Bazel outputs for this tutorial.
bazel clean
```

It downloads `toml_parser` and `simpleenv` through the same temporary
`git_override` and `odin_deps.github` workflow as the single BUILD tutorial.
