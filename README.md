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

   Replace `<full|release|tag>` for `PACK_CHANGELOG_MODE` with either of these choices.
   It defaults to `full`. This setting is only effective when generating the changelog from Git history.
   It affects the fallback solutions used to retrieve the changelog text from git:

   `full` allows fallback to GitHub release description or commit message.

   `release` allows fallback to GitHub release description only.

   `tag` forces tag annotation messages to be used without any fallback.

   If no changelog text can be retrieved pack generation is aborted.

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

## License

This library is made available as-is under Apache-2.0 license.
