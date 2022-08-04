#!/bin/bash

DIRNAME="$(dirname "$0")"

test_integ_default() {
  cd "${DIRNAME}/test_integ_default"

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
  test -d "${DIRNAME}/test_integ_with_git" || tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C "${DIRNAME}"
  cd "${DIRNAME}/test_integ_with_git"
  
  git --git-dir=$(pwd)/.git clean -fdx
  git --git-dir=$(pwd)/.git checkout -f v1.0.0
  
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
  assertContains "$pdsc" '<release version="1.0.0" date="2022-08-04" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertNotContains "$pdsc" "Active development ..."
}

test_integ_with_git_devdrop() {
  test -d "${DIRNAME}/test_integ_with_git" || tar -xjf "${DIRNAME}/test_integ_with_git.tbz2" -C "${DIRNAME}"
  cd "${DIRNAME}/test_integ_with_git"
  
  git --git-dir=$(pwd)/.git clean -fdx
  git --git-dir=$(pwd)/.git checkout -f main
  
  ./gen_pack.sh -k

  assertTrue  "Pack description file missing"  "[ -f build/ARM.GenPack.pdsc ]"
  assertTrue  "Pack checksum file missing"     "[ -f build/ARM.GenPack.sha1 ]"
  assertTrue  "LICENSE file"                   "[ -f build/LICENSE ]"
  assertTrue  "Doc top level index missing"    "[ -f build/doc/index.html ]"
  assertFalse "Doxyfile found in build"        "[ -f build/doc/test.dxy ]"
  assertTrue  "Doc index file missing"         "[ -f build/doc/html/index.html ]"
  assertTrue  "Header file missing"            "[ -f build/inc/test.h ]"
  assertTrue  "Source file missing"            "[ -f build/src/test.c ]"
  assertTrue  "Pack archive missing"           "[ -f output/ARM.GenPack.1.0.1-dev1+g932aa3d.pack ]"
  
  assertTrue  "Checksum file verification failed" "cd build; sha1sum ARM.GenPack.sha1"
 
  pdsc=$(cat build/ARM.GenPack.pdsc)
  assertContains "$pdsc" '<release version="1.0.1-dev1+g932aa3d">'
  assertContains "$pdsc" '<release version="1.0.0" date="2022-08-04" tag="v1.0.0">'
  assertContains "$pdsc" "Initial release 1.0.0"
  assertContains "$pdsc" "Active development ..."
}

. "${DIRNAME}/shunit2/shunit2"
