#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2026 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

DIRNAME="$(realpath "$(dirname "$0")")"

result=0
passed=0
failed=0
suite_results=()

for test in "${DIRNAME}"/tests_*.sh; do
  [[ -f "${test}" ]] || continue

  echo "$test"
  if "$test"; then
    passed=$((passed + 1))
    suite_results+=("PASS  ${test##*/}")
  else
    result=$?
    failed=$((failed + 1))
    suite_results+=("FAIL  ${test##*/} (exit ${result})")
  fi
  echo ""
done

printf '\nTest summary\n'
printf '  %s\n' "${suite_results[@]}"
printf 'Suites: %d passed, %d failed, %d total\n' "${passed}" "${failed}" "$((passed + failed))"

if [[ ${result} == 0 ]]; then
  echo "Overall result: PASS"
else
  printf 'Overall result: FAIL (exit %d)\n' "${result}"
fi

exit "${result}"
