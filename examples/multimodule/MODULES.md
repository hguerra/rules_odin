# Multi-module map

Run each module from its own directory:

- `libs/config` owns TOML parsing and its own lockfile.
- `apps/example` consumes that library through a local development override and
  owns the environment dependency and its own lockfile.

See each module README for commands.
