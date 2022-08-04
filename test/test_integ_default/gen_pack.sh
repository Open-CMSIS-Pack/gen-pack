#!/bin/bash
# Version: 2.0
# Date: 2022-07-28
# This bash script generates a CMSIS Software Pack:
#

set -o pipefail

# Set version of gen pack library
REQUIRED_GEN_PACK_LIB="0.1.0"

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

############ DO NOT EDIT BELOW ###########

. "$(dirname "$0")/../../gen-pack"
gen_pack "${DEFAULT_ARGS[@]}" "$@"

exit 0
