#!/usr/bin/env sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log_file=$(mktemp "${TMPDIR:-/tmp}/rules_odin_http.XXXXXX")
wrong_workspace=$(mktemp -d "${TMPDIR:-/tmp}/rules_odin_http_workspace.XXXXXX")
trap 'rm -f "$log_file"; rm -rf "$wrong_workspace"' EXIT HUP INT TERM

cd "$workspace"

bazel mod deps
bazel mod deps --lockfile_mode=error

resolved_commit=f5c7a632d83a6a28ddd59aa1c12e94160359b7b8
resolved_sha256=e3738b874b05c33848427ac8d84927436b7c4362063a993050326d1d4205ea97
if ! grep -Fq "toml_parser-$resolved_commit" MODULE.bazel.lock; then
    echo "provider tag was not locked as its resolved commit" >&2
    exit 1
fi
if ! grep -Fq "\"sha256\": \"$resolved_sha256\"" MODULE.bazel.lock; then
    echo "provider archive checksum was not frozen in MODULE.bazel.lock" >&2
    exit 1
fi
bazel query @provider_contract//:provider_contract --output=location
bazel query --nofetch @provider_contract//:provider_contract --output=location

bazel test --distdir=testdata //...
bazel query --distdir=testdata @parser//:parser --output=location
bazel fetch --distdir=testdata //...
bazel test --distdir=testdata --nofetch //...

repo_root=$(CDPATH= cd -- "$workspace/../.." && pwd)
archive="$workspace/testdata/parser.tar.gz"
cat >"$wrong_workspace/MODULE.bazel" <<EOF
module(name = "rules_odin_http_checksum_failure")

bazel_dep(name = "rules_odin", version = "0.2.0")
local_path_override(
    module_name = "rules_odin",
    path = "$repo_root",
)

odin_http_repository = use_repo_rule(
    "@rules_odin//odin/private:deps_repositories.bzl",
    "odin_http_repository",
)

odin_http_repository(
    name = "parser_bad",
    dependency_name = "parser_bad",
    urls = ["file://$archive"],
    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    auth = "none",
    package_path = "parser",
    source_subdir = "src",
    strip_prefix = "parser-source",
)
EOF
touch "$wrong_workspace/BUILD.bazel"

if (cd "$wrong_workspace" && bazel --batch query @parser_bad//:parser_bad) >"$log_file" 2>&1; then
    echo "expected the wrong archive checksum to fail" >&2
    exit 1
fi

if ! grep -Eiq "checksum|sha-?256" "$log_file"; then
    echo "wrong-checksum failure did not identify integrity verification" >&2
    sed -n '1,120p' "$log_file" >&2
    exit 1
fi
