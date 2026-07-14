#!/usr/bin/env sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$workspace/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/rules_odin_git_private.XXXXXX")
log_file="$test_root/failure.log"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

cat >"$test_root/MODULE.bazel" <<EOF
module(name = "rules_odin_git_private_failures")

bazel_dep(name = "rules_odin", version = "0.2.0")
local_path_override(
    module_name = "rules_odin",
    path = "$repo_root",
)

odin_deps = use_extension("@rules_odin//odin:deps_extensions.bzl", "odin_deps")
odin_deps.git_repository(
    name = "private_https",
    remote = "https://127.0.0.1:1/private.git",
    commit = "0000000000000000000000000000000000000000",
)
odin_deps.git_repository(
    name = "private_ssh",
    remote = "ssh://git@127.0.0.1:1/private.git",
    commit = "0000000000000000000000000000000000000000",
)
use_repo(odin_deps, "private_https", "private_ssh")
EOF
touch "$test_root/BUILD.bazel"

cat >"$test_root/credentials" <<'EOF'
https://fixture:RULES_ODIN_GIT_SECRET_MARKER@unrelated.invalid
EOF
cat >"$test_root/gitconfig" <<EOF
[credential]
    helper = store --file=$test_root/credentials
EOF
touch "$test_root/known_hosts"
chmod 600 "$test_root/credentials" "$test_root/known_hosts"

check_failure() {
    repository=$1

    if (cd "$test_root" && \
        GIT_CONFIG_GLOBAL="$test_root/gitconfig" \
        GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$test_root/known_hosts" \
        GIT_TERMINAL_PROMPT=0 \
        bazel --batch query "@$repository//:$repository") >"$log_file" 2>&1; then
        echo "expected @$repository to fail without private credentials" >&2
        exit 1
    fi
    if ! grep -Eiq "git|fetch|connect|repository" "$log_file"; then
        echo "@$repository did not report a Git transport failure" >&2
        sed -n '1,120p' "$log_file" >&2
        exit 1
    fi
    if grep -Fq "RULES_ODIN_GIT_SECRET_MARKER" "$log_file"; then
        echo "@$repository leaked the fixture credential marker" >&2
        exit 1
    fi
}

check_failure private_https
check_failure private_ssh
