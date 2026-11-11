#!/usr/bin/env bash
# Runs `terraform test` in every module that has tests/*.tftest.hcl (or in the
# module directories given as arguments). Tests use mock providers: no cloud
# credentials are needed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ "$#" -gt 0 ]; then
  modules=("$@")
else
  modules=()
  while IFS= read -r d; do modules+=("$d"); done < <(find modules -name '*.tftest.hcl' -not -path '*/.terraform/*' -exec dirname {} \; | xargs -n1 dirname | sort -u)
fi

stub=_validate_providers.tf
failed=0

for dir in "${modules[@]}"; do
  # Same aliased-provider stub as validate-modules.sh (see there).
  if grep -q 'configuration_aliases' "$dir/versions.tf" 2>/dev/null; then
    grep -o 'aws\.[a-z0-9_]*' "$dir/versions.tf" | sort -u | sed 's/^aws\.//' |
      while read -r alias; do printf 'provider "aws" {\n  alias = "%s"\n}\n' "$alias"; done >"$dir/$stub"
  fi

  if out=$(cd "$dir" && terraform init -backend=false -input=false -no-color >/dev/null 2>&1 && terraform test -no-color 2>&1); then
    echo "ok    $dir  ($(echo "$out" | tail -1))"
  else
    echo "FAIL  $dir"
    echo "$out" | sed 's/^/      /'
    failed=1
  fi

  rm -f "$dir/$stub"
done

exit "$failed"
