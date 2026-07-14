#!/usr/bin/env sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$workspace/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/rules_odin_http_private.XXXXXX")
log_file="$test_root/failure.log"
empty_netrc="$test_root/empty.netrc"
basic_netrc="$test_root/basic.netrc"
default_netrc="$test_root/default.netrc"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

: >"$empty_netrc"
cat >"$basic_netrc" <<'EOF'
machine packages.example.com
  password RULES_ODIN_HTTP_SECRET_MARKER
EOF
cat >"$default_netrc" <<'EOF'
default
  login fixture
  password RULES_ODIN_HTTP_SECRET_MARKER
EOF
chmod 600 "$empty_netrc" "$basic_netrc" "$default_netrc"

cat >"$test_root/MODULE.bazel" <<EOF
module(name = "rules_odin_http_private_failures")

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
    name = "missing_github",
    dependency_name = "missing_github",
    urls = ["https://api.github.com/repos/acme/parser/tarball/0000000000000000000000000000000000000000"],
    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    auth = "github_bearer",
    package_path = "parser",
)

odin_http_repository(
    name = "missing_gitlab",
    dependency_name = "missing_gitlab",
    urls = ["https://gitlab.com/api/v4/projects/acme%2Fparser/repository/archive.tar.gz"],
    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    auth = "gitlab_bearer",
    package_path = "parser",
)

odin_http_repository(
    name = "basic_missing_login",
    dependency_name = "basic_missing_login",
    urls = ["https://packages.example.com/parser.tar.gz"],
    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    auth = "netrc_basic",
    package_path = "parser",
)

odin_http_repository(
    name = "default_entry",
    dependency_name = "default_entry",
    urls = ["https://packages.example.com/parser.tar.gz"],
    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    auth = "netrc_basic",
    package_path = "parser",
)

EOF
touch "$test_root/BUILD.bazel"

github_root="$test_root/provider_github"
gitlab_root="$test_root/provider_gitlab"
duplicate_root="$test_root/provider_duplicate"
mkdir "$github_root" "$gitlab_root" "$duplicate_root"

cat >"$github_root/MODULE.bazel" <<EOF
module(name = "rules_odin_private_github_provider_failure")
bazel_dep(name = "rules_odin", version = "0.2.0")
local_path_override(module_name = "rules_odin", path = "$repo_root")
odin_deps = use_extension("@rules_odin//odin:deps_extensions.bzl", "odin_deps")
odin_deps.github(
    name = "missing_provider_github",
    private = True,
    repository = "acme/parser",
    tag = "v1.0.0",
)
use_repo(odin_deps, "missing_provider_github")
EOF
touch "$github_root/BUILD.bazel"

cat >"$gitlab_root/MODULE.bazel" <<EOF
module(name = "rules_odin_private_gitlab_provider_failure")
bazel_dep(name = "rules_odin", version = "0.2.0")
local_path_override(module_name = "rules_odin", path = "$repo_root")
odin_deps = use_extension("@rules_odin//odin:deps_extensions.bzl", "odin_deps")
odin_deps.gitlab(
    name = "missing_provider_gitlab",
    commit = "0000000000000000000000000000000000000000",
    private = True,
    repository = "acme/parser",
)
use_repo(odin_deps, "missing_provider_gitlab")
EOF
touch "$gitlab_root/BUILD.bazel"

cat >"$duplicate_root/MODULE.bazel" <<EOF
module(name = "rules_odin_duplicate_provider_failure")
bazel_dep(name = "rules_odin", version = "0.2.0")
local_path_override(module_name = "rules_odin", path = "$repo_root")
odin_deps = use_extension("@rules_odin//odin:deps_extensions.bzl", "odin_deps")
odin_deps.github(
    name = "duplicate_provider",
    commit = "0000000000000000000000000000000000000000",
    private = True,
    repository = "acme/parser",
)
odin_deps.gitlab(
    name = "duplicate_provider",
    commit = "0000000000000000000000000000000000000000",
    private = True,
    repository = "acme/parser",
)
use_repo(odin_deps, "duplicate_provider")
EOF
touch "$duplicate_root/BUILD.bazel"

check_failure() {
    repository=$1
    netrc_file=$2
    expected=$3
    query_root=${4:-$test_root}

    if (cd "$query_root" && NETRC="$netrc_file" bazel --batch query "@$repository//:$repository") >"$log_file" 2>&1; then
        echo "expected @$repository to reject its credential configuration" >&2
        exit 1
    fi
    if ! grep -Fq "$expected" "$log_file"; then
        echo "@$repository did not report the expected authentication boundary" >&2
        sed -n '1,120p' "$log_file" >&2
        exit 1
    fi
    if grep -Fq "RULES_ODIN_HTTP_SECRET_MARKER" "$log_file"; then
        echo "@$repository leaked the fixture credential marker" >&2
        exit 1
    fi
}

check_failure missing_github "$empty_netrc" "no password for host 'api.github.com'"
check_failure missing_gitlab "$empty_netrc" "no password for host 'gitlab.com'"
check_failure basic_missing_login "$basic_netrc" "netrc_basic requires a login"
check_failure default_entry "$default_netrc" "rejects a default .netrc entry"
check_failure missing_provider_github "$empty_netrc" "no password for host 'api.github.com'" "$github_root"
check_failure missing_provider_github "$default_netrc" "rejects a default .netrc entry" "$github_root"
check_failure missing_provider_gitlab "$empty_netrc" "no password for host 'gitlab.com'" "$gitlab_root"
check_failure duplicate_provider "$empty_netrc" "attribute 'name' is declared more than once" "$duplicate_root"
