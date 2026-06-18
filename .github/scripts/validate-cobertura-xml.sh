#!/usr/bin/env bash
#
# Validate an untrusted Cobertura XML coverage report before passing it to QLTY.
#

set -euo pipefail

cov_path="${1:?usage: validate-cobertura-xml.sh <path-to-cov.xml>}"
size_limit_bytes=$((10 * 1024 * 1024))

test -s "${cov_path}"

if [ "$(wc -c < "${cov_path}")" -gt "${size_limit_bytes}" ]; then
  echo "${cov_path} exceeds the 10 MiB size limit" >&2
  exit 1
fi

if grep -Eiq '<!ELEMENT|<!ENTITY' "${cov_path}"; then
  echo "${cov_path} contains unsupported XML declarations" >&2
  exit 1
fi

root_name=$(xmllint --nonet --xpath 'local-name(/*)' "${cov_path}")
if [ "${root_name}" != "coverage" ]; then
  echo "${cov_path} is not a Cobertura coverage report: expected root element coverage, got ${root_name}" >&2
  exit 1
fi

line_rate=$(xmllint --nonet --xpath 'string(/*/@line-rate)' "${cov_path}")
branch_rate=$(xmllint --nonet --xpath 'string(/*/@branch-rate)' "${cov_path}")
lines_covered=$(xmllint --nonet --xpath 'string(/*/@lines-covered)' "${cov_path}")
lines_valid=$(xmllint --nonet --xpath 'string(/*/@lines-valid)' "${cov_path}")

for attr_name in line_rate branch_rate lines_covered lines_valid; do
  if [ -z "${!attr_name}" ]; then
    echo "${cov_path} is missing required coverage XML attribute ${attr_name//_/-}" >&2
    exit 1
  fi
done

python3 - "${line_rate}" "${branch_rate}" "${lines_covered}" "${lines_valid}" <<'PY'
import sys

EXPECTED_ARG_COUNT = 5
if len(sys.argv) != EXPECTED_ARG_COUNT:
    raise SystemExit(f"expected 4 coverage attributes, got {len(sys.argv) - 1}")

for attr_name, value in zip(("line-rate", "branch-rate"), sys.argv[1:3]):
    try:
        rate = float(value)
    except ValueError as exc:
        raise SystemExit(f"coverage XML attribute {attr_name} must be numeric, got {value!r}") from exc
    if not 0.0 <= rate <= 1.0:
        raise SystemExit(f"coverage XML attribute {attr_name} must be between 0.0 and 1.0, got {rate}")

for attr_name, value in zip(("lines-covered", "lines-valid"), sys.argv[3:5]):
    try:
        count = int(value)
    except ValueError as exc:
        raise SystemExit(f"coverage XML attribute {attr_name} must be an integer, got {value!r}") from exc
    if count < 0:
        raise SystemExit(f"coverage XML attribute {attr_name} must be zero or greater, got {count}")
PY
