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

DIRNAME="$(realpath "$(dirname "$0")")"

shopt -s expand_aliases

case $(uname -s) in
  'Darwin')
    alias "stat"="gstat"
  ;;
esac

setUp() {
  # shellcheck disable=SC2155
  export GEN_PACK_LIB="$(realpath "${DIRNAME}/../")"
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit
 
  export GIT_COMMITTER_NAME="github-actions"
  export GIT_COMMITTER_EMAIL="github-actions@github.com"
}

teardown() {
  unset GEN_PACK_LIB
  unset TESTDIR
  popd >/dev/null || exit
}

test_integ_default() {
  cp -r "${DIRNAME}/test_integ_default" .
  cd test_integ_default || return

  rm -rf build output

  ./gen_pack.sh --verbose -k

  assertTrue   "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue   "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue   "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue   "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse  "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue   "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue   "Header file missing"            "[ -f build/inc/test.h ]"
  assertEquals "test.h seems not patched"       "13" "$(stat -c "%s" build/inc/test.h)"
  assertTrue   "Source file missing"            "[ -f build/src/test.c ]"
  assertEquals "test.c seems not patched"       "48" "$(stat -c "%s" build/src/test.c)"
  assertTrue   "Source file missing"            "[ -f build/src/win.c ]"
  assertEquals "win.c seems not patched"        "50" "$(stat -c "%s" build/src/win.c)"
  assertTrue   "Source file missing"            "[ -f build/src/mac.c ]"
  assertEquals "mac.c seems not patched"        "47" "$(stat -c "%s" build/src/mac.c)"
  assertTrue   "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.1-dev1.pack ]"

  assertTrue   "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.1-dev1">'
  assertContains "$pdsc" '<release version="1.0.0" date="2022-08-04" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertContains "$pdsc" "Active development ..."
}

# Exercise the PDSC release workflow with real packaging tools and Git.
test_integ_pdsc_release_workflow() {
  local -x PACK_CHANGELOG_MODE="pdsc"
  local -x GIT_AUTHOR_NAME="Release Integration Test"
  local -x GIT_AUTHOR_EMAIL="release-test@example.invalid"
  local -x GIT_CONFIG_NOSYSTEM=1
  local -x GIT_CONFIG_GLOBAL=/dev/null

  cp -r "${DIRNAME}/test_integ_default" .
  cd test_integ_default || return

  # Step 1 - Prepare git repository with pdsc file
  sed 's/Active development \.\.\./Integration release notes/' ARM.GenPack.pdsc > release.pdsc
  mv release.pdsc ARM.GenPack.pdsc

  git init -q
  assertEquals "Git initialization failed" 0 $? || return

  git add .
  assertEquals "Fixture staging failed" 0 $? || return

  git commit -qm "Initial release workflow fixture"
  assertEquals "Initial commit failed" 0 $? || return

  # Step 2 - Run the release preparation to set version and date in pdsc, commit, and tag
  ./gen_pack.sh --mode prepare --version 1.2.3 --date 2026-10-26 --tag -c v
  assertEquals "Release preparation failed" 0 $? || return

  assertFalse "Prepare created a build directory" '[ -d build ]'
  assertFalse "Prepare created an output directory" '[ -d output ]'
  assertEquals tag "$(git cat-file -t v1.2.3)"
  assertEquals 'Integration release notes' "$(git tag -l --format='%(contents)' v1.2.3)"
  assertEquals "$(git rev-parse HEAD)" "$(git rev-list -n1 v1.2.3)"
  assertEquals 1.2.3 "$(xmllint --xpath 'string(/package/releases/release[1]/@version)' ARM.GenPack.pdsc)"
  assertEquals 2026-10-26 "$(xmllint --xpath 'string(/package/releases/release[1]/@date)' ARM.GenPack.pdsc)"
  assertEquals v1.2.3 "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' ARM.GenPack.pdsc)"

  local release_commit
  local release_tag
  release_commit=$(git rev-parse HEAD)
  release_tag=$(git rev-parse v1.2.3)
  git show v1.2.3:ARM.GenPack.pdsc > ../tagged-release.pdsc
  assertEquals "Cannot read the release PDSC from its tag" 0 $? || return

  # Step 3 - Run the default release build with changelog and keep the build directory
  ./gen_pack.sh -c v --keep
  assertEquals "Default release build failed" 0 $? || return

  assertTrue "Pack archive missing" '[ -f output/ARM.GenPack.1.2.3.pack ]'
  assertTrue "Build PDSC differs from the release tag" 'cmp -s ../tagged-release.pdsc build/ARM.GenPack.pdsc'
  assertTrue "Build changed the source PDSC" 'cmp -s ../tagged-release.pdsc ARM.GenPack.pdsc'
  assertEquals "Build created a commit" "${release_commit}" "$(git rev-parse HEAD)"
  assertEquals "Build changed tracked files" '' "$(git status --porcelain)"

  unzip -tq output/ARM.GenPack.1.2.3.pack
  assertEquals "Archive CRC validation failed" 0 $? || return
  unzip -q output/ARM.GenPack.1.2.3.pack -d ../unpacked-release
  assertEquals "Cannot extract Pack archive" 0 $? || return

  assertTrue "Archived PDSC differs from tag" 'cmp -s ../tagged-release.pdsc ../unpacked-release/ARM.GenPack.pdsc'
  assertContains "Header patch was not packaged" "$(cat ../unpacked-release/inc/test.h)" 'void test();'
  assertTrue "Checksum manifest is empty" '[ -s ../unpacked-release/ARM.GenPack.sha1 ]'
  (
    cd ../unpacked-release || exit 1
    sha1sum --check --strict ARM.GenPack.sha1
  )
  assertEquals "Pack checksum verification failed" 0 $? || return

  # Step 4 - Run post-release finalization
  ./gen_pack.sh --mode finalize --tag -c v
  assertEquals "Release finalization failed" 0 $? || return
  
  assertEquals 3 "$(git rev-list --count HEAD)"
  assertEquals 'Start development of 1.2.4-dev' "$(git log -1 --format=%s)"
  assertEquals tag "$(git cat-file -t v1.2.4-dev)"
  assertEquals "$(git rev-parse HEAD)" "$(git rev-list -n1 v1.2.4-dev)"
  assertEquals 'Active development ...' "$(git tag -l --format='%(contents)' v1.2.4-dev)"
  assertEquals 1.2.4-dev "$(xmllint --xpath 'string(/package/releases/release[1]/@version)' ARM.GenPack.pdsc)"
  assertEquals v1.2.4-dev "$(xmllint --xpath 'string(/package/releases/release[1]/@tag)' ARM.GenPack.pdsc)"
  assertEquals 0 "$(xmllint --xpath 'count(/package/releases/release[1]/@date | /package/releases/release[1]/@url)' ARM.GenPack.pdsc)"
  assertEquals "Finalize changed earlier releases" \
    "$(xmllint --xpath '/package/releases/release' ../tagged-release.pdsc)" \
    "$(xmllint --xpath '/package/releases/release[position()>1]' ARM.GenPack.pdsc)"
  assertEquals "Finalize moved the release tag" "${release_tag}" "$(git rev-parse v1.2.3)"
  git show v1.2.4-dev:ARM.GenPack.pdsc > ../tagged-dev.pdsc
  assertEquals "Cannot read the development PDSC from its tag" 0 $? || return
  assertTrue "Development tag differs from source PDSC" 'cmp -s ../tagged-dev.pdsc ARM.GenPack.pdsc'
  assertEquals "Finalize left uncommitted changes" '' "$(git status --porcelain)"
}

test_integ_with_git_release() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || return

  git --git-dir="$(pwd)/.git" clean -fdxq
  git --git-dir="$(pwd)/.git" checkout -fq v1.0.0

  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.0.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.0" date="2023-05-22" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertNotContains "$pdsc" "Active development ..."
}

test_integ_with_git_recreate_release() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || return

  git --git-dir="$(pwd)/.git" clean -fdxq
  export GIT_COMMITTER_DATE="2023-06-16T13:00:00Z"
  git --git-dir="$(pwd)/.git" tag -m "Release v1.1.0" v1.1.0
  git --git-dir="$(pwd)/.git" checkout -fq v1.0.0

  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.0.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.0" date="2023-05-22" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertNotContains "$pdsc" "Active development ..."
  assertNotContains "$pdsc" '<release version="1.1.0"'
  assertNotContains "$pdsc" "Release v1.1.0"
}

test_integ_with_git_release_candidate() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || return

  git --git-dir="$(pwd)/.git" clean -fdxq
  git --git-dir="$(pwd)/.git" checkout -fq v1.0.0
  export GIT_COMMITTER_DATE="2023-05-22T16:00:00Z"
  git --git-dir="$(pwd)/.git" tag -m "Pre-release" v1.0.0-rc0
  export GIT_COMMITTER_DATE="2022-08-04T16:00:00Z"
  git --git-dir="$(pwd)/.git" tag -m "Old release" v0.9.0 v1.0.0^
  git --git-dir="$(pwd)/.git" tag -d v1.0.0
  
  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.0-rc0.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.0-rc0" date="2023-05-22" tag="v1.0.0-rc0">'
  assertContains "$pdsc" "Pre-release"
  assertContains "$pdsc" '<release version="0.9.0" date="2022-08-04" tag="v0.9.0">'
  assertContains "$pdsc" "Old release"
}

test_integ_with_git_prerelease() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || return

  git --git-dir="$(pwd)/.git" config --global user.email "you@example.com"
  git --git-dir="$(pwd)/.git" config --global user.name "Your Name"

  git --git-dir="$(pwd)/.git" clean -fdxq
  git --git-dir="$(pwd)/.git" checkout -fq v1.0.0

  export GIT_COMMITTER_DATE="2022-08-04T16:00:00Z"
  git --git-dir="$(pwd)/.git" tag -m "Active development ..." v1.0.0-dev v1.0.0^

  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.0.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.0" date="2023-05-22" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertNotContains "$pdsc" '<release version="1.0.0-dev" date="2022-08-04" tag="v1.0.0-dev">'
  assertNotContains "$pdsc" "Active development ..."
}

test_integ_with_git_devdrop() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || exit

  git --git-dir="$(pwd)/.git" clean -fdxq
  git --git-dir="$(pwd)/.git" checkout -fq main

  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.1-dev1+g07dedc7.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.1-dev1+g07dedc7">'
  assertContains "$pdsc" '<release version="1.0.0" date="2023-05-22" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertContains "$pdsc" "Active development ..."
}

test_integ_with_git_v2_dev() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git || return

  git --git-dir="$(pwd)/.git" clean -fdxq
  git --git-dir="$(pwd)/.git" checkout -fq v2

  ./gen_pack.sh --verbose -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.2.0.0-dev1+gecd4525.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="2.0.0-dev1+gecd4525">'
  assertContains "$pdsc" '<release version="1.0.0" date="2023-05-22" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertContains "$pdsc" "Active development ..."
}

. "${DIRNAME}/shunit2/shunit2"

