#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

# shellcheck disable=SC2317

shopt -s expand_aliases

. "$(dirname "$0")/../lib/patches"
. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/helper"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}/pack"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit

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
  # shellcheck disable=SC2034
  VAR_WITHOUT_PLACEHOLDER="some\ncontent\nmore content"
  # shellcheck disable=SC2034
  VAR_WITH_PLACEHOLDER="some\ncontent\n<placeholder>\nmore content"

  output=$(check_placeholder "VAR_WITHOUT_PLACEHOLDER" 2>&1)
  assertTrue $?
  assertEquals "" "${output}"

  output=$(check_placeholder "VAR_WITH_PLACEHOLDER" 2>&1)
  assertFalse $?
  assertContains "${output}" "Variable 'VAR_WITH_PLACEHOLDER' contains placeholder"
  assertContains "${output}" "Remove placeholders from gen-pack settings!"
}

test_is_url() {
  output=$(is_url "http://url.to/file")
  assertTrue $?

  output=$(is_url "https://url.to/file")
  assertTrue $?

  output=$(is_url "file://path.to/file")
  assertFalse $?

  output=$(is_url "/path/to/file")
  assertFalse $?

  output=$(is_url "file")
  assertFalse $?
}

test_is_file_uri() {
  output=$(is_file_uri "file://path.to/file")
  assertTrue $?

  output=$(is_file_uri "http://url.to/file")
  assertFalse $?

  output=$(is_file_uri "/path/to/file")
  assertFalse $?

  output=$(is_file_uri "file")
  assertFalse $?
}

test_has_write_protect() {
  mkdir protected
  chmod a-w protected

  assertEquals "no" "$(has_write_protect ".")"
  assertEquals "no" "$(has_write_protect "nonexistent/path/to/file")"

  if get_perms "."; then
    assertEquals "yes" "$(has_write_protect "protected")"
    assertEquals "yes" "$(has_write_protect "protected/nonexistent/path/to/file")"
  fi

  chmod -R a+w protected
}

. "$(dirname "$0")/shunit2/shunit2"
