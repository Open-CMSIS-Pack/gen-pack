#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

DIRNAME="$(realpath "$(dirname "$0")")"

result=0
for test in $(find "${DIRNAME}" -name "tests_*.sh" -maxdepth 1); do
  if [[ ! "$test" =~ .*_integ.* ]]; then
    echo "$test"
    mkdir -p "${DIRNAME}/cov/$(basename "${test/.sh}")"
    kcov --strip-path="$(realpath "${DIRNAME}/../..")" --include-pattern=gen-pack/gen-pack,gen-pack/lib/ "${DIRNAME}/cov/$(basename "${test/.sh}")" "${test}" || result=$?
    echo ""
  fi
done

kcov --merge "${DIRNAME}/cov/all" --include-pattern=gen-pack/gen-pack,gen-pack/lib/ ${DIRNAME}/cov/tests_*

exit $result
