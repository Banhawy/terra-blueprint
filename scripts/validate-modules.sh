#!/usr/bin/env bash
# Runs `terraform init -backend=false && terraform validate` in every module
# under modules/ (or in the directories given as arguments).
#
# Modules that declare `configuration_aliases` (e.g. aws.us_east_1) cannot be
# validated on their own: in a deployment Terragrunt generates the aliased
# provider block, so for validation a throwaway stub is dropped in and removed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ "$#" -gt 0 ]; then
  modules=("$@")
else
  modules=()
  while IFS= read -r d; do modules+=("$d"); done < <(find modules -name versions.tf -not -path '*/.terraform/*' -exec dirname {} \; | sort)
fi

stub=_validate_providers.tf
failed=0

for dir in "${modules[@]}"; do
  if grep -q 'configuration_aliases' "$dir/versions.tf" 2>/dev/null; then
    grep -o 'aws\.[a-z0-9_]*' "$dir/versions.tf" | sort -u | sed 's/^aws\.//' |
      while read -r alias; do printf 'provider "aws" {\n  alias = "%s"\n}\n' "$alias"; done >"$dir/$stub"
  fi

  if out=$(cd "$dir" && terraform init -backend=false -input=false -no-color 2>&1 >/dev/null && terraform validate -no-color 2>&1); then
    echo "ok    $dir"
  else
    echo "FAIL  $dir"
    echo "$out" | sed 's/^/      /'
    failed=1
  fi

  rm -f "$dir/$stub"
done

exit "$failed"
