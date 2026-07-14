# Git dependency fixture

`check.sh` creates a Git repository with deterministic source and commit
metadata, then declares an HTTPS remote through the public
`odin_deps.git_repository` tag. A temporary Git `url.insteadOf` rule maps that
URL to the local repository, so the test exercises system Git without network
access. It verifies the exact commit, generated `@parser//:parser` label,
missing-commit failure, and cached `--nofetch` build.

Run:

```sh
./check.sh
./check_private_failures.sh
```

The private failure script sets `GIT_TERMINAL_PROMPT=0`, uses a host-matched
credential store, and requires strict SSH host-key checking with an explicit
`known_hosts` file. Its loopback endpoints reject immediately, proving that
missing HTTPS or SSH credentials fail non-interactively and do not expose the
fixture marker.

Real private repositories use the normal system configuration: an OS-backed
HTTPS credential helper or an SSH agent/read-only deploy key plus managed
`known_hosts`. The extension accepts no token, password, helper command,
private key, SSH option, branch, or tag attribute. CI must keep
`GIT_TERMINAL_PROMPT=0` and must never disable host-key checking.
