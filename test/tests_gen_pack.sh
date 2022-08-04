#!/bin/bash

. "$(dirname "$0")/../gen-pack"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null
}

tearDown() {
  unset UTILITY_CURL_RESULT
  unset CURL_MOCK_ARGS
  unset XMLLINT_MOCK_ARGS
}

createTestData() {
  # prepare a folder structure
  mkdir input1
  mkdir input2
  mkdir input3
  echo "File 11" > input1/file11.txt
  echo "File 12" > input1/file12.txt
  echo "File 13" > input1/file13.txt
  echo "File 21" > input2/file21.txt
  echo "File 22" > input2/file22.txt
  echo "File 23" > input2/file23.txt
  echo "File 31" > input3/file31.txt
  echo "File 32" > input3/file32.txt
  echo "File 33" > input3/file33.txt

  # create a target folder
  mkdir output  
}

test_add_dirs() {
  createTestData
  
  # run add_dirs
  PACK_DIRS="
    input1
    input2
  "
  add_dirs "output"
  
  assertTrue  "[ -d output/input1 ]"
  assertTrue  "[ -f output/input1/file11.txt ]"
  assertTrue  "[ -f output/input1/file12.txt ]"
  assertTrue  "[ -f output/input1/file13.txt ]"
  assertTrue  "[ -d output/input2 ]"
  assertTrue  "[ -f output/input2/file21.txt ]"
  assertTrue  "[ -f output/input2/file22.txt ]"
  assertTrue  "[ -f output/input2/file23.txt ]" 
  assertFalse "[ -d output/input3 ]"
}

test_add_files() {
  createTestData
  
  # run add_dirs
  PACK_BASE_FILES="
    input1/file12.txt
    input3/file31.txt
  "
  add_files "output"
  
  assertFalse "[ -f output/input1/file11.txt ]"
  assertTrue  "[ -f output/input1/file12.txt ]"
  assertFalse "[ -f output/input1/file13.txt ]"
  assertFalse "[ -d output/input2 ]"
  assertTrue  "[ -f output/input3/file31.txt ]"
  assertFalse "[ -f output/input3/file32.txt ]"
  assertFalse "[ -f output/input3/file33.txt ]"
  
}

test_delete_files() {
  createTestData
  
  cp -r --parents "input1" "output"
  cp -r --parents "input2" "output"
  cp -r --parents "input3" "output"
  
  PACK_DELETE_FILES="
    input1/file11.txt
    input2/file22.txt
    input3/file33.txt
  "
  delete_files "output"

  assertFalse "[ -f output/input1/file11.txt ]"
  assertTrue  "[ -f output/input1/file12.txt ]"
  assertTrue  "[ -f output/input1/file13.txt ]"
  assertTrue  "[ -f output/input2/file21.txt ]"
  assertFalse "[ -f output/input2/file22.txt ]"
  assertTrue  "[ -f output/input2/file23.txt ]"
  assertTrue  "[ -f output/input3/file31.txt ]"
  assertTrue  "[ -f output/input3/file32.txt ]"
  assertFalse "[ -f output/input3/file33.txt ]"
}

test_apply_patches() {
  createTestData

  cp -r --parents "input1" "output"

  cat > file11.patch <<EOF
--- input1/file11.txt
+++ input1/file11.txt
@@ -1 +1 @@
-File 11
+File 11 extended version
EOF
  
  PACK_PATCH_FILES="
    file11.patch
  "
  apply_patches "output"
  
  assertEquals "$(cat "output/input1/file11.txt")" "File 11 extended version"
  assertEquals "$(cat "output/input1/file12.txt")" "File 12"
}

curl_mock() {
  CURL_MOCK_ARGS="$@"
  return ${UTILITY_CURL_RESULT:-0}
}

xmllint_mock() {
  XMLLINT_MOCK_ARGS="$@"
  return 0
}

test_check_schema() {
  cat > test.pdsc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
</package>
EOF

  UTILITY_CURL="curl_mock"
  UTILITY_XMLLINT="xmllint_mock"
  check_schema test.pdsc
  
  assertContains "${CURL_MOCK_ARGS[@]}" "https://url.to/schema/PACK.xsd"
  assertContains "${XMLLINT_MOCK_ARGS[@]}" "test.pdsc"
}

test_check_schema_nourl() {
  cat > test.pdsc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="PACK.xsd">
</package>
EOF

  UTILITY_CURL="curl_mock"
  UTILITY_CURL_RESULT=6
  UTILITY_XMLLINT="xmllint_mock"
  
  check_schema test.pdsc
  
  assertContains "${CURL_MOCK_ARGS[@]}" "PACK.xsd"
  assertNotContains "${XMLLINT_MOCK_ARGS[@]:-empty}" "test.pdsc"
}

packchk_mock() {
  PACKCHK_MOCK_ARGS="$@"
  return 0
}

test_check_pack() {
  touch test.pdsc
  
  CMSIS_PACK_ROOT="path/to/packs"
  UTILITY_PACKCHK="packchk_mock"
  check_pack test.pdsc
  
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "test.pdsc"  
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"  
}

test_create_sha1() {
  createTestData

  cp -r --parents "input1" "output"

  UTILITY_SHA1SUM="sha1sum"
    
  create_sha1 "output" "ARM" "GenPack"
  
  assertTrue     "[ -f output/ARM.GenPack.sha1 ]"
  assertContains "$(cat "output/ARM.GenPack.sha1")" "./input1/file11.txt"
  assertContains "$(cat "output/ARM.GenPack.sha1")" "./input1/file12.txt"
  assertContains "$(cat "output/ARM.GenPack.sha1")" "./input1/file13.txt"
  assertNotContains "$(cat "output/ARM.GenPack.sha1")" "./input2"
  assertNotContains "$(cat "output/ARM.GenPack.sha1")" "./input3"
}

. "$(dirname "$0")/shunit2/shunit2"
