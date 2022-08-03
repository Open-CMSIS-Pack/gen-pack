#!/bin/bash

shopt -s expand_aliases

git_changelog_mock() {

  cat <<EOF
<releases>
  <release version="1.2.3">
    Unit test change log
  </release>
</releases>
EOF
  return 0
}

alias git_changelog='git_changelog_mock'

. "$(dirname "$0")/../lib/pdsc"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null  
}

test_locate_pdsc_auto() {
  touch "ARM.GenPack.pdsc"

  local pdsc=$(locate_pdsc)
  
  assertEquals "$(readlink -f "$(pwd)/ARM.GenPack.pdsc")" "$pdsc"
}

test_locate_pdsc_specific() {
  touch "ARM.GenPack.pdsc"
  touch "ARM.GenPack2.pdsc"

  local pdsc=$(locate_pdsc "ARM.GenPack.pdsc")
  
  assertEquals "$(readlink -f "$(pwd)/ARM.GenPack.pdsc")" "$pdsc"
}

test_pdsc_vendor() {
  local vendor=$(pdsc_vendor "$(pwd)/ARM.GenPack.pdsc")
  assertEquals "ARM" "$vendor"
}

test_pdsc_name() {
  local name=$(pdsc_name "$(pwd)/ARM.GenPack.pdsc")
  assertEquals "GenPack" "$name"
}

test_pdsc_update_releases() {
  cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="0.0.0">
      Active development ...
    </release>
  </releases>
  
  <conditions>
    ...
  </conditions>
  
  <components>
   ...
  </components>
  
  ...
</package>
EOF

  mkdir -p output
    
  pdsc_update_releases "ARM.GenPack.pdsc" "output/ARM.GenPack.pdsc" "v"
  
  assertTrue "[ -f output/ARM.GenPack.pdsc ]"
  
  local pdsc=$(cat "output/ARM.GenPack.pdsc")
  assertContains    "${pdsc}"  "    <release version=\"1.2.3\">"
  assertNotContains "${pdsc}"  "<release version=\"0.0.0\">"
}

. "$(dirname "$0")/shunit2/shunit2"
