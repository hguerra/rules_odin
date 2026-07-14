#!/usr/bin/env sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$workspace/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/rules_odin_git.XXXXXX")
source_repo="$test_root/source"
consumer="$test_root/consumer"
log_file="$test_root/missing-commit.log"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mkdir -p "$source_repo/src" "$consumer/app"
cp "$workspace/testdata/parser.odin" "$source_repo/src/parser.odin"

git -C "$source_repo" init --quiet
git -C "$source_repo" add src/parser.odin
GIT_AUTHOR_NAME="rules_odin fixture" \
GIT_AUTHOR_EMAIL="fixture@example.invalid" \
GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
GIT_COMMITTER_NAME="rules_odin fixture" \
GIT_COMMITTER_EMAIL="fixture@example.invalid" \
GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
    git -C "$source_repo" commit --quiet -m "fixture"
commit=$(git -C "$source_repo" rev-parse HEAD)

sed \
    -e "s|RULES_ODIN_PATH|$repo_root|g" \
    -e "s|PARSER_COMMIT|$commit|g" \
    "$workspace/template/MODULE.bazel" >"$consumer/MODULE.bazel"
cp "$workspace/template/BUILD.bazel" "$consumer/BUILD.bazel"
cp "$workspace/template/app/main.odin" "$consumer/app/main.odin"

cat >"$test_root/gitconfig" <<EOF
[url "file://$source_repo"]
    insteadOf = https://git.invalid/parser.git
EOF

run_bazel() {
    (cd "$consumer" && \
        GIT_CONFIG_GLOBAL="$test_root/gitconfig" \
        GIT_TERMINAL_PROMPT=0 \
        bazel "$@")
}

run_bazel test //...
run_bazel query @parser//:parser --output=location
run_bazel fetch //...
run_bazel test --nofetch //...

if run_bazel query @parser_bad//:parser_bad >"$log_file" 2>&1; then
    echo "expected the nonexistent Git commit to fail" >&2
    exit 1
fi
if ! grep -Eiq "commit|reference|revision|reset" "$log_file"; then
    echo "missing-commit failure did not identify Git revision resolution" >&2
    sed -n '1,120p' "$log_file" >&2
    exit 1
fi
