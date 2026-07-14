# Runnable examples

These examples use real GitHub dependencies and are intended for manual
learning. They are separate from the hermetic `e2e/` contracts used by CI.

- [singlebuildfile](singlebuildfile/README.md) uses one root BUILD file.
- [multibuildfile](multibuildfile/README.md) uses layer BUILD files under one
  root module.
- [multimodule](multimodule/README.md) remains an advanced topology with
  independently runnable modules.

Both examples use the unpublished fork through a fixed `git_override`. Replace
that override with a plain `bazel_dep` after `rules_odin` is published in BCR.
