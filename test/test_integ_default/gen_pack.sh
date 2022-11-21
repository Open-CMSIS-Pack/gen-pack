#!/bin/bash
# Version: 2.4
# Date: 2022-11-21
# This bash script generates a CMSIS Software Pack:
#

set -o pipefail

# Set version of gen pack library
REQUIRED_GEN_PACK_LIB=""

# Set default command line arguments
DEFAULT_ARGS=()

# Pack warehouse directory - destination
PACK_OUTPUT=./output

# Temporary pack build directory
PACK_BUILD=./build

# Specify directory names to be added to pack base directory
PACK_DIRS=""

# Specify file names to be added to pack base directory
PACK_BASE_FILES="
  LICENSE
"

# Specify file names to be deleted from pack build directory
PACK_DELETE_FILES="
    doc/test.dxy
"

# Specify patches to be applied
PACK_PATCH_FILES="
    test.patch
"

# Specify addition argument to packchk
PACKCHK_ARGS=()

# Specify additional dependencies for packchk
PACKCHK_DEPS=""

# Optional: restrict fallback modes for changelog generation
# Default: full
# Values:
# - full      Tag annotations, release descriptions, or commit messages (in order)
# - release   Tag annotations, or release descriptions (in order)
# - tag       Tag annotations only
PACK_CHANGELOG_MODE="full"

# custom pre-processing steps
function preprocess() {
  # add custom steps here to be executed
  # before populating the pack build folder
  return 0
}

# custom post-processing steps
function postprocess() {
  # add custom steps here to be executed
  # after populating the pack build folder
  # but before archiving the pack into output folder
  return 0
}

############ DO NOT EDIT BELOW ###########

. "${GEN_PACK_LIB}/gen-pack"
gen_pack "${DEFAULT_ARGS[@]}" "$@"

exit 0
