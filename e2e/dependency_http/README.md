# HTTP dependency fixture

This fixture verifies the public `odin_deps.http_archive` path without network
access. `MODULE.bazel` uses an HTTPS URL, while `check.sh` supplies the reviewed
archive from `testdata/` through Bazel's `--distdir`. Bazel still verifies the
declared SHA-256 before extraction.

Run:

```sh
./check.sh
./check_private_failures.sh
```

The first script checks the generated `@parser//:parser` target, cached
`--nofetch` behavior, and rejection of incorrect archive bytes. The private
script checks missing GitHub and GitLab credentials, Basic authentication
without a login, rejection of a `.netrc` `default` entry, and non-disclosure of
its marker password. It intentionally fails before any network request.

The archive is deterministic: its gzip timestamp, tar metadata, file order,
owners, and file timestamps are fixed. Its reviewed SHA-256 is declared beside
the dependency in `MODULE.bazel`.
