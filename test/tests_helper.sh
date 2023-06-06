#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/helper"

setUp() {
  VERBOSE=1
}

tearDown() {
  unset VERBOSE
}

test_check_locale() {
  OLD_LANG="${LANG}"
  export LANG="en_US.UTF-8"

  output=$(check_locale 2>&1)
  assertTrue $?
  assertContains "${output}" "Found LANG=${LANG} set to UTF-8 locale."

  export LANG="${OLD_LANG}"
}

test_check_locale_unset() {
  OLD_LANG="${LANG}"
  unset LANG

  output=$(check_locale 2>&1)
  assertFalse $?7
  assertContains "${output}" "LANG is not set!"
  assertContains "${output}" "Going on with LANG=$(locale -s -U 2>/dev/null || echo "en_US.UTF-8") ..."

  export LANG="${OLD_LANG}"
}

test_check_locale_utf8() {
  OLD_LANG="${LANG}"
  export LANG="POSIX"

  output=$(check_locale 2>&1)
  assertFalse $?
  assertContains "${output}" "non-UTF locale"
  assertContains "${output}" "Going on with LANG=$(locale -s -U 2>/dev/null || echo "en_US.UTF-8") ..."

  export LANG="${OLD_LANG}"
}

test_check_placeholder() {
  VAR_WITHOUT_PLACEHOLDER="some\ncontent\nmore content"
  VAR_WITH_PLACEHOLDER="some\ncontent\n<placeholder>\nmore content"

  output=$(check_placeholder "VAR_WITHOUT_PLACEHOLDER" 2>&1)
  assertTrue $?
  assertEquals "" "${output}"

  output=$(check_placeholder "VAR_WITH_PLACEHOLDER" 2>&1)
  assertFalse $?
  assertContains "${output}" "Variable 'VAR_WITH_PLACEHOLDER' contains placeholder"
  assertContains "${output}" "Remove placeholders from gen-pack settings!"
}

. "$(dirname "$0")/shunit2/shunit2"
