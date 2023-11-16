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

setUp() {
  export GEN_PACK_LIB="$(realpath "${DIRNAME}/../")"
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null
}

teardown() {
  unset GEN_PACK_LIB
  unset TESTDIR
  popd >/dev/null
}

test_integ_default() {
  cp -r "${DIRNAME}/test_integ_default" .
  cd test_integ_default

  rm -rf build output

  ./gen_pack.sh -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.1-dev1.pack ]"

  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"

  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.1-dev1">'
  assertContains "$pdsc" '<release version="1.0.0" date="2022-08-04" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertContains "$pdsc" "Active development ..."
}

test_integ_with_git_release() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git

  git --git-dir=$(pwd)/.git clean -fdxq
  git --git-dir=$(pwd)/.git checkout -fq v1.0.0

  ./gen_pack.sh -k

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

test_integ_with_git_prerelease() {
  mkdir -p test_integ_with_git
  tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C test_integ_with_git
  cd test_integ_with_git

  git --git-dir=$(pwd)/.git clean -fdxq
  git --git-dir=$(pwd)/.git checkout -fq v1.0.0

  GIT_COMMITTER_NAME="github-actions"
  GIT_COMMITTER_EMAIL="github-actions@github.com"
  GIT_COMMITTER_DATE="2022-08-04T16:00:00Z"
  git --git-dir=$(pwd)/.git tag -m "Active development ..." v1.0.0-dev v1.0.0^

  ./gen_pack.sh -k

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
  cd test_integ_with_git

  git --git-dir=$(pwd)/.git clean -fdxq
  git --git-dir=$(pwd)/.git checkout -fq main

  ./gen_pack.sh -k

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
  cd test_integ_with_git

  git --git-dir=$(pwd)/.git clean -fdxq
  git --git-dir=$(pwd)/.git checkout -fq v2

  ./gen_pack.sh -k

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

