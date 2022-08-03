#!/bin/bash

DIRNAME="$(readlink -f "$(dirname "$0")")"

result=0
for test in $(find "${DIRNAME}" -name "tests_*.sh"); do
  echo "$test"
  "$test" || result=$?
  echo ""
done

exit $result
