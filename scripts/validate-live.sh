#!/usr/bin/env bash
# Validates every Terragrunt unit end to end -- generated provider, module
# source and inputs -- without touching any cloud: no backend, dependency
# outputs replaced by each dependency block's mock_outputs.
#
#   scripts/validate-live.sh            # all of live/
#   scripts/validate-live.sh live/gcp   # one subtree
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
dir="${1:-live}"

export TG_TF_PATH="${TG_TF_PATH:-terraform}" TG_NO_TIPS=true TG_NON_INTERACTIVE=true
# Units are initialised in parallel. Terraform's own plugin cache is not safe for
# concurrent writers, so let Terragrunt's provider cache download each provider once.
export TG_PROVIDER_CACHE=true
common=(--all --no-dependency-outputs --log-level error)

terragrunt run "${common[@]}" -- init -backend=false -input=false -no-color >/dev/null
terragrunt run "${common[@]}" --no-auto-init -- validate -no-color
