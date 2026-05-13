#!/usr/bin/env bash
#
# Open-CMSIS-Pack gen-pack Bash library
#
# Copyright (c) 2022-2023 Arm Limited. All rights reserved.
#
# Provided as-is without warranty under Apache 2.0 License
# SPDX-License-Identifier: Apache-2.0
#

# shellcheck disable=SC2317,SC2329

. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/gittools"

setUp() {
  PACK_CHANGELOG_MODE="full"
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit

  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REFS=(           \
    "refs/tags/v1.5.0"      \
    "refs/tags/v1.5.0-dev"  \
    "refs/tags/v1.2.4"      \
    "refs/tags/v1.2.3"      \
    "refs/tags/v0.9.0"      \
    "refs/tags/v0.0.1"      \
  )
}

tearDown() {
  unset GIT_MOCK_DESCRIBE
  unset GIT_MOCK_REVPARSE
  unset GIT_MOCK_REVLIST  
}

git_mock() {
  echo "git $*" >&2

  while [[ $# -gt 0 ]]; do 
    case $1 in
      '-c')
        shift
        shift
        ;;
      'rev-parse')
        return "${GIT_MOCK_REVPARSE-0}"
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
        if [[ " $* " == *" --format %(refname)"* ]]; then
          printf '%s\n' "${GIT_MOCK_REFS[@]}"
          return 0
        elif [[ " $* " == *" --format %(objecttype)"* ]]; then
          case "${*: -1}" in
            refs/tags/v1.5.0*|refs/tags/v1.2.4|refs/tags/v1.2.3)
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
        shift
        while [[ $# -gt 0 ]]; do 
          case $1 in
            "-n")
              shift
              shift
            ;;
            *)
              if [ "${GIT_MOCK_REVLIST[$1]+x}" ]; then
                echo "${GIT_MOCK_REVLIST[$1]}"
                return 0
              else
                return 1
              fi
            ;;
          esac
        done
        return 1
        ;;
      'tag')
        if [[ " $* " == *" %(contents) "* ]]; then
          case "${@: -1}" in
            v1.5.0*|v1.2.4|v1.2.3)
              echo "Change log text for release version ${*: -1}"
            ;;
            *)
              echo "Commit message for ${*: -1}"
            ;;
          esac
          return 0
        elif [[ " $* " == *" %(taggerdate:short) "* ]]; then
          case "${@: -1}" in
            v1.5.0*)
              echo "2022-08-03"
            ;;
            v1.2.4)
              echo "2022-06-27"
            ;;
            v1.2.3)
              echo "2022-06-15"
            ;;
            *)
              return 1
            ;;
          esac
          return 0
        elif [[ " $* " == *" %(committerdate:short) "* ]]; then
          echo "2021-07-29"
          return 0
        fi
        ;;
    *)
      break
      ;;
    esac
  done

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

  GIT_MOCK_DESCRIBE="v1.2.3-dev1-1-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.3-dev1.1+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="v1.2.3-3-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.4-dev3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-3-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2.3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-0-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-dev-0-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-dev0+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-dev-3-g1abcdef"
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-dev3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="v1.1.0-preview1-67-g895850a"
  local version=$(git_describe "v" 2>/dev/null)
  assertEquals "1.1.0-preview1.67+g895850a" "${version}"

  GIT_MOCK_DESCRIBE="v1.1.0-preview1-0-g895850a"
  local version=$(git_describe "v" 2>/dev/null)
  assertEquals "1.1.0-preview1" "${version}"

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
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

  changelog=$(git_changelog -f pdsc -p v)

  read -r -d '' expected <<EOF
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_release() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-0-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  GIT_MOCK_REVLIST["refs/tags/v1.5.0"]="deadbeef"

  changelog=$(git_changelog -f pdsc -p v)

  read -r -d '' expected <<EOF
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_prerelease() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_REFS=(           \
    "refs/tags/v1.5.0-rc0"  \
    "refs/tags/v1.5.0-dev"  \
    "refs/tags/v1.2.4"      \
    "refs/tags/v1.2.3"      \
    "refs/tags/v0.9.0"      \
    "refs/tags/v0.0.1"      \
  )
  GIT_MOCK_DESCRIBE="v1.5.0-rc0-0-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  GIT_MOCK_REVLIST["refs/tags/v1.5.0-rc0"]="deadbeef"

  changelog=$(git_changelog -f pdsc -p v)

  read -r -d '' expected <<EOF
<release version="1.5.0-rc0" date="2022-08-03" tag="v1.5.0-rc0">
  Change log text for release version v1.5.0-rc0
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_with_default_devlog() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

  changelog=$(git_changelog -f pdsc -d -p v)

  read -r -d '' expected <<EOF
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_with_empty_devlog() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

  changelog=$(git_changelog -f pdsc -d "" -p v)

  read -r -d '' expected <<EOF
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_pdsc_with_devlog() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

  changelog=$(git_changelog -f pdsc -d "Custom dev log" -p v)

  read -r -d '' expected <<EOF
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
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_html() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef"
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

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
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  GIT_MOCK_REVLIST["refs/tags/v1.5.0-dev"]="3faee"
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
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"

  PACK_CHANGELOG_MODE="release"

  changelog=$(git_changelog -f text -p v 2>&1)
  assertNotEquals 0 $?

  echo "$changelog"
  assertContains "${changelog}"  "Changelog generation for tag 'v0.0.1' failed!"
}

# Verify that all stable tags are returned in version-descending order and that
# a pre-release tag whose SHA does not match HEAD is silently dropped.
test_git_collect_tags() {
  UTILITY_GIT="git_mock"

  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  # refs/tags/v1.5.0-dev is absent from GIT_MOCK_REVLIST so rev-list returns ""
  # which differs from HEADSHA -> pre-release tag is excluded

  mapfile -t tags < <(git_collect_tags "v")

  # Expected: 5 stable tags in descending semver order; v1.5.0-dev absent.
  assertEquals 5 "${#tags[@]}"
  assertEquals "refs/tags/v1.5.0" "${tags[0]}"
  assertEquals "refs/tags/v1.2.4" "${tags[1]}"
  assertEquals "refs/tags/v1.2.3" "${tags[2]}"
  assertEquals "refs/tags/v0.9.0" "${tags[3]}"
  assertEquals "refs/tags/v0.0.1" "${tags[4]}"
}

# Verify that a pre-release tag pointing to HEAD is included while another
# pre-release tag pointing to a different commit is excluded.
test_git_collect_tags_prerelease_at_head() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_REFS=(            \
    "refs/tags/v1.5.0-rc0"  \
    "refs/tags/v1.5.0-dev"  \
    "refs/tags/v1.2.4"      \
    "refs/tags/v1.2.3"      \
    "refs/tags/v0.9.0"      \
    "refs/tags/v0.0.1"      \
  )
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  GIT_MOCK_REVLIST["refs/tags/v1.5.0-rc0"]="deadbeef"
  # refs/tags/v1.5.0-dev not set -> excluded

  mapfile -t tags < <(git_collect_tags "v")

  # Expected: v1.5.0-rc0 retained (at HEAD); v1.5.0-dev dropped (not at HEAD).
  assertEquals 5 "${#tags[@]}"
  assertEquals "refs/tags/v1.5.0-rc0" "${tags[0]}"
  assertEquals "refs/tags/v1.2.4"     "${tags[1]}"
  assertEquals "refs/tags/v1.2.3"     "${tags[2]}"
  assertEquals "refs/tags/v0.9.0"     "${tags[3]}"
  assertEquals "refs/tags/v0.0.1"     "${tags[4]}"
}

# Verify that a pre-release tag whose SHA differs from HEAD is excluded even
# when it is the only candidate tag in that position.
test_git_collect_tags_prerelease_not_at_head() {
  UTILITY_GIT="git_mock"

  GIT_MOCK_REFS=(           \
    "refs/tags/v1.5.0-dev"  \
    "refs/tags/v1.2.4"      \
    "refs/tags/v1.2.3"      \
    "refs/tags/v0.9.0"      \
    "refs/tags/v0.0.1"      \
  )
  declare -A GIT_MOCK_REVLIST
  GIT_MOCK_REVLIST["HEAD"]="deadbeef"
  GIT_MOCK_REVLIST["refs/tags/v1.5.0-dev"]="cafebabe"

  mapfile -t tags < <(git_collect_tags "v")

  # Expected: v1.5.0-dev dropped; only the 4 stable tags remain.
  assertEquals 4 "${#tags[@]}"
  assertEquals "refs/tags/v1.2.4" "${tags[0]}"
  assertEquals "refs/tags/v1.2.3" "${tags[1]}"
  assertEquals "refs/tags/v0.9.0" "${tags[2]}"
  assertEquals "refs/tags/v0.0.1" "${tags[3]}"
}

# For an annotated tag the annotation message and taggerdate are used directly;
# no GitHub CLI lookup occurs.
test_git_tag_desc_annotated_tag() {
  UTILITY_GIT="git_mock"

  local desc date
  git_tag_desc "v1.5.0" "tag" desc date 2>/dev/null

  # Expected: annotation body and taggerdate returned as-is.
  assertEquals "Change log text for release version v1.5.0" "${desc}"
  assertEquals "2022-08-03" "${date}"
}

# When an annotated tag has no taggerdate the function falls back to the
# committerdate of the underlying commit object.
test_git_tag_desc_annotated_tag_no_taggerdate() {
  UTILITY_GIT="git_mock"

  # v0.9.0 has no taggerdate in git_mock -> falls back to committerdate "2021-07-29"
  local desc date
  git_tag_desc "v0.9.0" "tag" desc date 2>/dev/null

  # Expected: commit message used for desc; committerdate used for date.
  assertEquals "Commit message for v0.9.0" "${desc}"
  assertEquals "2021-07-29" "${date}"
}

# For a commit tag with mode=full, when a GitHub release exists with a non-empty
# body, that body and the published date override the git annotation.
test_git_tag_desc_commit_full_with_gh_release() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  # v0.9.0 is a commit tag; ghcli_mock returns a release description for it
  local desc date
  git_tag_desc "v0.9.0" "commit" desc date 2>/dev/null

  # Expected: GitHub release body and publishedAt date returned.
  assertEquals "Release description for version v0.9.0" "${desc}"
  assertEquals "2021-07-29" "${date}"
}

# For a commit tag with mode=full, when no GitHub release exists the function
# falls back to the commit message and committerdate.
test_git_tag_desc_commit_full_no_gh_release() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"

  # v0.0.1: ghcli_mock returns 1 (no GitHub release) -> mode=full falls back to commit message
  local desc date
  git_tag_desc "v0.0.1" "commit" desc date 2>/dev/null

  # Expected: commit message and committerdate returned; exit code 0.
  assertEquals "Commit message for v0.0.1" "${desc}"
  assertEquals "2021-07-29" "${date}"
}

# For a commit tag with mode=release, when no GitHub release exists the function
# must fail rather than fall back to the commit message.
test_git_tag_desc_commit_release_mode_no_gh_release() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"
  PACK_CHANGELOG_MODE="release"

  # v0.0.1: ghcli_mock returns 1 (no GitHub release) -> mode=release -> fails
  local desc date
  git_tag_desc "v0.0.1" "commit" desc date 2>/dev/null

  # Expected: non-zero exit code; no fallback to commit message.
  assertNotEquals 0 $?
}

# With mode=tag only annotated tags are accepted; a commit tag must fail even
# when a GitHub release is available for it.
test_git_tag_desc_commit_tag_mode() {
  UTILITY_GIT="git_mock"
  UTILITY_GHCLI="ghcli_mock"
  PACK_CHANGELOG_MODE="tag"

  # type=commit with mode=tag always fails regardless of gh availability
  local desc date
  git_tag_desc "v0.9.0" "commit" desc date 2>/dev/null

  # Expected: non-zero exit code; GitHub CLI not consulted.
  assertNotEquals 0 $?
}

# For a commit tag with mode=full, when a GitHub release exists but its body is
# empty the git annotation message is kept while the GH published date is used.
test_git_tag_desc_commit_full_empty_gh_body() {
  UTILITY_GIT="git_mock"

  ghcli_empty_body_mock() {
    if [ "$1" = "release" ] && [ "$2" = "view" ]; then
      if [[ " $* " =~ " --json body " ]]; then
        echo ""
      elif [[ " $* " =~ " --json publishedAt " ]]; then
        echo "2022-01-15"
      fi
      return 0
    fi
    return 1
  }
  UTILITY_GHCLI="ghcli_empty_body_mock"

  # Empty GH release body + mode=full -> desc stays as git tag annotation message
  local desc date
  git_tag_desc "v1.2.3" "commit" desc date 2>/dev/null

  # Expected: git annotation body retained; GH publishedAt used as date.
  assertEquals "Change log text for release version v1.2.3" "${desc}"
  assertEquals "2022-01-15" "${date}"
}

# For a commit tag with mode=release, an empty GitHub release body is treated
# as a missing description and the function must fail.
test_git_tag_desc_commit_release_mode_empty_gh_body() {
  UTILITY_GIT="git_mock"
  PACK_CHANGELOG_MODE="release"

  ghcli_empty_body_mock() {
    if [ "$1" = "release" ] && [ "$2" = "view" ]; then
      if [[ " $* " =~ " --json body " ]]; then
        echo ""
      elif [[ " $* " =~ " --json publishedAt " ]]; then
        echo "2022-01-15"
      fi
      return 0
    fi
    return 1
  }
  UTILITY_GHCLI="ghcli_empty_body_mock"

  # Empty GH release body + mode=release -> fails
  local desc date
  git_tag_desc "v1.2.3" "commit" desc date 2>/dev/null

  # Expected: non-zero exit code; no fallback to commit message.
  assertNotEquals 0 $?
}

. "$(dirname "$0")/shunit2/shunit2"
