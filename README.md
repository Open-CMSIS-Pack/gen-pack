[![License](https://img.shields.io/github/license/Open-CMSIS-Pack/gen-pack?label=License)](https://github.com/Open-CMSIS-Pack/gen-pack/blob/main/LICENSE)
[![Maintainability](https://qlty.sh/gh/Open-CMSIS-Pack/projects/gen-pack/maintainability.svg)](https://qlty.sh/gh/Open-CMSIS-Pack/projects/gen-pack)
[![Code Coverage](https://qlty.sh/gh/Open-CMSIS-Pack/projects/gen-pack/coverage.svg)](https://qlty.sh/gh/Open-CMSIS-Pack/projects/gen-pack)

# Bash library for gen-pack scripts

## About

This repository contains a library with helper function to assemble a
[`gen_pack.sh`](./template/gen_pack.sh) script that creates a
[Open-CMSIS-Pack](https://open-cmsis-pack.github.io/Open-CMSIS-Pack-Spec/main/html/index.html).

## Prerequisites

This library is written for Bash v5 or later and uses a couple of standard
\*nix commands:

- basename
- cp
- curl
- dirname
- dos2unix (optional)
- echo
- find
- git (optional)
- gh (optional)
- grep
- mac2unix (optional)
- mkdir
- mv
- patch (optional)
- realpath
- sed
- sha1sum
- tar
- test
- unix2dos (optional)
- unix2mac (optional)
- xmllint (optional)

In addition the `packchk` utility from [CMSIS-Toolbox](https://github.com/Open-CMSIS-Pack/cmsis-toolbox)
is required for verification.

### Linux

This library shall be well prepared to run on any standard Linux with Bash v5 or later.

```sh
$ sudo apt install \
    curl \
    libxml2-utils
```

### MacOS

This library requires Bash v5 and some additional GNU tools to be installed using [Homebrew](https://brew.sh/):

```sh
$ brew install \
    bash \
    coreutils \
    gnu-tar \
    grep
```

### Windows

The following tools need to be installed on Windows machines.

#### Bash v5

- [git for Windows](https://gitforwindows.org/) offers a Bash v5 compliant shell.
- Alternatively, you may use a [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/).

#### xmllint

xmllint is provided by the [Chocolatey](https://chocolatey.org/install) [xsltproc package](https://chocolatey.org/packages/xsltproc).
Installing choco and xsltproc can be done from an administrative PowerShell prompt:

```ps
> Set-ExecutionPolicy Bypass -Scope Process -Force
> [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
> iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
> choco install xsltproc
```

Alternatively, [xmllint](http://xmlsoft.org/xmllint.html) can be installed manually using the
[libxml library](https://www.zlatkovic.com/pub/libxml/). Download the following ZIP files:

- iconv-1.9.2.win32.zip
- libxml2-2.7.8.win32.zip
- libxmlsec-1.2.18.win32.zip
- zlib-1.2.5.win32.zip

Extract the /bin directory of each ZIP file to a directory, for example C:\xmllint and add this directory to the
Windows PATH environment variable.

#### 7-Zip

The compression tool [7-Zip](http://www.7-zip.org/) supports command line calls and can be used in generation scripts
like gen_pack.sh for automated pack file creation. Download the appropriate installer for your Windows system. Use
defaults for your installation.

## Get Started

In order to use this Bash library for your `gen_pack.sh` script you can use
the [template](template/gen_pack.sh) as a starting point.

All file references are evaluated relative to the `.pdsc` files parent directory, i.e. you
can use the same relative file names as within the `.pdsc` file.

1. Copy template

   Copy the [gen_pack.sh](template/gen_pack.sh) template into the root of your package source.

1. Set eXecute permission (**Windows only**!)

   Run `git update-index --chmod=+x gen_pack.sh` to set the eXecute permission. Otherwise
   the script will not be executable in a Linux/Mac checkout by default such as running in a GitHub Action.

1. Prepare variable `REQUIRED_GEN_PACK_LIB`

   Replace `<pin lib version here>` with the version of the library you want to use, e.g. `1.0.0`.

   For available versions see [Open-CMSIS-Pack/gen-pack/tags](https://github.com/Open-CMSIS-Pack/gen-pack/tags).

   Use the tag name without the prefix "v", e.g., 0.7.0

1. Prepare variable `DEFAULT_ARGS`

   Add any required default command line arguments to the line `DEFAULT_ARGS=()`.

   For example, add `-c [<prefix>]` here to force creating release history from Git.

   The `<prefix>` is the version prefixed used for release tags if any.

1. Prepare variable `PACK_OUTPUT`

   This variable holds the path for the output files relative to the script location.

1. Prepare variable `PACK_BUILD`

   This variable holds the path for the build files relative to the script location.

1. Prepare variable `PACK_DIRS`

   Replace `<list directories here>` with a list of directories that shall be included in the pack.

   The directories are included recursively with all contained files. If left empty (i.e. `PACK_DIRS=""`),
   all folders next to the `.pdsc` file are copied.

   Subdirectories (e.g., `path/to/folder`) are copied with same hierarchy
   (i.e., resulting in `<build>/path/to/folder/**/*`).

   Folders from outside the pack root (e.g., `../path/to/src`) are copied without hierarchy into the build
   folder (i.e., resulting in `<build>/src`).

   Files and folders used by common version control system (vsc) are ignored by default (`--exclude-vcs`).
   By providing a `.gpignore` file in any folder additional patterns can be excluded (`--exclude-ignore`).
   Find more details on the [tar manpage](https://www.gnu.org/software/tar/manual/html_node/exclude.html).

   For customizing the layout any further consider the `postprocess` hook.

1. Prepare variable `PACK_BASE_FILES`

   Replace `<list files here>` with a list of files that shall be included in the pack.

   This can be used as an alternative to including whole directories.
   Files from subdirectories (e.g., `path/to/file`) are copied with same hierarchy
   (i.e., resulting in `<build>/path/to/file`).

   Files from outside the pack root (e.g., `../path/to/file`) are copied without hierarchy into the build
   folder (i.e., resulting in `<build>/file`). For customizing the layout consider the `postprocess` hook.

1. Prepare variable `PACK_DELETE_FILES`

   Replace `<list files here>` with a list of files to be removed again.

   This can be used to copy whole directories and remove files afterwards.

1. Prepare variable `PACK_PATCH_FILES`

   Replace `<list patches here>` with a list of patches that shall be applied.
   The patch files are for use with the patch utility (see [Prerequisites](#prerequisites)).

1. Prepare variable `PACKCHK_ARGS`

   Add additional required command line arguments for packchk to the line `PACKCHK_ARGS=()`.

   For example, add `-x M353` to suppress this warning.

1. Prepare variable `PACKCHK_DEPS`

   Replace `<list pdsc files here>` with additional `.pdsc` files required to resolve references into
   other packs during `packchk`.

   The following formats can be used:

   - Plain `.pdsc` file looked up via `index.pidx`. File will be downloaded if not already in cache.
      E.g., `ARM.CMSIS.pdsc`.

   - Path to local `.pdsc` file relative to enclosing `gen_pack.sh`.
      E.g., `./path/to/Local.Pack.pdsc`. Relative or absolute paths leaving the scripts base directory
      are not accepted for security reasons.

   - URL to remote `.pdsc` file. File will be downloaded if not already in cache.
      E.g., `https://url.to/Remove.Pack.pdsc`.

   Packs specified in the `<requirements>` section are considered automatically and do not need to be listed.

1. Prepare variable `PACK_CHANGELOG_MODE`

   Replace `<full|release|tag|pdsc>` for `PACK_CHANGELOG_MODE` with one of these choices.
   It defaults to `full`. This setting selects the changelog source and the allowed Git fallbacks:

   `full` uses tag annotations with fallback to GitHub release descriptions or commit messages.

   `release` uses tag annotations with fallback to GitHub release descriptions only.

   `tag` forces tag annotation messages to be used without any fallback.

   `pdsc` keeps the PDSC release history unchanged

   ```sh
   PACK_CHANGELOG_MODE="pdsc"
   ```

   For `PACK_CHANGELOG_MODE="pdsc"` one can use `--mode [prepare|build|finalize]` to
   run the 3-steps pack release.

   `prepare` bumps the latest release tag in the pdsc file to the release, combine with
   `--version`, `--date`, and `--url` to set release tag attributes specifically. Add
   `--commit` and `--tag` to automatically commit the updated pdsc and set the release
   version tag.

   `build` just generates the pack archive as usual, can be omitted as its the default.

   `finalize` adds a new `-dev` release tag on top of the releases history. Combine with
   `version` to set a specific version attribute. Add `--commit` and `--tag` to automatically
   commit the updated pdsc and set the dev version tag.

1. Prepare variable `PACK_CHECKSUM_EXCLUDE`

   Replace `<list file patterns here>` for `PACK_CHECKSUM_EXCLUDE` wit glob patterns to exclude files from the
   checksum file, or provide `*` (match all pattern) to skip checksum file creation completely.

1. Prepare functions `preprocess`, `postprocess`

   Put custom commands to be executed before/after populating the pack build folder
   into the `preprocess` and `postprocess` functions. The working directory (`pwd`) for
   both functions is the base folder containing the pack description file. The first
   parameter of the functions (`$1`) points to the build folder.

   For example, if you need to customize the folder structure generated by default, add
   some move commands into the `postprocess` hook:

   ```bash
   # usage: postprocess <build>
   #   <build>  The build folder
   function postprocess() {
      mkdir -p $1/lib
      mv $1/src $1/lib/
      return 0
   }
   ```

## Usage

A `gen_pack.sh` script accepts the following command line flags and arguments:

- `-h, --help`: Prints below usage message end exits with error level 1.
- `-k, --keep`: Prevents the temporary build directory from being automatically deleted.
- `-c, --[no-]changelog <prefix>`: Update the `<releases>` section in the `.pdsc` file with a generated history. The
                                   versions, dates and descriptions are inferred from Git tags. The `<prefix>` can be
                                   used to filter tags for release tags by the given string.
- `--[no-]preprocess`: Run custom preprocess function if implemented.
- `--[no-]postproces`: Run custom postprocess function if implemented.
- `-v, --verbose`: Enable verbose log output such as full sub-commands being issues.

```sh
$ ./gen_pack.sh -h

Usage: gen_pack.sh [-h] [-k] [-c <prefix>] [<pdsc>]

Arguments:
  -h, --help                      Print this usage message and exit.
  -k, --keep                      Keep build directory.
  -c, --[no-]changelog <prefix>   Generate changelog. Tags are filtered for <prefix>.
  --[no-]preprocess               Run the preprocess function if implemented in the enclosing script.
  --[no-]postproces               Run the postprocess function if implemented in the enclosing script.
  -v, --verbose                   Print verbose log output.
  <pdsc>                          The pack description to generate the pack for.
```

## Source-PDSC release workflow

To keep the tagged source PDSC identical to the PDSC shipped in a pack,
set `PACK_CHANGELOG_MODE="pdsc"` in your `gen_pack.sh` script. This enables the
three release modes below; omitting `--mode` defaults to `build`. The Git source
modes (`full`, `release`, and `tag`) retain the existing build behavior and reject
explicit release modes.

```sh
# Prepare the first, undated release entry; keep its prepared changelog text.
./gen_pack.sh --mode prepare --version 1.2.3 --date 2026-10-22 \
  --url https://example.com/releases/1.2.3 --tag -c v

# Build from that exact PDSC; --mode build is the default for pdsc.
./gen_pack.sh

# After publishing, start development of 1.2.4-dev and commit the change.
./gen_pack.sh --mode finalize --commit
```

- `prepare` updates the first `<release>` in the source PDSC. It must have no
  `date` attribute. `--version` overrides its version; otherwise all prerelease and
  build suffixes are removed. `--date` defaults to today's local calendar date.
  `--url` is optional; without it, the entry has no release URL. Existing release
  notes and older releases are preserved.
- `build` is the default when `PACK_CHANGELOG_MODE="pdsc"`. It uses the source
  PDSC unchanged, even if `DEFAULT_ARGS` contains `-c`.
  Existing build hooks and patches still run. If they change the source or built
  PDSC, generation fails before archiving. No Git or GitHub CLI is needed for
  changelog generation in this mode.
- `finalize` closes the release workflow and requires a dated first release.
  It prepends a new undated entry
  with the patch version incremented and `-dev` appended, and the text
  `Active development ...`. Use `--version 1.3.0` or `--version 1.3.0-dev` to
  override the next version; its base version must be higher than the release.
  The new entry has no `date` or `url` attributes. With `--tag`, its `tag`
  attribute names the new development tag; otherwise that attribute is omitted.

Prepare and finalize require `xmllint` but do not run build hooks, `packchk`,
or schema downloads. Without Git options, they only edit the PDSC. Use `--commit`
to commit that change. Both modes accept `--tag [<name>]`, which includes the
commit and creates an annotated tag with the updated PDSC's first release
description as its message. For finalize, the tag points to the new development
commit and uses the new entry's `Active development ...` text. An explicit tag
name wins; otherwise the name is `<prefix><version>`, including the `-dev` suffix
for finalize. `-c <prefix>` supplies the prefix (empty by default):

```sh
./gen_pack.sh --mode prepare --tag custom-release-name
./gen_pack.sh --mode prepare --tag -c v
./gen_pack.sh --mode prepare --tag -- Vendor.Pack.pdsc
./gen_pack.sh --mode finalize --tag -c v
```

After `--tag`, a token ending in `.pdsc` is interpreted as the PDSC path. Use
`--tag=<name>` to specify a tag name ending in `.pdsc`. Options may precede or
follow the explicit tag name. The generated tag name is also stored in the
updated PDSC's first release `tag` attribute; without `--tag`, that attribute is omitted.

Automatic commits require the PDSC to be tracked and all other tracked files to
be clean, including the index; unrelated untracked files are allowed. Existing
tags are never replaced. A commit failure retains the edited PDSC for inspection;
a tag failure retains the successful commit. No commits or tags are pushed.
Publishing the release and invoking finalize remain the caller's responsibility.

## GitHub Integration

### Open-CMSIS-Pack/gen-pack-action

For running Bash scripts based on gen-pack library within a GitHub Action workflow one could rely on the reusable
action available at [Open-CMSIS-Pack/gen-pack-action](https://github.com/Open-CMSIS-Pack/gen-pack-action).

### Auto-update library reference

Once a new version of the gen-pack library is released, one need to update all scripts `REQUIRED_GEN_PACK_LIB``
variable to make use of the new version. This can be semi-automated via the shared workflow provided in
[update-lib.yml](https://github.com/Open-CMSIS-Pack/gen-pack/blob/update-scripts-workflow/.github/workflows/update-lib.yml).

This shared workflow can be run within the user's repo via a cron schedule:

```yml
name: Update library in gen-pack scripts
on:
  workflow_dispatch:
  schedule:
    - cron: "30 9 * * *"

permissions:
  contents: write
  pull-requests: write

jobs:
  update-workflows:
    uses: Open-CMSIS-Pack/gen-pack/.github/workflows/update-lib.yml@update-scripts-workflow
    secrets:
      TOKEN_ACCESS: ${{ secrets.TOKEN_WORKFLOW_UPDATE }}
```

The workflow requires write permissions the default `GITHUB_TOKEN` does not have for
security reasons. Hence, one needs to register Personal Access Token as a repository secret, which has

- Contents: read and write
- Pull requests: read and write

## License

This library is made available as-is under Apache-2.0 license.

