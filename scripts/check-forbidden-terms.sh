#!/usr/bin/env bash
# Fails if any tracked file mentions a forbidden term.
#
# Use it when this blueprint moves between organisations: set FORBIDDEN_TERMS
# to the previous owner's identifiers (company and product names, account and
# project IDs, domains) as one case-insensitive extended regex, e.g.
#
#   FORBIDDEN_TERMS='oldco|oldproduct|123456789012|oldco\.com' scripts/check-forbidden-terms.sh
#
# The terms come from the environment (a GitHub repository variable in CI) so
# they never have to be written into the repository they are kept out of.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -z "${FORBIDDEN_TERMS:-}" ]; then
  echo "FORBIDDEN_TERMS is not set; nothing to check."
  exit 0
fi

if git ls-files -z | xargs -0 grep -n -i -E -I -- "$FORBIDDEN_TERMS"; then
  echo
  echo "Forbidden terms found (see above)."
  exit 1
fi

echo "No forbidden terms in $(git ls-files | wc -l | tr -d ' ') tracked files."
