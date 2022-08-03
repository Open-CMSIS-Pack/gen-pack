#!/bin/bash

. "$(dirname "$0")/../lib/utilities"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null  

  OLD_PATH="$PATH"
  OLD_HOME="${HOME}"
  OLD_LOCALAPPDATA="${LOCALAPPDATA}"
  
  PATH="$(pwd):$PATH"
  HOME="$(pwd)"
  LOCALAPPDATA="$(pwd)"
  
  unset CMSIS_PACK_ROOT
}

tearDown() {
  PATH="${OLD_PATH}"
  HOME="${OLD_HOME}"
  LOCALAPPDATA="${OLD_LOCALAPPDATA}"
}

remove_path() {
  PATH=$(awk -v RS=: -v ORS=: '$0 != "'$1'"' <<<"$PATH" | sed 's/:$//')
}

add_path() {
  PATH="$1:$PATH"
}

remove_from_path() {
  # Remove all command executables from PATH
  while which $1 1>/dev/null 2>/dev/null; do
    local path="$(dirname $(which $1))"
    # echo "Un'PATH'ing ${path}..." >&2
    if [[ "${path}" == "/bin" || "${path}" == "/usr/bin" ]] ; then
      if [[ ! -d "$(pwd)${path}" ]]; then
        # echo "  Relocating ${path} to $(pwd)${path}..." >&2
        mkdir -p "$(pwd)${path}"
        find "${path}/" -executable -exec ln -s {} "$(pwd)${path}/" \;
        add_path "$(pwd)${path}"
      fi
      remove_path "${path}"
    elif [[ "${path}" == "$(pwd)/bin" || "${path}" == "$(pwd)/usr/bin" ]] ; then
      # echo "  Removing $1 from ${path}..." >&2
      rm "${path}/$1"
    else
      remove_path "${path}"
    fi
  done
}

test_get_os_type() {
  local OS_TYPE=$(get_os_type)
  local OS=$(uname -s)
  case $OS in
    'Linux')
      assertEquals $OS_TYPE "Linux64"
      ;;
    'WindowsNT'|MINGW*|CYGWIN*)
      assertEquals $OS_TYPE "Win32"
      ;;
    'Darwin')
      assertEquals $OS_TYPE "Darwin64"
      ;;
  esac
}

test_find_pack_root_by_env() {
  CMSIS_PACK_ROOT="$(pwd)/.packs"
  mkdir -p "${CMSIS_PACK_ROOT}"
  
  find_pack_root
  
  assertEquals "${CMSIS_PACK_ROOT}" "$(pwd)/.packs"
}

test_find_pack_root_by_default() {
  case $(uname -s) in
    'Linux'|'Darwin')
      local DEFAULT_CMSIS_PACK_ROOT="${HOME}/.arm/Packs"
      ;;
    'WindowsNT'|MINGW*|CYGWIN*)
      local DEFAULT_CMSIS_PACK_ROOT="${LOCALAPPDATA//\\//}/Arm/Packs"
      ;;
    *)
      echo "Error: unrecognized OS $OS"
      exit 1
      ;;
  esac  
  
  mkdir -p "${DEFAULT_CMSIS_PACK_ROOT}"
  
  find_pack_root
  
  assertEquals "${DEFAULT_CMSIS_PACK_ROOT}" "${CMSIS_PACK_ROOT}"
}

test_find_packchk_by_env() {
  cat > packchk <<EOF
#!/bin/sh
echo "packchk \$*"
EOF
  chmod +x packchk

  find_packchk
  
  assertEquals "$(pwd)/packchk" "${UTILITY_PACKCHK}"
}

test_find_packchk_by_pack() {
  CMSIS_PACK_ROOT="$(pwd)/.arm/Packs"
  local toolsdir="${CMSIS_PACK_ROOT}/ARM/CMSIS/5.9.0/CMSIS/Utilities/$(get_os_type)"
  
  mkdir -p "${toolsdir}"

  cat > "${toolsdir}/packchk" <<EOF
#!/bin/sh
echo "packchk \$*"
EOF
  chmod +x "${toolsdir}/packchk"

  remove_from_path "packchk"
  
  find_packchk
  
  assertEquals "${toolsdir}/packchk" "${UTILITY_PACKCHK}"
}

test_find_zip_7zip_env() {
  remove_from_path "7z"
  remove_from_path "zip"

  cat > "7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "7z"
  
  find_zip
  
  assertEquals "$(pwd)/7z" "${UTILITY_ZIP}"
  assertEquals "7zip" "${UTILITY_ZIP_TYPE}"
}

test_find_zip_7zip_default() {
  remove_from_path "7z"
  remove_from_path "zip"

  local programfiles="$(pwd)/Program Files"
  local zipdir="${programfiles}/7-Zip"
  PROGRAMFILES="$(sed -e 's~^/\([cd]\)/~\U\1:/~g' -e 's~/~\\~g' <<<${programfiles})"
  mkdir -p "${zipdir}"

  cat > "${zipdir}/7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "${zipdir}/7z"
      
  find_zip
  
  assertEquals "${zipdir}/7z" "${UTILITY_ZIP}"
  assertEquals "7zip" "${UTILITY_ZIP_TYPE}"
}

test_find_zip_gnuzip_env() {
  remove_from_path "7z"
  remove_from_path "zip"
  PROGRAMFILES=""

  cat > "zip" <<EOF
#!/bin/sh
echo "zip \$*"
EOF
  chmod +x "zip"

  find_zip
  
  assertEquals "$(pwd)/zip" "${UTILITY_ZIP}"
  assertEquals "zip" "${UTILITY_ZIP_TYPE}"
}

test_archive_7zip() {
  UTILITY_ZIP_TYPE="7zip"
  UTILITY_ZIP="$(pwd)/7z"

  cat > "7z" <<EOF
#!/bin/sh
echo "7z \$*"
EOF
  chmod +x "7z"
  
  mkdir "input"
  
  output=$(archive "$(pwd)/input" "$(pwd)/output/test.zip")
  
  assertContains "$output" "$(pwd)/input"
  assertContains "$output" "7z a -tzip $(pwd)/output/test.zip"
}

. "$(dirname "$0")/shunit2/shunit2"
