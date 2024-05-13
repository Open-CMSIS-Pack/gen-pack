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

