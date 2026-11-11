#!/usr/bin/env bash
# Regenerates the inputs/outputs tables in every module README that has
# terraform-docs markers (<!-- BEGIN_TF_DOCS --> / <!-- END_TF_DOCS -->).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

grep -rl --include=README.md 'BEGIN_TF_DOCS' modules | while read -r readme; do
  terraform-docs --config .terraform-docs.yml "$(dirname "$readme")"
done
