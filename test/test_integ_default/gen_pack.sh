#!/usr/bin/env bash
# Version: 2.7
# Date: 2023-05-22
# This bash script generates a CMSIS Software Pack:
#

set -o pipefail

# Set version of gen pack library
# For available versions see https://github.com/Open-CMSIS-Pack/gen-pack/tags.
# Use the tag name without the prefix "v", e.g., 0.7.0
REQUIRED_GEN_PACK_LIB=""

# Set default command line arguments
DEFAULT_ARGS=()

# Pack warehouse directory - destination
# Default: ./output
#
# PACK_OUTPUT=./output

# Temporary pack build directory,
# Default: ./build
#
# PACK_BUILD=./build

# Specify directory names to be added to pack base directory
# An empty list defaults to all folders next to this script.
# Default: empty (all folders)
#
# PACK_DIRS="
#   <list directories here>
# "

# Specify file names to be added to pack base directory
# Default: empty
#
PACK_BASE_FILES="
  LICENSE
"

# Specify file names to be deleted from pack build directory
# Default: empty
#
PACK_DELETE_FILES="
  doc/test.dxy
"

# Specify patches to be applied
# Default: empty
#
PACK_PATCH_FILES="
  test.patch
"

# Specify addition argument to packchk
# Default: empty
#
# PACKCHK_ARGS=()

# Specify additional dependencies for packchk
# Default: empty
#
# PACKCHK_DEPS="
#   <list pdsc files here>
# "

# Optional: restrict fallback modes for changelog generation
# Default: full
# Values:
# - full      Tag annotations, release descriptions, or commit messages (in order)
# - release   Tag annotations, or release descriptions (in order)
# - tag       Tag annotations only
#
# PACK_CHANGELOG_MODE="<full|release|tag>"

#
# custom pre-processing steps
#
# usage: preprocess <build>
#   <build>  The build folder
#
function preprocess() {
  # add custom steps here to be executed
  # before populating the pack build folder
  return 0
}

#
# custom post-processing steps
#
# usage: postprocess <build>
#   <build>  The build folder
#
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
