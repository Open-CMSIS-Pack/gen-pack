# Bash library for gen-pack scripts

## About

This repository contains a library with helper function to assemble a
`gen_pack.sh` script like this:

```sh
#!/bin/bash
# Version: 2.0
# Date: 2022-07-28
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

############ DO NOT EDIT BELOW ###########

function install_lib() {
  local URL="https://github.com/Open-CMSIS-Pack/gen-pack/archive/refs/tags/v$1.tar.gz"
  echo "Downloading gen-pack lib to '$2'"
  mkdir -p "$2"
  curl -L "${URL}" -s | tar -xzf - --strip-components 1 -C "$2" || exit 1
}

function load_lib() {
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

```

## Prerequisites

This library is written for Bash v5 or later and uses a couple of standard
\*nix commands:

- basename
- cp
- curl
- dirname
- echo
- find
- grep
- mkdir
- mv
- sed
- test


### Linux

This library shall be well prepared to run on any standard Linux with Bash v5 or later.

### Windows

This library requires Bash for Windows v5 or later.

### MacOS

This library requires Bash and some additional GNU tools:

```bash
$ brew install coreutils grep 
```

## Get Started

In order to use this Bash library for your `gen_pack.sh` script you can use
the [template](template/gen_pack.sh) as a starting point.

1. Put the [template](template/gen_pack.sh) into the root of your package source.
2. Replace `<pin lib version here>` with the version of the library you want to use, e.g. `1.0.0`.
3. Replace `<list directories here>` with a list of directories that shall be included in the pack.
   The directories are included recursively with all contained files.
4. Replace `<list files here>` with a list of files that shall be included in the pack.
   This can be used as an alternative to including whole directories.
5. Replace `<list files here>` with a list of files to be removed again.
   This can be used to copy whole directories and remove files afterwards.
6. Replace `<list patches here>` with a list of patches that shall be applied.
7. Add any required default command line arguments to the line `DEFAULT_ARGS=()`.
   For example, add `-c [<prefix>]` here to force creating release history from Git.
   The `<prefix>` is the version prefixed used for release tags if any.

## License

This library is made available as-is under Apache-2.0 license.
