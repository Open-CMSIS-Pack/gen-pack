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
skipped=0
suite_results=()

for test in "${DIRNAME}"/tests_*.sh; do
  [[ -f "${test}" ]] || continue

  if [[ ${test##*/} == *_integ* ]]; then
    skipped=$((skipped + 1))
    suite_results+=("SKIP  ${test##*/} (integration suite)")
    continue
  fi

  echo "$test"
  if mkdir -p "${DIRNAME}/cov/$(basename "${test/.sh}")" &&
    kcov --strip-path="$(realpath "${DIRNAME}/../..")" --include-pattern=gen-pack/gen-pack,gen-pack/lib/ --exclude-pattern=gen-pack/template/,gen-pack/test/,gen-pack/README.md,gen-pack/LICENSE,gen-pack/codecov.yml "${DIRNAME}/cov/$(basename "${test/.sh}")" "${test}"; then
    passed=$((passed + 1))
    suite_results+=("PASS  ${test##*/}")
  else
    result=$?
    failed=$((failed + 1))
    suite_results+=("FAIL  ${test##*/} (exit ${result})")
  fi
  echo ""
done

merge_result=0
kcov --merge "${DIRNAME}/cov/all" --include-pattern=gen-pack/gen-pack,gen-pack/lib/ --exclude-pattern=gen-pack/template/,gen-pack/test/,gen-pack/README.md,gen-pack/LICENSE,gen-pack/codecov.yml "${DIRNAME}"/cov/tests_* || merge_result=$?

printf '\nTest summary\n'
printf '  %s\n' "${suite_results[@]}"
printf 'Suites: %d passed, %d failed, %d skipped, %d total\n' "${passed}" "${failed}" "${skipped}" "$((passed + failed + skipped))"

if [[ ${merge_result} == 0 ]]; then
  echo "Coverage merge: PASS"
else
  printf 'Coverage merge: FAIL (exit %d)\n' "${merge_result}"
  if [[ ${result} == 0 ]]; then
    result=${merge_result}
  fi
fi

if [[ ${result} == 0 ]]; then
  echo "Overall result: PASS"
else
  printf 'Overall result: FAIL (exit %d)\n' "${result}"
fi

exit "${result}"
