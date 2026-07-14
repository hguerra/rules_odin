# Single-module monorepo fixture

This is the recommended layout for multiple Odin applications that share one
dependency graph:

```text
MODULE.bazel
apps/
  billing/
  identity/
libs/
  core/
  feature/
```

The root module owns the `rules_odin` override, Odin toolchain, external
`parser` archive, and lockfile. `feature` depends directly on `shared_core` and
`@parser`; each application depends only on `feature`. Provider propagation
makes the two indirect collections and all their source inputs available to the
application compile actions.

The `.bazelrc` resolves the deterministic archive from the sibling HTTP
fixture's distdir, so these checks do not use the network:

```sh
bazel mod deps
bazel test //...
bazel fetch //...
bazel test --nofetch //...
```
