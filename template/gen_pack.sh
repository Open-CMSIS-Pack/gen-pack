#!/bin/bash
# Version: 2.3
# Date: 2022-09-28
# This bash script generates a CMSIS Software Pack:
#

set -o pipefail

# Set version of gen pack library
REQUIRED_GEN_PACK_LIB="<pin lib version here>"

# Set default command line arguments
DEFAULT_ARGS=()

# Pack warehouse directory - destination
PACK_OUTPUT=./output

# Temporary pack build directory
PACK_BUILD=./build

# Specify directory names to be added to pack base directory
PACK_DIRS="
    <list directories here>
"

# Specify file names to be added to pack base directory
PACK_BASE_FILES="
  LICENSE
  <list files here>
"

# Specify file names to be deleted from pack build directory
PACK_DELETE_FILES="
    <list files here>
"

# Specify patches to be applied
PACK_PATCH_FILES="
    <list patches here>
"

# Specify addition argument to packchk
PACKCHK_ARGS=()

# Specify additional dependencies for packchk
PACKCHK_DEPS="
    <list pdsc files here>
"

# Optional: restrict fallback modes for changelog generation
# Default: full
# Values:
# - full      Tag annotations, release descriptions, or commit messages (in order)
# - release   Tag annotations, or release descriptions (in order)
# - tag       Tag annotations only
PACK_CHANGELOG_MODE="<full|release|tag>"

# custom pre-processing steps
function preprocess() {
  # add custom steps here to be executed
  # before populating the pack build folder
}

# custom post-processing steps
function postprocess() {
  # add custom steps here to be executed
  # after populating the pack build folder
  # but before archiving the pack into output folder
}

############ DO NOT EDIT BELOW ###########

function install_lib() {
  local URL="https://github.com/Open-CMSIS-Pack/gen-pack/archive/refs/tags/v$1.tar.gz"
  echo "Downloading gen-pack lib to '$2'"
  mkdir -p "$2"
  curl -L "${URL}" -s | tar -xzf - --strip-components 1 -C "$2" || exit 1
}

function load_lib() {
  if [[ -d ${GEN_PACK_LIB} ]]; then
    . "${GEN_PACK_LIB}/gen-pack"
    return 0
  fi
  local GLOBAL_LIB="/usr/local/share/gen-pack/${REQUIRED_GEN_PACK_LIB}"
  local USER_LIB="${HOME}/.local/share/gen-pack/${REQUIRED_GEN_PACK_LIB}"
  if [[ ! -d "${GLOBAL_LIB}" && ! -d "${USER_LIB}" ]]; then
    echo "Required gen_pack lib not found!" >&2
    install_lib "${REQUIRED_GEN_PACK_LIB}" "${USER_LIB}"
  fi

  if [[ -d "${GLOBAL_LIB}" ]]; then
    . "${GLOBAL_LIB}/gen-pack"
  elif [[ -d "${USER_LIB}" ]]; then
    . "${USER_LIB}/gen-pack"
  else
    echo "Required gen-pack lib is not installed!" >&2
    exit 1
  fi
}

load_lib
gen_pack "${DEFAULT_ARGS[@]}" "$@"

exit 0
