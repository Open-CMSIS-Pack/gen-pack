#!/bin/bash

. "$(dirname "$0")/../gen-pack"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null

  PACK_BUILD="$(realpath ./build)"
  PACK_OUTPUT="$(realpath ./output)"
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
  mkdir -p input4/test
  mkdir -p ../input5

  echo "File 11" > input1/file11.txt
  echo "File 12" > input1/file12.txt
  echo "File 13" > input1/file13.txt
  echo "File 21" > input2/file21.txt
  echo "File 22" > input2/file22.txt
  echo "File 23" > input2/file23.txt
  echo "File 31" > input3/file31.txt
  echo "File 32" > input3/file32.txt
  echo "File 33" > input3/file33.txt
  echo "File 41" > input4/test/file41.txt
  echo "File 51" > ../input5/file51.txt

  # create a target folder
  mkdir -p "${PACK_BUILD}"
}

test_add_dirs() {
  createTestData

  # run add_dirs
  PACK_DIRS="
    input1
    input2
    input4/test
    ../input5
  "
  add_dirs "${PACK_BUILD}"

  assertTrue  "[ -d \"${PACK_BUILD}/input1\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file11.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file12.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file13.txt\" ]"
  assertTrue  "[ -d \"${PACK_BUILD}/input2\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file21.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file22.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file23.txt\" ]"
  assertFalse "[ -d \"${PACK_BUILD}/input3\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input4/test/file41.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input5/file51.txt\" ]"
}

test_add_dirs_default() {
  createTestData

  # run add_dirs
  PACK_DIRS=""
  add_dirs "${PACK_BUILD}"

  assertTrue  "[ -d \"${PACK_BUILD}/input1\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file11.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file12.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file13.txt\" ]"
  assertTrue  "[ -d \"${PACK_BUILD}/input2\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file21.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file22.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file23.txt\" ]"
  assertTrue  "[ -d \"${PACK_BUILD}/input3\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file31.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file32.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file33.txt\" ]"
}

test_add_files() {
  createTestData

  # run add_dirs
  PACK_BASE_FILES="
    input1/file12.txt
    input3/file31.txt
    ../input5/file51.txt
  "
  add_files "${PACK_BUILD}"

  assertFalse "[ -f \"${PACK_BUILD}/input1/file11.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file12.txt\" ]"
  assertFalse "[ -f \"${PACK_BUILD}/input1/file13.txt\" ]"
  assertFalse "[ -d \"${PACK_BUILD}/input2\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file31.txt\" ]"
  assertFalse "[ -f \"${PACK_BUILD}/input3/file32.txt\" ]"
  assertFalse "[ -f \"${PACK_BUILD}/input3/file33.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/file51.txt\" ]"
}

test_delete_files() {
  createTestData

  cp -r --parents "input1" "${PACK_BUILD}"
  cp -r --parents "input2" "${PACK_BUILD}"
  cp -r --parents "input3" "${PACK_BUILD}"

  PACK_DELETE_FILES="
    input1/file11.txt
    input2/file22.txt
    input3/file33.txt
  "
  delete_files "${PACK_BUILD}"

  assertFalse "[ -f \"${PACK_BUILD}/input1/file11.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file12.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input1/file13.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file21.txt\" ]"
  assertFalse "[ -f \"${PACK_BUILD}/input2/file22.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input2/file23.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file31.txt\" ]"
  assertTrue  "[ -f \"${PACK_BUILD}/input3/file32.txt\" ]"
  assertFalse "[ -f \"${PACK_BUILD}/input3/file33.txt\" ]"
}

test_apply_patches() {
  createTestData

  cp -r --parents "input1" "${PACK_BUILD}"

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
  apply_patches "${PACK_BUILD}"

  assertEquals "$(cat "${PACK_BUILD}/input1/file11.txt")" "File 11 extended version"
  assertEquals "$(cat "${PACK_BUILD}/input1/file12.txt")" "File 12"
}

curl_mock() {
  CURL_MOCK_ARGS="$@"
  echo "curl_mock $@"
  local result=${UTILITY_CURL_RESULT[0]:-0}
  UTILITY_CURL_RESULT=(${UTILITY_CURL_RESULT[@]:1})
  return $result
}

xmllint_mock() {
  XMLLINT_MOCK_ARGS="$@"
  echo "xmllint_mock $@"
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

test_check_schema_nourl_version() {
  cat > test.pdsc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="PACK.xsd">
</package>
EOF

  UTILITY_CURL="curl_mock"
  UTILITY_CURL_RESULT=(6 0)
  UTILITY_XMLLINT="xmllint_mock"

  result=$(check_schema test.pdsc 2>&1)
  errorlevel=$?

  echo "$result"

  assertEquals 0 $errorlevel
  assertContains "${result}" "Failed downloading file from URL 'PACK.xsd'."
  assertContains "${result}" "curl_mock -sL https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/v1.7.7/schema/PACK.xsd"
  assertNotContains "${result}" "Failed downloading file from URL 'https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/v1.7.7/schema/PACK.xsd'."
  assertContains "${result}" "xmllint_mock"
}

test_check_schema_nourl_main() {
  cat > test.pdsc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="PACK.xsd">
</package>
EOF

  UTILITY_CURL="curl_mock"
  UTILITY_CURL_RESULT=(6 6 0)
  UTILITY_XMLLINT="xmllint_mock"

  result=$(check_schema test.pdsc 2>&1)
  errorlevel=$?

  echo "$result"

  assertEquals 0 $errorlevel
  assertContains "${result}" "Failed downloading file from URL 'PACK.xsd'."
  assertContains "${result}" "Failed downloading file from URL 'https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/v1.7.7/schema/PACK.xsd'."
  assertContains "${result}" "curl_mock -sL https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/main/schema/PACK.xsd"
  assertNotContains "${result}" "Failed downloading file from URL 'https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/main/schema/PACK.xsd'."
  assertContains "${result}" "xmllint_mock"
}

test_check_schema_noschema() {
  cat > test.pdsc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="PACK.xsd">
</package>
EOF

  UTILITY_CURL="curl_mock"
  UTILITY_CURL_RESULT=(6 6 6)
  UTILITY_XMLLINT="xmllint_mock"

  result=$(check_schema test.pdsc 2>&1)
  errorlevel=$?

  echo "$result"

  assertNotEquals 0 $errorlevel
  assertContains "${result}" "Failed downloading file from URL 'PACK.xsd'."
  assertContains "${result}" "Failed downloading file from URL 'https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/v1.7.7/schema/PACK.xsd'."
  assertContains "${result}" "Failed downloading file from URL 'https://github.com/Open-CMSIS-Pack/Open-CMSIS-Pack-Spec/blob/main/schema/PACK.xsd'."
  assertNotContains "${result}" "xmllint_mock"
}

packchk_mock() {
  PACKCHK_MOCK_ARGS="$@"
  return 0
}

test_check_pack() {
  touch test.pdsc

  CMSIS_PACK_ROOT="path/to/packs"
  UTILITY_PACKCHK="packchk_mock"
  UTILITY_CURL="curl_mock"
  check_pack test.pdsc

  assertContains "${PACKCHK_MOCK_ARGS[@]}" "test.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"
}

test_check_pack_with_args() {
  touch test.pdsc

  CMSIS_PACK_ROOT="path/to/packs"
  UTILITY_PACKCHK="packchk_mock"
  UTILITY_CURL="curl_mock"
  PACKCHK_ARGS=(-x M300)
  check_pack test.pdsc

  assertContains "${PACKCHK_MOCK_ARGS[@]}" "test.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "-x"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "M300"
}

test_check_pack_with_reqs() {
  cat > test.pdsc <<EOF
    <package vendor="Keil" name="ARM_Compiler" version="1.6.2-0"/>
EOF

  CMSIS_PACK_ROOT="path/to/packs"
  UTILITY_PACKCHK="packchk_mock"
  UTILITY_CURL="curl_mock"
  check_pack test.pdsc

  assertContains "${PACKCHK_MOCK_ARGS[@]}" "test.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/Keil.ARM_Compiler.pdsc"

  result=$(check_pack test.pdsc)
  assertContains "${result}" "curl_mock -sL https://www.keil.com/pack/ARM.CMSIS.pdsc --output path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${result}" "curl_mock -sL https://www.keil.com/pack/Keil.ARM_Compiler.pdsc --output path/to/packs/.Web/Keil.ARM_Compiler.pdsc"
}

test_check_pack_with_deps() {
  touch test.pdsc

  CMSIS_PACK_ROOT="path/to/packs"
  UTILITY_PACKCHK="packchk_mock"
  UTILITY_CURL="curl_mock"
  PACKCHK_DEPS="Keil.ARM_Compiler.pdsc"
  check_pack test.pdsc

  assertContains "${PACKCHK_MOCK_ARGS[@]}" "test.pdsc"
  assertNotContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${PACKCHK_MOCK_ARGS[@]}" "path/to/packs/.Web/Keil.ARM_Compiler.pdsc"

  result=$(check_pack test.pdsc)
  assertNotContains "${result}" "curl_mock -sL https://www.keil.com/pack/ARM.CMSIS.pdsc --output path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${result}" "curl_mock -sL https://www.keil.com/pack/Keil.ARM_Compiler.pdsc --output path/to/packs/.Web/Keil.ARM_Compiler.pdsc"
}

test_create_sha1() {
  createTestData

  cp -r --parents "input1" "${PACK_BUILD}"

  UTILITY_SHA1SUM="sha1sum"

  create_sha1 "${PACK_BUILD}" "ARM" "GenPack"

  assertTrue     "[ -f \"${PACK_BUILD}/ARM.GenPack.sha1\" ]"
  assertContains "$(cat "${PACK_BUILD}/ARM.GenPack.sha1")" "./input1/file11.txt"
  assertContains "$(cat "${PACK_BUILD}/ARM.GenPack.sha1")" "./input1/file12.txt"
  assertContains "$(cat "${PACK_BUILD}/ARM.GenPack.sha1")" "./input1/file13.txt"
  assertNotContains "$(cat "${PACK_BUILD}/ARM.GenPack.sha1")" "./input2"
  assertNotContains "$(cat "${PACK_BUILD}/ARM.GenPack.sha1")" "./input3"
}

. "$(dirname "$0")/shunit2/shunit2"
