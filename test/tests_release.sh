#!/usr/bin/env bash
# Copyright (c) 2026 Arm Limited. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC2317,SC2329

DIRNAME="$(realpath "$(dirname "$0")")"
. "${DIRNAME}/../gen-pack"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit
  cp "${DIRNAME}/test_integ_default/ARM.GenPack.pdsc" Pack.pdsc
  cp Pack.pdsc original.pdsc
  PACK_CHANGELOG_MODE="pdsc"
  unset CHANGELOG
  export GIT_AUTHOR_NAME="Release Test"
  export GIT_AUTHOR_EMAIL="release@example.invalid"
  export GIT_COMMITTER_NAME="Release Test"
  export GIT_COMMITTER_EMAIL="release@example.invalid"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL=/dev/null
}

tearDown() {
  popd >/dev/null 2>&1 || true
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  unset GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL
}

release_test_run() (
  unset UTILITY_XMLLINT UTILITY_GIT
  gen_pack "$@" "$(realpath Pack.pdsc)"
)

release_test_git() {
  git init -q
  git add Pack.pdsc
  git commit -qm Initial
}

test_tag_optional_name() {
  local release_mode
  for release_mode in prepare finalize; do
    getopts --mode "${release_mode}" --tag -c v Pack.pdsc
    assertEquals 0 $?
    assertEquals 1 "${RELEASE_TAG}"
    assertEquals 1 "${RELEASE_COMMIT}"
    assertEquals '' "${RELEASE_TAG_NAME}"
    assertEquals v "${CHANGELOG}"
    assertEquals Pack.pdsc "${POSITIONAL[0]}"

    getopts --mode "${release_mode}" --tag custom-release Pack.pdsc
    assertEquals 0 $?
    assertEquals custom-release "${RELEASE_TAG_NAME}"
    assertEquals Pack.pdsc "${POSITIONAL[0]}"

    getopts --mode "${release_mode}" --tag=custom.pdsc -- Pack.pdsc
    assertEquals 0 $?
    assertEquals custom.pdsc "${RELEASE_TAG_NAME}"
    assertEquals Pack.pdsc "${POSITIONAL[0]}"
  done
}

test_invalid_release_options() {
  getopts --mode invalid
  assertNotEquals 0 $?
  getopts --mode build --tag
  assertNotEquals 0 $?
  getopts --mode finalize --date 2026-10-22
  assertNotEquals 0 $?
  getopts --version
  assertNotEquals 0 $?
  getopts --tag=
  assertNotEquals 0 $?
}

test_release_modes_require_pdsc_changelog() {
  local changelog_mode release_mode
  for changelog_mode in full release tag ''; do
    for release_mode in prepare build finalize; do
      PACK_CHANGELOG_MODE="${changelog_mode}" getopts --mode "${release_mode}"
      assertNotEquals "${changelog_mode:-unset}/${release_mode} must fail" 0 $?
    done
  done

  (
    unset PACK_CHANGELOG_MODE
    getopts --mode build
  )
  assertNotEquals 0 $?
}

test_default_release_mode_follows_changelog_source() {
  getopts --mode prepare
  assertEquals 0 $?
  getopts
  assertEquals 0 $?
  assertEquals build "${RELEASE_MODE}"

  local changelog_mode
  for changelog_mode in full release tag ''; do
    PACK_CHANGELOG_MODE="${changelog_mode}" getopts
    assertEquals 0 $?
    assertEquals '' "${RELEASE_MODE}"
  done

  (
    unset PACK_CHANGELOG_MODE
    getopts && [[ -z ${RELEASE_MODE} ]]
  )
  assertEquals 0 $?
}

test_invalid_release_dispatch_leaves_pdsc_unchanged() {
  local output
  output=$(PACK_CHANGELOG_MODE=tag gen_pack --mode prepare Pack.pdsc 2>&1)
  assertNotEquals 0 $?
  assertContains "${output}" "Release modes require PACK_CHANGELOG_MODE='pdsc'."
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  assertFalse '[ -d build ]'
  assertFalse '[ -d output ]'
}

test_prepare_defaults_and_preserves_notes() {
  release_test_run --mode prepare
  assertEquals 0 $?
  assertEquals 1.0.1 "$(pdsc_release_version Pack.pdsc)"
  assertContains "$(cat Pack.pdsc)" "date=\"$(date +%F)\""
  assertContains "$(cat Pack.pdsc)" 'Active development ...'
  # Only the opening tag changes; all remaining bytes are preserved.
  assertEquals "$(sed '/<release version="1.0.1/d' original.pdsc)" "$(sed '/<release version="1.0.1/d' Pack.pdsc)"
}

test_prepare_override_and_xml_url() {
  release_test_run --mode prepare --version 2.0.0-rc1 --date 2024-02-29 --url 'https://example.invalid/a?x=1&y="two"'
  assertEquals 0 $?
  assertEquals '2.0.0-rc1' "$(pdsc_release_version Pack.pdsc)"
  assertEquals 'https://example.invalid/a?x=1&y="two"' "$(xmllint --xpath 'string(/package/releases/release[1]/@url)' Pack.pdsc)"
}

test_prepare_strips_all_suffixes() {
  sed 's/1.0.1-dev1/1.0.1-rc1+build.42/' original.pdsc > Pack.pdsc
  release_test_run --mode prepare
  assertEquals 0 $?
  assertEquals 1.0.1 "$(pdsc_release_version Pack.pdsc)"
}

test_prepare_invalid_date_is_atomic() {
  release_test_run --mode prepare --date 2025-02-29
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  release_test_run --mode prepare --date 2026-13-01
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
}

test_prepare_rejects_dated_entry() {
  release_test_run --mode prepare
  cp Pack.pdsc prepared.pdsc
  release_test_run --mode prepare
  assertNotEquals 0 $?
  assertTrue 'cmp -s prepared.pdsc Pack.pdsc'
}

test_finalize_default_and_override() {
  release_test_run --mode prepare --date 2026-10-22
  cp Pack.pdsc prepared.pdsc
  release_test_run --mode finalize
  assertEquals 0 $?
  assertEquals 1.0.2-dev "$(pdsc_release_version Pack.pdsc)"
  assertEquals 0 "$(xmllint --xpath 'count(/package/releases/release[1]/@date | /package/releases/release[1]/@tag | /package/releases/release[1]/@url)' Pack.pdsc)"
  assertContains "$(cat Pack.pdsc)" 'Active development ...'
  assertContains "$(cat Pack.pdsc)" '<release version="1.0.1" date="2026-10-22">'

  cp prepared.pdsc Pack.pdsc
  release_test_run --mode finalize --version 2.0.0-dev
  assertEquals 0 $?
  assertEquals 2.0.0-dev "$(pdsc_release_version Pack.pdsc)"
}

test_finalize_requires_release_and_higher_version() {
  release_test_run --mode finalize
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  release_test_run --mode prepare
  cp Pack.pdsc prepared.pdsc
  release_test_run --mode finalize --version 1.0.0
  assertNotEquals 0 $?
  assertTrue 'cmp -s prepared.pdsc Pack.pdsc'
}

test_annotated_default_tag_and_finalize_commit() {
  release_test_git
  release_test_run --mode prepare --tag -c v --date 2026-10-22
  assertEquals 0 $?
  assertEquals tag "$(git cat-file -t v1.0.1)"
  assertEquals "$(git rev-parse HEAD)" "$(git rev-list -n1 v1.0.1)"
  assertEquals 'Active development ...' "$(git tag -l --format='%(contents)' v1.0.1)"
  assertEquals v1.0.1 "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
  assertTrue 'git diff --quiet HEAD -- Pack.pdsc'

  release_test_build
  assertEquals 0 $?
  git show v1.0.1:Pack.pdsc > tagged.pdsc
  assertTrue 'cmp -s tagged.pdsc output/archived.pdsc'

  release_test_run --mode finalize --commit
  assertEquals 0 $?
  assertEquals 3 "$(git rev-list --count HEAD)"
  assertEquals 1.0.2-dev "$(pdsc_release_version Pack.pdsc)"
  assertEquals "$(git rev-parse HEAD^)" "$(git rev-list -n1 v1.0.1)"
  assertEquals v1.0.1 "$(git tag -l)"
  assertContains "$(git show v1.0.1:Pack.pdsc)" '<release version="1.0.1" date="2026-10-22" tag="v1.0.1">'
}

test_finalize_creates_annotated_dev_tag() {
  sed 's/Active development \.\.\./Released changes/' Pack.pdsc > notes.pdsc
  cp notes.pdsc Pack.pdsc
  release_test_git
  release_test_run --mode prepare --tag -c v --date 2026-10-22
  assertEquals 0 $?
  cp Pack.pdsc prepared.pdsc

  release_test_run --mode finalize --tag -c v
  assertEquals 0 $?
  assertEquals 3 "$(git rev-list --count HEAD)"
  assertEquals 'Start development of 1.0.2-dev' "$(git log -1 --format=%s)"
  assertEquals tag "$(git cat-file -t v1.0.2-dev)"
  assertEquals "$(git rev-parse HEAD)" "$(git rev-list -n1 v1.0.2-dev)"
  assertEquals 'Active development ...' "$(git tag -l --format='%(contents)' v1.0.2-dev)"
  assertEquals 'Released changes' "$(git tag -l --format='%(contents)' v1.0.1)"
  assertEquals v1.0.2-dev "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
  assertEquals 0 "$(xmllint --xpath 'count(/package/releases/release[1]/@date | /package/releases/release[1]/@url)' Pack.pdsc)"
  assertTrue 'git diff --quiet HEAD -- Pack.pdsc'
  git show v1.0.2-dev:Pack.pdsc > tagged-dev.pdsc
  assertTrue 'cmp -s Pack.pdsc tagged-dev.pdsc'
  git show v1.0.1:Pack.pdsc > tagged-release.pdsc
  assertTrue 'cmp -s prepared.pdsc tagged-release.pdsc'
}

test_finalize_explicit_tag_and_version() {
  release_test_git
  release_test_run --mode prepare --commit
  assertEquals 0 $?

  release_test_run --mode finalize --version 2.0.0 --tag=custom.pdsc -c ignored
  assertEquals 0 $?
  assertEquals 2.0.0-dev "$(pdsc_release_version Pack.pdsc)"
  assertEquals custom.pdsc "$(git tag -l)"
  assertEquals tag "$(git cat-file -t custom.pdsc)"
  assertEquals 'Active development ...' "$(git tag -l --format='%(contents)' custom.pdsc)"
  assertEquals custom.pdsc "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
}

test_finalize_default_tag_without_prefix() {
  release_test_git
  release_test_run --mode prepare --commit
  assertEquals 0 $?

  release_test_run --mode finalize --tag
  assertEquals 0 $?
  assertEquals tag "$(git cat-file -t 1.0.2-dev)"
  assertEquals 1.0.2-dev "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
}

test_finalize_rejects_existing_and_invalid_tags_before_edit() {
  release_test_git
  release_test_run --mode prepare --commit
  assertEquals 0 $?
  cp Pack.pdsc prepared.pdsc
  git tag v1.0.2-dev

  release_test_run --mode finalize --tag -c v
  assertNotEquals 0 $?
  assertTrue 'cmp -s prepared.pdsc Pack.pdsc'
  assertEquals 2 "$(git rev-list --count HEAD)"

  release_test_run --mode finalize --tag invalid..tag
  assertNotEquals 0 $?
  assertTrue 'cmp -s prepared.pdsc Pack.pdsc'
  assertEquals 2 "$(git rev-list --count HEAD)"
  assertEquals v1.0.2-dev "$(git tag -l)"
}

test_finalize_failed_commit_retains_pdsc_without_tag() {
  release_test_git
  release_test_run --mode prepare --commit
  assertEquals 0 $?
  printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit

  release_test_run --mode finalize --tag -c v
  assertNotEquals 0 $?
  assertEquals 2 "$(git rev-list --count HEAD)"
  assertEquals '' "$(git tag -l)"
  assertEquals 1.0.2-dev "$(pdsc_release_version Pack.pdsc)"
  assertEquals v1.0.2-dev "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
}

test_explicit_tag_overrides_prefix() {
  release_test_git
  release_test_run --mode prepare -c ignored --tag release/custom-1.0.1
  assertEquals 0 $?
  assertEquals tag "$(git cat-file -t release/custom-1.0.1)"
  assertEquals release/custom-1.0.1 "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' Pack.pdsc)"
}

test_default_tag_without_prefix() {
  release_test_git
  release_test_run --mode prepare --tag
  assertEquals 0 $?
  assertEquals tag "$(git cat-file -t 1.0.1)"
}

test_commit_only() {
  release_test_git
  release_test_run --mode prepare --commit
  assertEquals 0 $?
  assertEquals 2 "$(git rev-list --count HEAD)"
  assertEquals '' "$(git tag -l)"
}

test_release_in_subdirectory_with_spaces() {
  mkdir 'package sources'
  mv Pack.pdsc 'package sources/Pack.pdsc'
  git init -q
  git add 'package sources/Pack.pdsc'
  git commit -qm Initial

  (
    cd 'package sources' || exit 1
    release_test_run --mode prepare --tag -c v --date 2026-10-22
  )
  assertEquals 0 $?
  assertEquals 2 "$(git rev-list --count HEAD)"
  assertEquals tag "$(git cat-file -t v1.0.1)"
  assertContains "$(git show 'v1.0.1:package sources/Pack.pdsc')" 'date="2026-10-22"'

  (
    cd 'package sources' || exit 1
    release_test_run --mode finalize --tag -c v
  )
  assertEquals 0 $?
  assertEquals 3 "$(git rev-list --count HEAD)"
  assertEquals tag "$(git cat-file -t v1.0.2-dev)"
  assertContains "$(git show 'v1.0.2-dev:package sources/Pack.pdsc')" 'version="1.0.2-dev"'
  assertEquals '' "$(git status --porcelain -- 'package sources/Pack.pdsc')"
}

test_git_diff_errors_leave_source_unchanged() {
  release_test_git
  local git_path
  git_path=$(command -v git)
  local injected_diff_scope output

  for injected_diff_scope in worktree index; do
    output=$(
      release_test_failing_git() {
        if [[ $3 == diff ]]; then
          if [[ ${injected_diff_scope} == worktree && " $* " != *' --cached '* ]] ||
             [[ ${injected_diff_scope} == index && " $* " == *' --cached '* ]]; then
            return 128
          fi
        fi
        "${git_path}" "$@"
      }

      find_git() {
        UTILITY_GIT=release_test_failing_git
      }

      release_test_run --mode prepare --tag -c v 2>&1
    )
    assertNotEquals "Git ${injected_diff_scope} error accepted" 0 $?
    assertContains "${output}" "Git ${injected_diff_scope} diff check failed (exit 128)."
    assertNotContains "${output}" 'Only the PDSC may have tracked changes'
    assertTrue 'cmp -s original.pdsc Pack.pdsc'
    assertEquals 1 "$(git rev-list --count HEAD)"
    assertEquals '' "$(git tag -l)"
  done
}

test_existing_tag_is_rejected_before_edit() {
  release_test_git
  git tag v1.0.1
  release_test_run --mode prepare -c v --tag
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  assertEquals 1 "$(git rev-list --count HEAD)"
}

test_invalid_tag_is_rejected_before_edit() {
  release_test_git
  release_test_run --mode prepare --tag 'invalid..tag'
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  assertEquals 1 "$(git rev-list --count HEAD)"
}

test_leading_hyphen_tags_are_rejected_before_edit() {
  release_test_git
  local release_mode tag_source output original_head original_index

  for release_mode in prepare finalize; do
    if [[ ${release_mode} == finalize ]]; then
      release_test_run --mode prepare --commit
      assertEquals 0 $? || return
    fi

    cp Pack.pdsc before.pdsc
    original_head=$(git rev-parse HEAD)
    original_index=$(git write-tree)

    for tag_source in explicit prefix; do
      if [[ ${tag_source} == explicit ]]; then
        output=$(release_test_run --mode "${release_mode}" --tag=-bad 2>&1)
      else
        output=$(CHANGELOG=- release_test_run --mode "${release_mode}" --tag 2>&1)
      fi

      assertNotEquals "Leading hyphen accepted for ${release_mode} (${tag_source})" 0 $?
      assertContains "${output}" 'must not begin with a hyphen'
      assertTrue 'cmp -s before.pdsc Pack.pdsc'
      assertEquals "${original_head}" "$(git rev-parse HEAD)"
      assertEquals "${original_index}" "$(git write-tree)"
      assertEquals '' "$(git tag -l)"
    done
  done
}

test_failed_commit_retains_pdsc_without_tag() {
  release_test_git
  printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
  release_test_run --mode prepare --tag
  assertNotEquals 0 $?
  assertEquals 1 "$(git rev-list --count HEAD)"
  assertEquals '' "$(git tag -l)"
  assertEquals 1.0.1 "$(pdsc_release_version Pack.pdsc)"
  assertEquals 1 "$(xmllint --xpath 'count(/package/releases/release[1]/@date)' Pack.pdsc)"
}

test_invalid_xml_and_version_leave_source_unchanged() {
  release_test_run --mode prepare --version 1.2.3-01
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  printf '<package><releases/></package>\n' > Pack.pdsc
  cp Pack.pdsc input.pdsc
  release_test_run --mode prepare
  assertNotEquals 0 $?
  assertTrue 'cmp -s input.pdsc Pack.pdsc'
  printf '<package>\n' > Pack.pdsc
  cp Pack.pdsc input.pdsc
  release_test_run --mode prepare
  assertNotEquals 0 $?
  assertTrue 'cmp -s input.pdsc Pack.pdsc'
}

test_release_dispatch_skips_build_tools_and_hooks() {
  (
    unset UTILITY_GIT
    find_pack_root() { exit 90; }
    preprocess() { exit 91; }
    postprocess() { exit 92; }
    find_git() { exit 93; }
    find_ghcli() { exit 94; }
    gen_pack --mode prepare --date 2026-10-22 -c v Pack.pdsc
    gen_pack --mode finalize -c v Pack.pdsc
  )
  assertEquals 0 $?
  assertEquals 1.0.2-dev "$(pdsc_release_version Pack.pdsc)"
  assertFalse '[ -d build ]'
  assertFalse '[ -d output ]'
}

test_release_tools_are_available_before_dispatch() {
  local release_mode git_option
  for release_mode in prepare finalize; do
    for git_option in --commit --tag; do
      (
        unset UTILITY_XMLLINT UTILITY_GIT
        find_xmllint() { UTILITY_XMLLINT="selected-xmllint"; }
        find_git() { UTILITY_GIT="selected-git"; }
        find_ghcli() { exit 90; }
        release_update_pdsc() {
          [[ ${UTILITY_XMLLINT} == selected-xmllint && ${UTILITY_GIT} == selected-git ]]
        }
        gen_pack --mode "${release_mode}" "${git_option}" Pack.pdsc
      )
      assertEquals "Tools unavailable for ${release_mode} ${git_option}" 0 $?
    done
  done
}

test_missing_release_tools_leave_source_unchanged() {
  local xmllint_path git_path
  xmllint_path=$(command -v xmllint)
  git_path=$(command -v git)

  local missing_tool tool_state release_mode git_option output expected_error
  for missing_tool in xmllint git; do
    if [[ ${missing_tool} == xmllint ]]; then
      expected_error="xmllint is required."
    else
      expected_error="Git is required."
    fi

    for tool_state in unset empty; do
      for release_mode in prepare finalize; do
        for git_option in --commit --tag; do
          output=$(
            unset UTILITY_XMLLINT UTILITY_GIT
            find_xmllint() {
              if [[ ${missing_tool} != xmllint ]]; then
                UTILITY_XMLLINT="${xmllint_path}"
              elif [[ ${tool_state} == empty ]]; then
                UTILITY_XMLLINT=""
              fi
            }
            find_git() {
              if [[ ${missing_tool} != git ]]; then
                UTILITY_GIT="${git_path}"
              elif [[ ${tool_state} == empty ]]; then
                UTILITY_GIT=""
              fi
            }
            gen_pack --mode "${release_mode}" "${git_option}" Pack.pdsc 2>&1
          )
          assertNotEquals "Missing ${missing_tool} (${tool_state}) accepted for ${release_mode} ${git_option}" 0 $?
          assertContains "${output}" "${expected_error}"
          assertTrue 'cmp -s original.pdsc Pack.pdsc'
        done
      done
    done
  done
}

test_unrelated_tracked_changes_are_rejected() {
  release_test_git
  echo original > other.txt
  git add other.txt
  git commit -qm Other
  echo changed > other.txt
  release_test_run --mode prepare --commit
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
  git add other.txt
  release_test_run --mode prepare --commit
  assertNotEquals 0 $?
  assertTrue 'cmp -s original.pdsc Pack.pdsc'
}

test_multiline_xml_comments_and_crlf() {
  cat > Pack.pdsc <<'EOF'
<?xml version="1.0"?>
<package>
  <!-- <releases><release version="0.0.0">fake</release></releases> -->
  <releases>
    <!-- <release version="0.0.0">fake</release> -->
    <release
      version='1.2.3-dev' url='stale' tag='stale'>
      A &amp; B <![CDATA[<release version="fake">]]>
    </release>
  </releases>
</package>
EOF
  sed 's/$/\r/' Pack.pdsc > crlf.pdsc
  cp crlf.pdsc Pack.pdsc
  release_test_run --mode prepare --date 2026-10-22
  assertEquals 0 $?
  assertEquals 1.2.3 "$(xmllint --xpath 'string(/package/releases/release[1]/@version)' Pack.pdsc)"
  assertEquals 0 "$(xmllint --xpath 'count(/package/releases/release[1]/@url | /package/releases/release[1]/@tag)' Pack.pdsc)"
  release_test_run --mode finalize
  assertEquals 0 $?
  assertContains "$(cat Pack.pdsc)" $'version="1.2.4-dev">\r\n'
}

# Exercise the real build dispatcher with only packaging tools replaced.
release_test_build() (
  check_shebang() { true; }
  check_locale() { true; }
  find_pack_root() { true; }
  find_zip() { true; }
  find_packchk() { true; }
  find_xmllint() { true; }
  find_curl() { true; }
  find_git() { exit 90; }
  find_ghcli() { exit 91; }
  find_eol_converter() { true; }
  add_dirs() { true; }
  add_files() { true; }
  delete_files() { true; }
  apply_patches() { true; }
  preprocess() {
    if [[ ${CHANGE_SOURCE} == 1 ]]; then
      echo '<!-- changed -->' >> Pack.pdsc
    fi
  }
  postprocess() {
    if [[ ${CHANGE_BUILD} == 1 ]]; then
      echo '<!-- changed -->' >> "${PACK_BUILD_DESCRIPTION_FILE}"
    fi
  }
  check_schema() { true; }
  check_pack() { echo test.pack > "${PACK_OUTPUT}/PackName.txt"; }
  create_sha1() { true; }
  archive() {
    printf '%s\n' "${PACK_CHANGELOG_MODE}" > "${PACK_OUTPUT}/changelog-mode.txt"
    printf '%s\n' "${RELEASE_MODE}" > "${PACK_OUTPUT}/release-mode.txt"
    cp "${PACK_BUILD_DESCRIPTION_FILE}" "${PACK_OUTPUT}/archived.pdsc"
  }
  gen_pack -c v --keep "$@" Pack.pdsc
)

test_build_preserves_exact_pdsc() {
  release_test_run --mode prepare
  release_test_build --mode build
  assertEquals 0 $?
  assertEquals pdsc "$(cat output/changelog-mode.txt)"
  assertEquals build "$(cat output/release-mode.txt)"
  assertTrue 'cmp -s Pack.pdsc output/archived.pdsc'
}

test_pdsc_mode_preserves_exact_pdsc_with_changelog_option() {
  PACK_CHANGELOG_MODE=pdsc release_test_build --verbose
  assertEquals 0 $?
  assertEquals build "$(cat output/release-mode.txt)"
  assertTrue 'cmp -s original.pdsc output/archived.pdsc'
}

test_pdsc_mode_preserves_exact_pdsc_without_changelog_option() {
  PACK_CHANGELOG_MODE=pdsc release_test_build --no-changelog
  assertEquals 0 $?
  assertEquals build "$(cat output/release-mode.txt)"
  assertTrue 'cmp -s original.pdsc output/archived.pdsc'
}

test_pdsc_mode_rejects_hook_changes() {
  PACK_CHANGELOG_MODE=pdsc CHANGE_BUILD=1 release_test_build --verbose
  assertNotEquals 0 $?
  assertFalse '[ -e output/archived.pdsc ]'
  PACK_CHANGELOG_MODE=pdsc CHANGE_SOURCE=1 release_test_build --no-changelog
  assertNotEquals 0 $?
  assertFalse '[ -e output/archived.pdsc ]'
}

test_build_rejects_hook_changes() {
  CHANGE_BUILD=1 release_test_build
  assertNotEquals 0 $?
  assertFalse '[ -e output/archived.pdsc ]'
  CHANGE_SOURCE=1 release_test_build
  assertNotEquals 0 $?
  assertFalse '[ -e output/archived.pdsc ]'
}

. "${DIRNAME}/shunit2/shunit2"
