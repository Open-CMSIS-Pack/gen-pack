#!/bin/bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/gittools"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null
}

tearDown() {
  unset GIT_MOCK_DESCRIBE
  unset GIT_MOCK_REVPARSE
  unset GIT_MOCK_REVLIST
  PACK_CHANGELOG_MODE="full"
}

git_mock() {
  echo "git $*" >&2

  case $1 in
    'rev-parse')
      return ${GIT_MOCK_REVPARSE-0}
      ;;
    'describe')
      if [ -n "${GIT_MOCK_DESCRIBE+x}" ]; then
        echo "${GIT_MOCK_DESCRIBE}"
        return 0
      elif [[ " $* " =~ " --always " ]]; then
        echo "1abcdef"
        return 0
      else
        return 1
      fi
      ;;
    'for-each-ref')
      if [[ " $* " =~ " --format %(refname)" ]]; then
        echo "refs/tags/v1.5.0"
        echo "refs/tags/v1.2.4"
        echo "refs/tags/v1.2.3"
        echo "refs/tags/v0.9.0"
        echo "refs/tags/v0.0.1"
        return 0
      elif  [[ " $* " =~ " --format %(objecttype)" ]]; then
        case "${@: -1}" in
          "refs/tags/v1.5.0"|"refs/tags/v1.2.4"|"refs/tags/v1.2.3")
            echo "tag"
          ;;
          *)
            echo "commit"
          ;;
        esac
        return 0
      fi
      ;;
    'rev-list')
      return ${GIT_MOCK_REVLIST-1}
      ;;
    'tag')
      if [[ " $* " =~ " %(contents) " ]]; then
        case "${@: -1}" in
          "v1.5.0"|"v1.2.4"|"v1.2.3")
            echo "Change log text for release version ${@: -1}"
          ;;
          *)
            echo "Commit message for ${@: -1}"
          ;;
        esac
        return 0
      elif [[ " $* " =~ " %(taggerdate:short) " ]]; then
        case "${@: -1}" in
          "v1.5.0")
            echo "2022-08-03"
          ;;
          "v1.2.4")
            echo "2022-06-27"
          ;;
          "v1.2.3")
            echo "2022-06-15"
          ;;
          *)
            return 1
          ;;
        esac
        return 0
      elif [[ " $* " =~ " %(committerdate:short) " ]]; then
        echo "2021-07-29"
        return 0
      fi
      ;;
  esac

  echo "Error: unrecognized git command '$1'" >&2
  return 1
}

ghcli_mock() {
  echo "gh $*" >&2

  if [ $1 = "release" ] && [ $2 = "view" ]; then
    if [ $3 == "v0.0.1" ]; then
      return 1
    fi

    if [[ " $* " =~ " --json body " ]]; then
      echo "Release description for version $3"
    elif [[ " $* " =~ " --json publishedAt " ]]; then
      echo "2021-07-29"
    fi
    return 0
  fi

  echo "Error: unrecognized gh command '$1'" >&2
  return 1
}

test_git_describe() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.2.3-0-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.3" "${version}"

  GIT_MOCK_DESCRIBE="v1.2.3-dev1-0-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.3-dev1" "${version}"

  GIT_MOCK_DESCRIBE="v1.2.3-3-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.4-dev3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-3-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2.3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-0-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-dev-3-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-dev3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="v1.1.0-preview1-67-g895850a"
  local version=$(git_describe "v" 2>/dev/null)
  assertEquals "1.1.0-preview1.67+g895850a" "${version}"

  unset GIT_MOCK_DESCRIBE
  local version=$(git_describe 2>/dev/null)
  assertEquals "0.0.0-dirty1+g1abcdef" "${version}"

  GIT_MOCK_REVPARSE=1
  local version=$(git_describe 2>/dev/null)
  assertEquals "0.0.0-nogit" "${version}"
}

test_git_changelog_pdsc() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"

  changelog=$(git_changelog -f pdsc -d -p v)

  read -r -d '' expected <<EOF
<releases>
  <release version="1.5.1-dev3+g1abcdef">
    Active development ...
  </release>
  <release version="1.5.0" date="2022-08-03" tag="v1.5.0">
    Change log text for release version v1.5.0
  </release>
  <release version="1.2.4" date="2022-06-27" tag="v1.2.4">
    Change log text for release version v1.2.4
  </release>
  <release version="1.2.3" date="2022-06-15" tag="v1.2.3">
    Change log text for release version v1.2.3
  </release>
  <release version="0.9.0" date="2021-07-29" tag="v0.9.0">
    Release description for version v0.9.0
  </release>
  <release version="0.0.1" date="2021-07-29" tag="v0.0.1">
    Commit message for v0.0.1
  </release>
</releases>
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_with_empty_devlog() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"

  changelog=$(git_changelog -f pdsc -d "" -p v)

  read -r -d '' expected <<EOF
<releases>
  <release version="1.5.1-dev3+g1abcdef">
    Active development ...
  </release>
  <release version="1.5.0" date="2022-08-03" tag="v1.5.0">
    Change log text for release version v1.5.0
  </release>
  <release version="1.2.4" date="2022-06-27" tag="v1.2.4">
    Change log text for release version v1.2.4
  </release>
  <release version="1.2.3" date="2022-06-15" tag="v1.2.3">
    Change log text for release version v1.2.3
  </release>
  <release version="0.9.0" date="2021-07-29" tag="v0.9.0">
    Release description for version v0.9.0
  </release>
  <release version="0.0.1" date="2021-07-29" tag="v0.0.1">
    Commit message for v0.0.1
  </release>
</releases>
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_with_devlog() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"

  changelog=$(git_changelog -f pdsc -d "Custom dev log" -p v)

  read -r -d '' expected <<EOF
<releases>
  <release version="1.5.1-dev3+g1abcdef">
    Custom dev log
  </release>
  <release version="1.5.0" date="2022-08-03" tag="v1.5.0">
    Change log text for release version v1.5.0
  </release>
  <release version="1.2.4" date="2022-06-27" tag="v1.2.4">
    Change log text for release version v1.2.4
  </release>
  <release version="1.2.3" date="2022-06-15" tag="v1.2.3">
    Change log text for release version v1.2.3
  </release>
  <release version="0.9.0" date="2021-07-29" tag="v0.9.0">
    Release description for version v0.9.0
  </release>
  <release version="0.0.1" date="2021-07-29" tag="v0.0.1">
    Commit message for v0.0.1
  </release>
</releases>
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_html() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"

  changelog=$(git_changelog -f html -p v)

  read -r -d '' expected <<EOF
/**
\page rev_hist Revision History
<table class="cmtable" summary="Revision History">
<tr>
  <th>Version</th>
  <th>Description</th>
</tr>
<tr>
  <td>v1.5.0</td>
  <td>
    Change log text for release version v1.5.0
  </td>
</tr>
<tr>
  <td>v1.2.4</td>
  <td>
    Change log text for release version v1.2.4
  </td>
</tr>
<tr>
  <td>v1.2.3</td>
  <td>
    Change log text for release version v1.2.3
  </td>
</tr>
<tr>
  <td>v0.9.0</td>
  <td>
    Release description for version v0.9.0
  </td>
</tr>
<tr>
  <td>v0.0.1</td>
  <td>
    Commit message for v0.0.1
  </td>
</tr>
</table>
*/
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_fail_tag() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  PACK_CHANGELOG_MODE="tag"

  changelog=$(git_changelog -f text -p v 2>&1)
  assertNotEquals 0 $?

  echo "$changelog"
  assertContains "${changelog}"  "Changelog generation for tag 'v0.9.0' failed!"
}

test_git_changelog_fail_release() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  PACK_CHANGELOG_MODE="release"

  changelog=$(git_changelog -f text -p v 2>&1)
  assertNotEquals 0 $?

  echo "$changelog"
  assertContains "${changelog}"  "Changelog generation for tag 'v0.0.1' failed!"
}

. "$(dirname "$0")/shunit2/shunit2"
