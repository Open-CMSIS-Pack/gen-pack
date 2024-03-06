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

shopt -s expand_aliases

curl_download_mock() {
  echo "curl_download $*"
  touch "${2}"
  return 0
}

git_changelog_mock() {

  echo "<!--"
  for f in "$@"; do
    echo "'$f'"
  done;
  echo "-->"
  cat <<EOF
<release version="1.2.3">
  Unit test change log:
</release>
EOF
  return 0
}

alias curl_download='curl_download_mock'
alias git_changelog='git_changelog_mock'

. "$(dirname "$0")/../lib/patches"
. "$(dirname "$0")/../lib/logging"
. "$(dirname "$0")/../lib/helper"
. "$(dirname "$0")/../lib/pdsc"

setUp() {
  VERBOSE=1

  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null || exit
}

test_locate_pdsc_auto() {
  touch "ARM.GenPack.pdsc"

  local pdsc
  pdsc=$(locate_pdsc)

  assertEquals "$(realpath ARM.GenPack.pdsc)" "$pdsc"
}

test_locate_pdsc_specific() {
  touch "ARM.GenPack.pdsc"
  touch "ARM.GenPack2.pdsc"

  local pdsc
  pdsc=$(locate_pdsc "ARM.GenPack.pdsc")

  assertEquals "$(realpath ARM.GenPack.pdsc)" "$pdsc"
}

test_pdsc_vendor() {
  local vendor
  vendor=$(pdsc_vendor "$(pwd)/ARM.GenPack.pdsc")
  assertEquals "ARM" "$vendor"
}

test_pdsc_name() {
  local name
  name=$(pdsc_name "$(pwd)/ARM.GenPack.pdsc")
  assertEquals "GenPack" "$name"
}

test_pdsc_release_desc() {
    cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="2.0.0">
      Active development...
      - Dev change log 1
      - Dev change log 2
    </release>
    <release version="1.0.0" date="2023-05-03">
      Release 1.0.0
      - Change log 1
      - Change log 2
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

  desc=$(pdsc_release_desc "ARM.GenPack.pdsc")

  assertEquals 0 $?
  assertContains    "${desc}"  "Active development..."
  assertContains    "${desc}"  "- Dev change log 1"
  assertContains    "${desc}"  "- Dev change log 2"
}

test_pdsc_release_desc_na() {
    cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="0.0.0"/>
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

  desc=$(pdsc_release_desc "ARM.GenPack.pdsc" 2>&1)
  assertNotEquals 0 $?
  assertContains "${desc}" "No release description found in ARM.GenPack.pdsc!"
}

test_pdsc_release_desc_nodev() {
    cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="1.0.0" date="2023-05-03">
      Release 1.0.0
      - Change log 1
      - Change log 2
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

  desc=$(pdsc_release_desc "ARM.GenPack.pdsc" 2>&1)
  assertNotEquals 0 $?
  assertContains "${desc}" "No release description found in ARM.GenPack.pdsc!"
}


test_pdsc_release_desc_exist() {
    cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="6.0.0">
      Active development...
      - Dev change log 1
      - Dev change log 2
    </release>
    <release version="5.9.0" date="2022-05-02">
      CMSIS-Core(M): 5.6.0
      CMSIS-DSP: 1.10.0 (see revision history for details)
    </release>
    <release version="5.8.0" date="2021-06-24">
      CMSIS-Core(M): 5.5.0 (see revision history for details)
      CMSIS-Core(A): 1.2.1 (see revision history for details)
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

  desc=$(pdsc_release_desc "ARM.GenPack.pdsc")

  assertEquals 0 $?
  assertContains    "${desc}"  "Active development..."
  assertContains    "${desc}"  "- Dev change log 1"
  assertContains    "${desc}"  "- Dev change log 2"
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
    <release version="0.0.0"/>
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

  local pdsc
  pdsc=$(cat "output/ARM.GenPack.pdsc")
  assertContains    "${pdsc}"  "    <release version=\"1.2.3\">"
  assertNotContains "${pdsc}"  "<release version=\"0.0.0\">"
}

test_pdsc_update_releases_with_devlog() {
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
      Active development...
      - Dev change log 1
      - Dev change log 2
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

  local pdsc
  pdsc=$(cat "output/ARM.GenPack.pdsc")
  assertContains    "${pdsc}"  "Active development..."
  assertContains    "${pdsc}"  "- Dev change log 1"
  assertContains    "${pdsc}"  "- Dev change log 2"
  assertContains    "${pdsc}"  "    <release version=\"1.2.3\">"
  assertNotContains "${pdsc}"  "<release version=\"0.0.0\">"
}

test_pdsc_update_releases_with_exist() {
  cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="6.0.0">
      Active development...
      - Dev change log 1
      - Dev change log 2
    </release>
    <release version="5.9.0" date="2022-05-02">
      CMSIS-Core(M): 5.6.0
      CMSIS-DSP: 1.10.0 (see revision history for details)
    </release>
    <release version="5.8.0" date="2021-06-24">
      CMSIS-Core(M): 5.5.0 (see revision history for details)
      CMSIS-Core(A): 1.2.1 (see revision history for details)
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

  local pdsc
  pdsc=$(cat "output/ARM.GenPack.pdsc")
  assertContains    "${pdsc}"  "Active development..."
  assertContains    "${pdsc}"  "- Dev change log 1"
  assertContains    "${pdsc}"  "- Dev change log 2"
  assertContains    "${pdsc}"  "    <release version=\"1.2.3\">"
  assertNotContains "${pdsc}"  "<release version=\"6.0.0\">"
  assertContains    "${pdsc}"  "    <release version=\"5.9.0\" date=\"2022-05-02\">"
  assertContains    "${pdsc}"  "    <release version=\"5.8.0\" date=\"2021-06-24\">"
}

test_pdsc_update_releases_with_exist_nodev() {
  cat > "ARM.GenPack.pdsc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package schemaVersion="1.7.7" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="https://url.to/schema/PACK.xsd">
  <vendor>ARM</vendor>
  <name>GenPack</name>
  <description>Test pack for GenPack library</description>
  <url>http://www.keil.com/pack/</url>
  <license>LICENSE</license>

  <releases>
    <release version="5.9.0" date="2022-05-02">
      CMSIS-Core(M): 5.6.0
      CMSIS-DSP: 1.10.0 (see revision history for details)
    </release>
    <release version="5.8.0" date="2021-06-24">
      CMSIS-Core(M): 5.5.0 (see revision history for details)
      CMSIS-Core(A): 1.2.1 (see revision history for details)
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

  local pdsc
  pdsc=$(cat "output/ARM.GenPack.pdsc")
  assertContains "${pdsc}"  "    <release version=\"1.2.3\">"
  assertContains "${pdsc}"  "    <release version=\"5.9.0\" date=\"2022-05-02\">"
  assertContains "${pdsc}"  "    <release version=\"5.8.0\" date=\"2021-06-24\">"
}

test_pdsc_assure_pack_webdir_noexist() {
  CMSIS_PACK_ROOT="path/to/packs"

  local webdir
  webdir=$(assure_pack_webdir)

  assertEquals "path/to/packs/.Web" "${webdir}"
  assertTrue "[ -w ${webdir} ]"
}

test_pdsc_assure_pack_webdir_writeable() {
  CMSIS_PACK_ROOT="path/to/packs"

  mkdir -p "${CMSIS_PACK_ROOT}"

  local webdir
  webdir=$(assure_pack_webdir)

  assertEquals "path/to/packs/.Web" "${webdir}"
  assertTrue "[ -w ${webdir} ]"
}

test_pdsc_assure_pack_webdir_writeprotect() {
  CMSIS_PACK_ROOT="path/to/packs"

  mkdir -p "${CMSIS_PACK_ROOT}"
  chmod a-w "${CMSIS_PACK_ROOT}"

  local webdir
  webdir=$(assure_pack_webdir)

  assertEquals "path/to/packs/.Web" "${webdir}"
  assertTrue "[ -d ${webdir} ]"
  
  if has_write_protect "${CMSIS_PACK_ROOT}" > /dev/null; then
    assertTrue "[ ! -w ${webdir} ]"
  fi

  chmod -R a+w "${CMSIS_PACK_ROOT}"
}

test_pdsc_cache_file() {
  CMSIS_PACK_ROOT="path/to/packs"
  
  local pdsc
  pdsc=$(pdsc_cache_file "ARM.CMSIS.pdsc")

  assertEquals "path/to/packs/.Web/ARM.CMSIS.pdsc" "${pdsc}"
}

test_pdsc_cache_file_with_path() {
  CMSIS_PACK_ROOT="path/to/packs"
  
  local pdsc
  pdsc=$(pdsc_cache_file "path/to/ARM.CMSIS.pdsc")

  assertEquals "path/to/packs/.Web/ARM.CMSIS.pdsc" "${pdsc}"
}

test_pdsc_cache_file_with_url() {
  CMSIS_PACK_ROOT="path/to/packs"
  
  local pdsc
  pdsc=$(pdsc_cache_file "http://path.to/ARM.CMSIS.pdsc")

  assertEquals "path/to/packs/.Web/ARM.CMSIS.pdsc" "${pdsc}"
}

test_pdsc_url() {
  CMSIS_PACK_ROOT="path/to/packs"
  local webdir="${CMSIS_PACK_ROOT}/.Web"

  mkdir -p "${webdir}"
  cat > "${webdir}/index.pidx" <<EOF
<<?xml version="1.0" encoding="UTF-8" ?> 
<index schemaVersion="1.1.0" xs:noNamespaceSchemaLocation="PackIndex.xsd" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance">
<vendor>Keil</vendor>
<url>https://www.keil.com/pack/</url>
<timestamp>2024-02-22T04:08:17.5071375+00:00</timestamp>
<pindex>
  <pdsc url="https://url.to/" vendor="ARM" name="CMSIS" version="6.0.0"/>
  <pdsc url="https://url.to" vendor="ARM" name="Test" version="1.2.3"/>
  <pdsc vendor="ARM" name="Nourl" version="1.1.0"/>
</pindex>
</index>
EOF

  assertEquals "https://url.to/ARM.CMSIS.pdsc" "$(pdsc_url "ARM.CMSIS.pdsc")"
  assertEquals "https://url.to/ARM.Test.pdsc" "$(pdsc_url "ARM.Test.pdsc")"
  assertEquals "file:/$(cwd)/path/to/Local.Pack.pdsc" "$(pdsc_url "path/to/Local.Pack.pdsc")"
  assertEquals "https://www.keil.com/pack/Local.Pack.pdsc" "$(pdsc_url "../invalid/path/to/Local.Pack.pdsc")"
  assertEquals "https://www.keil.com/pack/ARM.Nourl.pdsc" "$(pdsc_url "ARM.Nourl.pdsc")"
  assertEquals "https://www.keil.com/pack/Unknown.Pack.pdsc" "$(pdsc_url "Unknown.Pack.pdsc")"
  assertEquals "https://get.from/Somewhere.Else.pdsc" "$(pdsc_url "https://get.from/Somewhere.Else.pdsc")"
}

test_pdsc_url_without_index() {
  CMSIS_PACK_ROOT="path/to/packs"

  local url error
  url=$(pdsc_url "ARM.CMSIS.pdsc" 2>/dev/null)
  error=$(pdsc_url "ARM.CMSIS.pdsc" 2>&1 1>/dev/null)

  assertEquals "https://www.keil.com/pack/ARM.CMSIS.pdsc" "${url}"
  assertContains "${error}" "Pack index at 'path/to/packs/.Web/index.pidx' is not readable!"
}

test_fetch_pdsc_files() {
  CMSIS_PACK_ROOT="path/to/packs"
  local webdir="${CMSIS_PACK_ROOT}/.Web"

  mkdir -p "${webdir}"
  cat > "${webdir}/index.pidx" <<EOF
<<?xml version="1.0" encoding="UTF-8" ?> 
<index schemaVersion="1.1.0" xs:noNamespaceSchemaLocation="PackIndex.xsd" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance">
<vendor>Keil</vendor>
<url>https://www.keil.com/pack/</url>
<timestamp>2024-02-22T04:08:17.5071375+00:00</timestamp>
<pindex>
  <pdsc url="https://url.to/" vendor="ARM" name="CMSIS" version="6.0.0"/>
  <pdsc url="https://url.to" vendor="ARM" name="Test" version="1.2.3"/>
  <pdsc vendor="ARM" name="Nourl" version="1.1.0"/>
</pindex>
</index>
EOF

  chmod -R a-w "${CMSIS_PACK_ROOT}"

  local deps=("ARM.CMSIS.pdsc" "ARM.Test.pdsc" "ARM.Nourl.pdsc" "path/to/Local.Pack.pdsc")

  local result fetched=()
  result=$(fetch_pdsc_files fetched "${deps[@]}")

  assertContains "${result}" "curl_download https://url.to/ARM.CMSIS.pdsc path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${result}" "curl_download https://url.to/ARM.Test.pdsc path/to/packs/.Web/ARM.Test.pdsc"
  assertContains "${result}" "curl_download https://www.keil.com/pack/ARM.Nourl.pdsc path/to/packs/.Web/ARM.Nourl.pdsc"
  assertNotContains "${result}" "Local.Pack.pdsc"

  if has_write_protect "${CMSIS_PACK_ROOT}" > /dev/null; then
    assertTrue "[ ! -w path/to/packs/.Web/ARM.CMSIS.pdsc ]"
    assertTrue "[ ! -w path/to/packs/.Web/ARM.Test.pdsc ]"
    assertTrue "[ ! -w path/to/packs/.Web/ARM.Nourl.pdsc ]"
  fi

  fetch_pdsc_files fetched "${deps[@]}"
  assertContains "${fetched[*]}" "path/to/packs/.Web/ARM.CMSIS.pdsc"
  assertContains "${fetched[*]}" "path/to/packs/.Web/ARM.Test.pdsc"
  assertContains "${fetched[*]}" "path/to/packs/.Web/ARM.Nourl.pdsc"
  assertContains "${fetched[*]}" "path/to/Local.Pack.pdsc"

  chmod -R a+w "${CMSIS_PACK_ROOT}"
}

. "$(dirname "$0")/shunit2/shunit2"
