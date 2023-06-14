#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")/../lib/patches"
. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/utilities"

ffind() {
  if [[ "$(uname)" == "Darwin"  ]]; then
    args=()
    while [[ $# -gt 0 ]]; do
      arg=($1)
      case "${arg[@]}" in
        "-executable")
          arg=("-perm" "+111")
        ;;
      esac
      args+=("${arg[@]}") # save it in an array for later
      unset arg
      shift # past argument
    done
    find "${args[@]}"
    unset args
  else
    find "$@"
  fi
}

setUp() {
  VERBOSE=1
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit

  OLD_PATH="$PATH"
  OLD_HOME="${HOME}"
  OLD_LOCALAPPDATA="${LOCALAPPDATA}"

  PATH="$(cwd):$PATH"
  HOME="$(cwd)"
  LOCALAPPDATA="$(cwd)"

  unset CMSIS_PACK_ROOT
}

tearDown() {
  PATH="${OLD_PATH}"
  HOME="${OLD_HOME}"
  LOCALAPPDATA="${OLD_LOCALAPPDATA}"
}

remove_path() {
  local OFS=$IFS
  IFS=':'
  local path=()
  for p in $PATH; do
    if [[ ! "$p" == $1 ]]; then
      path+=($p)
    fi
  done
  PATH="${path[*]}"
  IFS=$OFS
}

add_path() {
  PATH="$1:$PATH"
}

remove_from_path() {
  # Remove all command executables from PATH
  while type -p "$1" 1>/dev/null 2>&1; do
    local path="$(dirname $(type -p "$1"))"
    #echo "Un'PATH'ing ${path}..." >&2
    if [[ "${path}" == "/bin" || "${path}" == "/usr/bin" ]] ; then
      local lpath="$(cwd)${path}"
      if [[ ! -d "${lpath}" ]]; then
        #echo "  Relocating ${path} to ${lpath}..." >&2
        mkdir -p "${lpath}"
        ffind "${path}" -executable -exec ln -s {} "${lpath}" \;
        add_path "${lpath}"
      fi
      remove_path "${path}"
    elif [[ "${path}" == "$(cwd)/bin" || "${path}" == "$(cwd)/usr/bin" ]] ; then
      #echo "  Removing $1 from ${path}..." >&2
      rm "${path}/$1"
    else
      remove_path "${path}"
    fi
  done
}

test_get_os_type() {
  local OS_TYPE=$(get_os_type)
  local OS=$(uname -s)
  case $OS in
    'Linux')
      assertEquals $OS_TYPE "Linux64"
      ;;
    'WindowsNT'|MINGW*|CYGWIN*)
      assertEquals $OS_TYPE "Win32"
      ;;
    'Darwin')
      assertEquals $OS_TYPE "Darwin64"
      ;;
  esac
}

test_find_pack_root_by_env() {
  CMSIS_PACK_ROOT="$(cwd)/.packs"
  mkdir -p "${CMSIS_PACK_ROOT}"

  find_pack_root

  assertEquals "${CMSIS_PACK_ROOT}" "$(cwd)/.packs"
}

test_find_pack_root_by_default() {
  case $(uname -s) in
    'Linux'|'Darwin')
      local DEFAULT_CMSIS_PACK_ROOT="${HOME}/.cache/arm/packs"
      ;;
    'WindowsNT'|MINGW*|CYGWIN*)
      local DEFAULT_CMSIS_PACK_ROOT="${LOCALAPPDATA//\\//}/Arm/Packs"
      ;;
    *)
      echo "Error: unrecognized OS $OS"
      exit 1
      ;;
  esac

  mkdir -p "${DEFAULT_CMSIS_PACK_ROOT}"

  find_pack_root

  assertEquals "${DEFAULT_CMSIS_PACK_ROOT}" "${CMSIS_PACK_ROOT}"
}

test_find_packchk_by_env() {
  cat > packchk <<EOF
#!/bin/sh
echo "packchk \$*"
EOF
  chmod +x packchk

  find_packchk

  assertEquals "$(cwd)/packchk" "${UTILITY_PACKCHK}"
}

test_find_packchk_by_pack() {
  CMSIS_PACK_ROOT="$(cwd)/.arm/Packs"
  local toolsdir="${CMSIS_PACK_ROOT}/ARM/CMSIS/5.9.0/CMSIS/Utilities/$(get_os_type)"

  mkdir -p "${toolsdir}"

  cat > "${toolsdir}/packchk" <<EOF
#!/bin/sh
echo "packchk \$*"
EOF
  chmod +x "${toolsdir}/packchk"

  remove_from_path "packchk"

  find_packchk

  assertEquals "${toolsdir}/packchk" "${UTILITY_PACKCHK}"
}

test_find_zip_7zip_env() {
  remove_from_path "7z"
  remove_from_path "zip"

  cat > "7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "7z"

  find_zip

  assertEquals "$(cwd)/7z" "${UTILITY_ZIP}"
  assertEquals "7zip" "${UTILITY_ZIP_TYPE}"
}

test_find_zip_7zip_default() {
  remove_from_path "7z"
  remove_from_path "zip"

  local programfiles="$(cwd)/Program Files"
  local zipdir="${programfiles}/7-Zip"
  PROGRAMFILES="$(sed -e 's~^/\([cd]\)/~\U\1:/~g' -e 's~/~\\~g' <<<${programfiles})"
  mkdir -p "${zipdir}"

  cat > "${zipdir}/7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "${zipdir}/7z"

  find_zip

  assertEquals "${zipdir}/7z" "${UTILITY_ZIP}"
  assertEquals "7zip" "${UTILITY_ZIP_TYPE}"
}

test_find_zip_gnuzip_env() {
  remove_from_path "7z"
  remove_from_path "zip"
  remove_from_path "unzip"
  PROGRAMFILES=""

  cat > "zip" <<EOF
#!/bin/sh
echo "zip \$*"
EOF
  chmod +x "zip"

  cat > "unzip" <<EOF
#!/bin/sh
echo "unzip \$*"
EOF
  chmod +x "unzip"

  find_zip

  assertEquals "$(cwd)/zip" "${UTILITY_ZIP}"
  assertEquals "$(cwd)/unzip" "${UTILITY_UNZIP}"
  assertEquals "zip" "${UTILITY_ZIP_TYPE}"
}

test_archive_7zip() {
  UTILITY_ZIP_TYPE="7zip"
  UTILITY_ZIP="$(cwd)/7z"

  cat > "7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "7z"

  mkdir "input"

  output=$(archive "$(cwd)/input" "$(cwd)/output/test.zip" 2>&1)

  assertContains "$output" "$(cwd)/input"
  assertContains "$output" "7z a -tzip $(cwd)/output/test.zip"
}

test_unarchive_7zip() {
  UTILITY_ZIP_TYPE="7zip"
  UTILITY_ZIP="$(cwd)/7z"

  cat > "7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "7z"

  output=$(unarchive "$(cwd)/input/test.zip" "$(cwd)/output"  2>&1)

  assertContains "$output" "$(cwd)/output"
  assertContains "$output" "7z x $(cwd)/input/test.zip"
}

test_archive_gnuzip() {
  UTILITY_ZIP_TYPE="zip"
  UTILITY_ZIP="$(cwd)/zip"

  cat > "zip" <<EOF
#!/bin/sh
echo "zip \$*"
EOF
  chmod +x "zip"

  mkdir "input"

  output=$(archive "$(cwd)/input" "$(cwd)/output/test.zip" 2>&1)

  assertContains "$output" "$(cwd)/input"
  assertContains "$output" "zip -r $(cwd)/output/test.zip"
}

test_unarchive_gnuzip() {
  UTILITY_ZIP_TYPE="zip"
  UTILITY_UNZIP="$(cwd)/unzip"

  cat > "unzip" <<EOF
#!/bin/sh
echo "unzip \$*"
EOF
  chmod +x "unzip"

  output=$(unarchive "$(cwd)/input/test.zip" "$(cwd)/output"  2>&1)

  assertContains "$output" "$(cwd)/output"
  assertContains "$output" "unzip $(cwd)/input/test.zip"
}

test_integ_archive_7zip() {
  remove_from_path "zip"

  if $(find_zip 1>/dev/null 2>&1); then
    find_zip

    mkdir -p input
  cat > "input/file.txt" <<EOF
Some test content for archive.
EOF

    archive "$(cwd)/input" "$(cwd)/archive.zip"
    assertTrue "test -f archive.zip"

    unarchive "$(cwd)/archive.zip" "$(cwd)/output"
    assertTrue "test -f output/file.txt"
    assertTrue "diff input/file.txt output/file.txt"
  else
    echo "7zip not available, skip integration test."
  fi
}

test_integ_archive_gnuzip() {
  PROGRAMFILES=""
  remove_from_path "7z"

  if $(find_zip 1>/dev/null 2>&1); then
    find_zip

    mkdir -p input
  cat > "input/file.txt" <<EOF
Some test content for archive.
EOF

    archive "$(cwd)/input" "$(cwd)/archive.zip"
    assertTrue "test -f archive.zip"

    unarchive "$(cwd)/archive.zip" "$(cwd)/output"
    assertTrue "test -f output/file.txt"
    assertTrue "diff input/file.txt output/file.txt"
  else
    echo "zip not available, skip integration test."
  fi
}

linkchecker_mock() {
  LINKCHECKER_MOCK_ARGS=($*)
}

test_check_links() {
  touch "index.html"
  mkdir "src"
  cat > "src/index.txt" <<EOF
<a href="https://url.to/file">file</a>
EOF
  cat > "linkchecker-out.csv" <<EOF
# created by LinkChecker at 2022-08-31 11:38:43+002
# Get the newest version at https://linkchecker.github.io/linkchecker/
# Write comments and bugs to https://github.com/linkchecker/linkchecker/issues
urlname;parentname;base;result;warningstring;infostring;valid;url;line;column;name;dltime;size;checktime;cached;level;modified
https://url.to/file;index.html;;"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file";;;False;https://url.to/file;119;74;AT45DB641E;-1;-1;0.9966633319854736;0;3;
# Stopped checking at 2022-08-31 11:38:56+002 (13 seconds)
EOF

  UTILITY_LINKCHECKER="linkchecker_mock"
  check_links "index.html" "src" --timeout 10 2> results.csv

  assertContains "${LINKCHECKER_MOCK_ARGS[*]}" "index.html"
  assertContains "${LINKCHECKER_MOCK_ARGS[*]}" "--timeout 10"
  assertEquals \
    "$(realpath src/index.txt):1:9;https://url.to/file;\"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file\";URL 'https://url.to/file' results to '\"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file\"'" \
    "$(cat results.csv)"
}

test_check_links_markdown() {
  touch "index.html"
  mkdir "src"
  cat > "src/index.md" <<EOF
Follw the link to [file](https://url.to/file).
EOF
  cat > "linkchecker-out.csv" <<EOF
# created by LinkChecker at 2022-08-31 11:38:43+002
# Get the newest version at https://linkchecker.github.io/linkchecker/
# Write comments and bugs to https://github.com/linkchecker/linkchecker/issues
urlname;parentname;base;result;warningstring;infostring;valid;url;line;column;name;dltime;size;checktime;cached;level;modified
https://url.to/file;index.html;;"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file";;;False;https://url.to/file;119;74;AT45DB641E;-1;-1;0.9966633319854736;0;3;
# Stopped checking at 2022-08-31 11:38:56+002 (13 seconds)
EOF

  UTILITY_LINKCHECKER="linkchecker_mock"
  check_links "index.html" "src" --timeout 10 2> results.csv

  assertContains "${LINKCHECKER_MOCK_ARGS[*]}" "index.html"
  assertContains "${LINKCHECKER_MOCK_ARGS[*]}" "--timeout 10"
  assertEquals \
    "$(realpath src/index.md):1:25;https://url.to/file;\"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file\";URL 'https://url.to/file' results to '\"SSLError: HTTPSConnectionPool(host='url.to', port=443): Max retries exceeded with url: /file\"'" \
    "$(cat results.csv)"
}

test_find_utility() {
  mkdir util-1.0
  mkdir util-2.0

  cat > util-1.0/util <<EOF
#!/bin/sh
echo "1.0.0"
EOF

  cat > util-2.0/util <<EOF
#!/bin/sh
echo "2.0.3"
EOF

  chmod +x util-1.0/util
  chmod +x util-2.0/util

  PATH="$(cwd)/util-1.0:$(cwd)/util-2.0:$PATH"

  UTIL=$(find_utility "util")
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/util-1.0/util" "$UTIL"

  UTIL=$(find_utility "util" "-v" "1.0.0")
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/util-1.0/util" "$UTIL"

  UTIL=$(find_utility "util" "-v" "2.0.3")
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/util-2.0/util" "$UTIL"
}

test_find_utility_version_na() {
  mkdir util-1.0
  mkdir util-2.0

  cat > util-1.0/util <<EOF
#!/bin/sh
echo "1.0.0"
EOF

  cat > util-2.0/util <<EOF
#!/bin/sh
echo "2.0.3"
EOF

  chmod +x util-1.0/util
  chmod +x util-2.0/util

  PATH="$(cwd)/util-1.0:$(cwd)/util-2.0:$PATH"

  UTIL=$(find_utility "util" "-v" "3.0.0")
  assertNotEquals "find_utility did not fail" 0 $?
}

test_find_utility_na() {
  UTIL=$(find_utility "utilX")
  assertNotEquals "find_utility did not fail" 0 $?
}

test_find_utility_whitespace() {
  mkdir "util 1.0"
  mkdir "util 2.0"

  cat > "util 1.0/util" <<EOF
#!/bin/sh
echo "1.0.0"
EOF

  cat > "util 2.0/util" <<EOF
#!/bin/sh
echo "2.0.3"
EOF
  chmod +x "util 1.0/util"
  chmod +x "util 2.0/util"

  PATH="$(cwd)/util 2.0:$(cwd)/util 1.0:$PATH"

  UTIL=$(find_utility "util" "-v" "1.0.0")
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/util 1.0/util" "$UTIL"

  UTIL=$(find_utility "util" "-v" "2.0.3")
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/util 2.0/util" "$UTIL"
}

_test_find_() {
  local utility=${2:-$1}
  local utility_var="UTILITY_${utility^^}"

  mkdir bin

  cat > "bin/$1" <<EOF
#!/bin/sh
echo "$1 $@"
EOF
  chmod +x "bin/$1"

  remove_from_path "$1"
  PATH="$(cwd)/bin:$PATH"

  find_${utility}
  assertEquals 0 $?
  assertEquals "$(cwd)/bin/$1" "${!utility_var}"

  OUTPUT=$(find_${utility} 2>&1 > /dev/null)
  assertNotContains "Error" "$OUTPUT"
  assertNotContains "Warning" "$OUTPUT"
  assertNotContains "Info" "$OUTPUT"
}

test_find_ghcli() {
  _test_find_ gh ghcli
}

test_find_ghcli_unauth() {
  mkdir ghcli

  cat > ghcli/gh <<EOF
#!/bin/sh
echo "gh-mock \$*"
exit 1
EOF

  chmod +x ghcli/gh

  PATH="$(cwd)/ghcli:$PATH"

  OUTPUT=$(find_ghcli 2>&1)
  assertEquals 1 $?
  assertContains "$OUTPUT" "gh-mock auth status"
  assertContains "$OUTPUT" "Action: Run gh auth login"
}

test_find_doxygen() {
  mkdir "doxygen-1.8.6"
  mkdir "doxygen-1.9.2"

  cat > "doxygen-1.8.6/doxygen" <<EOF
#!/bin/sh
echo "1.8.6"
EOF

  cat > "doxygen-1.9.2/doxygen" <<EOF
#!/bin/sh
echo "1.9.2 (caa4e3de211fbbef2c3adf58a6bd4c86d0eb7cb8)"
EOF
  chmod +x "doxygen-1.8.6/doxygen"
  chmod +x "doxygen-1.9.2/doxygen"

  PATH="$(cwd)/doxygen-1.8.6:$(cwd)/doxygen-1.9.2:$PATH"

  find_doxygen "1.8.6"
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/doxygen-1.8.6/doxygen" "$UTILITY_DOXYGEN"

  find_doxygen "1.9.2"
  assertEquals 0 $?
  assertEquals "$(realpath $(cwd))/doxygen-1.9.2/doxygen" "$UTILITY_DOXYGEN"
}

test_find_doxygen_version() {
  mkdir "doxygen-1.8.6"
  mkdir "doxygen-1.9.2"

  cat > "doxygen-1.8.6/doxygen" <<EOF
#!/bin/sh
echo "1.8.6"
EOF

  cat > "doxygen-1.9.2/doxygen" <<EOF
#!/bin/sh
echo "1.9.2 (caa4e3de211fbbef2c3adf58a6bd4c86d0eb7cb8)"
EOF

  chmod +x "doxygen-1.8.6/doxygen"
  chmod +x "doxygen-1.9.2/doxygen"

  remove_from_path "doxygen"
  PATH="$(cwd)/doxygen-1.8.6:$(cwd)/doxygen-1.9.2:$PATH"

  OUTPUT=$(find_doxygen "1.9.6" 2>&1)
  assertFalse $?
  assertContains "$OUTPUT" "Error: No doxygen utility found with version 1.9.6"
  assertContains "$OUTPUT" "Action: Add doxygen version 1.9.6 to your PATH" 
}

test_find_xmllint() {
  _test_find_ xmllint
}

test_find_sha1sum() {
  _test_find_ sha1sum
}

test_find_linkchecker() {
  _test_find_ linkchecker
}

. "$(dirname "$0")/shunit2/shunit2"
