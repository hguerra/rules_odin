#!/usr/bin/env bash
set -euo pipefail

readonly expected_version="9.2.0"
readonly actual_version="$(tr -d '[:space:]' < .bazelversion)"

if [[ "${actual_version}" != "${expected_version}" ]]; then
  echo "rules_odin: .bazelversion must contain ${expected_version}, got ${actual_version}" >&2
  exit 1
fi

readonly contract_files=(
  .github/workflows/check.yaml
  .github/workflows/release.yaml
  COMPATIBILITY.md
  README.md
  odin/private/deps_repositories.bzl
)

for contract_file in "${contract_files[@]}"; do
  if [[ ! -f "${contract_file}" ]]; then
    echo "rules_odin: Bazel version contract file is missing: ${contract_file}" >&2
    exit 1
  fi
done

if grep -En '7\.7\.1|8\.7\.0|9\.1\.1' "${contract_files[@]}"; then
  echo "rules_odin: supported files must describe only Bazel ${expected_version}" >&2
  exit 1
fi

if grep -En 'Bazel (7\.x|8\.x)|matrix\.bazel' README.md COMPATIBILITY.md .github/workflows/check.yaml .github/workflows/release.yaml; then
  echo "rules_odin: legacy Bazel support or a version matrix was reintroduced" >&2
  exit 1
fi

readonly download_calls="$(
  grep -Ec '^[[:space:]]+ctx\.download_and_extract\(' odin/private/deps_repositories.bzl || true
)"
if [[ "${download_calls}" != "1" ]]; then
  echo "rules_odin: expected one Bazel 9.2 download_and_extract path, got ${download_calls}" >&2
  exit 1
fi

echo "rules_odin: Bazel ${expected_version} is the only supported version"
