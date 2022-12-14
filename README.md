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
- echo
- find
- git (optional)
- gh (optional)
- grep
- mkdir
- mv
- realpath
- sed
- sha1sum
- test
- xmllint

### Linux

This library shall be well prepared to run on any standard Linux with Bash v5 or later.

```sh
$ sudo apt install \
    curl \
    libxml2-utils
```

### MacOS

This library requires Bash and some additional GNU tools to be installed using [Homebrew](https://brew.sh/):

```sh
$ brew install \
    coreutils \
    grep
```

### Windows

The following tools need to be installed on Windows machines.

#### Bash v5

- [git for Windows](https://gitforwindows.org/) offers a Bash v5 compliant shell.
- Alternatively, you may use a [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/).

#### xmllint

[xmllint](http://xmlsoft.org/xmllint.html) can be installed using the
[libxml library](https://www.zlatkovic.com/pub/libxml/). Download the following ZIP files:

- iconv-1.9.2.win32.zip
- libxml2-2.7.8.win32.zip
- libxmlsec-1.2.18.win32.zip
- zlib-1.2.5.win32.zip

Extract the /bin directory of each ZIP file to a directory, for example C:\xmllint and add this directory to the
Windows PATH environment variable.

Alternatively, xmllint is also provided by the [Chocolatey xsltproc package](https://chocolatey.org/packages/xsltproc):

```ps
> choco install xsltproc
```

#### 7-Zip

The compression tool [7-Zip](http://www.7-zip.org/) supports command line calls and can be used in generation scripts
like gen_pack.sh for automated pack file creation. Download the appropriate installer for your Windows system. Use
defaults for your installation.

## Get Started

In order to use this Bash library for your `gen_pack.sh` script you can use
the [template](template/gen_pack.sh) as a starting point.

All file references are evaluated relative to the `.pdsc` files parent directory, i.e. you
can use the same relative file names as within the `.pdsc` file.

1. Put the [template](template/gen_pack.sh) into the root of your package source.
1. Replace `<pin lib version here>` with the version of the library you want to use, e.g. `1.0.0`.
1. Add any required default command line arguments to the line `DEFAULT_ARGS=()`.
   For example, add `-c [<prefix>]` here to force creating release history from Git.
   The `<prefix>` is the version prefixed used for release tags if any.
1. Replace `<list directories here>` with a list of directories that shall be included in the pack.
   The directories are included recursively with all contained files. If left empty (i.e. `PACK_DIRS=""`),
   all folders next to the `.pdsc` file are copied.
1. Replace `<list files here>` with a list of files that shall be included in the pack.
   This can be used as an alternative to including whole directories.
1. Replace `<list files here>` with a list of files to be removed again.
   This can be used to copy whole directories and remove files afterwards.
1. Replace `<list patches here>` with a list of patches that shall be applied.
1. Add additional required command line arguments for packchk to the line `PACKCHK_ARGS=()`.
   For example, add `-x M353` to suppress this warning.
1. Replace `<list pdsc files here>` with additional `.pdsc` files required to resolve references into other packs.
   Packs specified in the `<requirements>` section are considered automatically and do not need to be listed.
   For example, add `ARM.CMSIS.pdsc` to include this file during packchk. The `.pdsc` files are referenced from
   `${CMSIS_PACK_ROOT}/.Web` folder. Missing files are downloaded.
1. Replace `<full|release|tag>` for `PACK_CHANGELOG_MODE` with either of these choices. It defaults to `full`. This setting
   is only effective when generating the changelog from Git history. It affects the fallback solutions
   used to retrieve the changelog text from git:

   `full` allows fallback to GitHub release description or commit message.

   `release` allows fallback to GitHub release description only.

   `tag` forces tag annotation messages to be used without any fallback.

   If no changelog text can be retrieved pack generation is aborted.
1. Put custom commands to be executed before/after populating the pack build folder
   into the `preprocess` and `postprocess` functions.

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
