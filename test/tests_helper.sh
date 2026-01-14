#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2026 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

# shellcheck disable=SC2317,SC2329

shopt -s expand_aliases

. "$(dirname "$0")/../lib/patches"
. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/helper"
. "$(dirname "$0")/helper"

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

test_split_and_trim() {
  MULTILINE_VAR="
    some text
    **/glob/pattern.txt
    path/to/fileName.dat
  "

  split_and_trim RESULT_ARRAY "${MULTILINE_VAR}"
  assertEquals 3 "${#RESULT_ARRAY[@]}"
  assertEquals "some text"             "${RESULT_ARRAY[0]}"
  assertEquals "**/glob/pattern.txt"   "${RESULT_ARRAY[1]}"
  assertEquals "path/to/fileName.dat"  "${RESULT_ARRAY[2]}"
}

test_is_subpath_of() {
  output=$(is_subpath_of "/base/dir" "/base/dir/sub/dir/file.txt")
  assertTrue $?

  output=$(is_subpath_of "/base/dir" "/base/dir/file.txt")
  assertTrue $?

  output=$(is_subpath_of "/base/dir" "/base/dir/../file.txt")
  assertFalse $?

  output=$(is_subpath_of "/base/dir" "/base/otherdir/file.txt")
  assertFalse $?

  output=$(is_subpath_of "/base/dir" "/other/base/dir/file.txt")
  assertFalse $?
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

test_detect_eol_style() {
  printf "This file has no line endings." > none_style.txt
  printf "This file\nuses Unix-style\nLF line endings." > unix_style.txt
  printf "This file\twith tabs\nuses Unix-style\nLF line endings." > unix_style_with_tabs.txt
  printf "This file\r\nuses Windows-style\r\nCRLF line endings." > windows_style.txt
  printf "This file\ruses classic Mac-style\rCR line endings." > mac_style.txt

  assertEquals "LF"   "$(detect_eol_style "none_style.txt")"
  assertEquals "LF"   "$(detect_eol_style "unix_style.txt")"
  assertEquals "LF"   "$(detect_eol_style "unix_style_with_tabs.txt")"
  assertEquals "CRLF" "$(detect_eol_style "windows_style.txt")"
  assertEquals "CR"   "$(detect_eol_style "mac_style.txt")"
}

test_convert_eol() {
  declare -g -A UTILITY_EOL_CONVERTER=()

  UTILITY_EOL_CONVERTER["CRLF-to-LF"]="$(which dos2unix)"
  UTILITY_EOL_CONVERTER["CR-to-LF"]="$(which mac2unix)"

  printf "This file\nuses Unix-style\nLF line endings." > unix_style.txt
  printf "This file\r\nuses Windows-style\r\nCRLF line endings." > windows_style.txt
  printf "This file\ruses classic Mac-style\rCR line endings." > mac_style.txt

  convert_eol "LF" unix_style.txt windows_style.txt mac_style.txt

  assertEquals "LF" "$(detect_eol_style "unix_style.txt")"
  assertEquals "LF" "$(detect_eol_style "windows_style.txt")"
  assertEquals "LF" "$(detect_eol_style "mac_style.txt")"

  local output
  output=$(convert_eol "CRLF" windows_style.txt 2>&1)
  assertContains "${output}" "No eol converter for LF-to-CRLF"

  unset UTILITY_EOL_CONVERTER
}

test_init_pack_cache() {
    local pack_index
    pack_index=$(cat <<EOF
  <pdsc url="https://www.keil.com/pack/ARM.CMSIS.pdsc" vendor="ARM" name="CMSIS" version="1.0.0"/>
  <pdsc url="file://localhost/$(cwd)/local_repo/" vendor="Vendor" name="DFP" version="1.0.0"/>
EOF
  )

  init_pack_cache "path/to/packs" "${pack_index}"

  assertTrue "[ -f path/to/packs/.Web/index.pidx ]"
  assertTrue "[ -f path/to/packs/.Local/local_repository.pidx ]"

  local web_index local_index
  web_index=$(cat path/to/packs/.Web/index.pidx)
  local_index=$(cat path/to/packs/.Local/local_repository.pidx)

  assertContains "${web_index}" "https://www.keil.com/pack/ARM.CMSIS.pdsc"
  assertNotContains "${web_index}" "file://"
  assertContains "${local_index}" "file://localhost/$(cwd)/local_repo/" 
  assertNotContains "${local_index}" "https://"
}

test_init_pack_cache_only_web() {
    local pack_index
    pack_index=$(cat <<EOF
  <pdsc url="https://www.keil.com/pack/ARM.CMSIS.pdsc" vendor="ARM" name="CMSIS" version="1.0.0"/>
EOF
  )

  init_pack_cache "path/to/packs" "${pack_index}"

  assertTrue "[ -f path/to/packs/.Web/index.pidx ]"
  assertFalse "[ -f path/to/packs/.Local/local_repository.pidx ]"

  local web_index
  web_index=$(cat path/to/packs/.Web/index.pidx)

  assertContains "${web_index}" "https://www.keil.com/pack/ARM.CMSIS.pdsc" 
}

. "$(dirname "$0")/shunit2/shunit2"
