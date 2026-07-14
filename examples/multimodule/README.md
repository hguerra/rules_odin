# Multi-module tutorial

Each independently invoked directory owns a `MODULE.bazel` and lockfile. This
is appropriate when a library and application have separate release boundaries.

Start with [libs/config](libs/config/README.md), then run the application in
[apps/example](apps/example/README.md).
