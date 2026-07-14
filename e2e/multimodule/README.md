# Multi-module monorepo fixture

This fixture models separate release and dependency boundaries inside one Git
repository:

```text
apps/billing/     # module billing@0.1.0
apps/identity/    # module identity@0.1.0
libs/common/      # module common@0.1.0
```

Each directory owns a `MODULE.bazel`, `MODULE.bazel.lock`, `rules_odin`
override, toolchain registration, and distdir configuration. Each application
uses a root-only `local_path_override` for `common`; the library independently
owns the external parser declaration. No top-level module or shared lockfile is
required.

Run all module roots and confirm their lockfiles remain unchanged:

```sh
./check.sh
```

Use this layout only when applications or libraries need independent module
graphs, versions, lockfiles, or release lifecycles. Prefer the sibling
single-module fixture otherwise.
