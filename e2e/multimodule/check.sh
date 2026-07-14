#!/usr/bin/env sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$workspace/../.." && pwd)
modules="libs/common apps/billing apps/identity"

expected_version=""
for module in $modules; do
    module_root="$workspace/$module"
    if [ ! -f "$module_root/MODULE.bazel" ] || [ ! -f "$module_root/MODULE.bazel.lock" ]; then
        echo "$module is missing its module declaration or lockfile" >&2
        exit 1
    fi

    version=$(sed -n 's/.*bazel_dep(name = "rules_odin", version = "\([^"]*\)").*/\1/p' "$module_root/MODULE.bazel")
    if [ -z "$version" ]; then
        echo "$module does not declare a rules_odin version" >&2
        exit 1
    fi
    if [ -z "$expected_version" ]; then
        expected_version=$version
    elif [ "$version" != "$expected_version" ]; then
        echo "$module resolves rules_odin $version instead of $expected_version" >&2
        exit 1
    fi

    (
        cd "$module_root"
        bazel mod deps
        bazel test //...
        bazel fetch //...
        bazel test --nofetch //...
    )
done

git -C "$repo_root" diff --exit-code -- \
    e2e/multimodule/apps/billing/MODULE.bazel.lock \
    e2e/multimodule/apps/identity/MODULE.bazel.lock \
    e2e/multimodule/libs/common/MODULE.bazel.lock
