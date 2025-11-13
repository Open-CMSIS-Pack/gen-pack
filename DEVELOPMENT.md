# Development Guide for gen-pack

This document describes how to set up your local development environment, build and test changes for **gen-pack**.

## Prerequisites

- Bash version 5 or later. (The library is written for Bash v5+.)  
- Standard Unix tools: `basename`, `cp`, `curl`, `dirname`, `grep`, `find`, `realpath`, `tar`, `sha1sum`, etc.
- Optional tools:
  - `dos2unix`, `mac2unix` (for Windows/mac file handling)  
  - `xmllint` (optional)  
  - `git`, `gh` (optional)  
- On macOS: install GNU versions of utilities if required via Homebrew.
- On Windows: use Git Bash or WSL as Bash v5 compliant shell.

## Repository structure

```txt
/
├── .devcontainer/         – Development container setup
├── .github/               – GitHub workflows and templates
├── .vscode/               – VS Code settings
├── lib/                   – The Bash library code
├── template/              – Template gen_pack.sh script & example
├── test/                  – Test scripts, CI test cases
├── gen_pack.sh            – (if applicable) top‐level invocation script
├── README.md              – Project overview
└── LICENSE                – Apache 2.0 license
```

## Setting up locally

1. Clone the repository:

   ```sh
   ❯ git clone https://github.com/Open-CMSIS-Pack/gen-pack.git
   ❯ cd gen-pack
   ```

2. (Optional) Open in VS Code with the .devcontainer/ for a ready-to-use environment.

3. Ensure Bash v5+ is in PATH (bash --version).

4. Run all existing tests:

   ```sh
   ❯ ./test/run_all.sh
   ```

   Or individual test groups or cases:

   ```sh
   ❯ ./test/tests_<group>.sh [-- <test> [<test>...]]
   ```

## Making changes

- Work on a feature/bug branch: git checkout -b feature/my-improvement.
- Make your edits in lib/ or template/ as appropriate.
- Update or add tests in test/.
- Run the tests and fix any failures.
- Update README.md or other documentation if your change requires explanation.

## Integration Testing

For testing changes/features in a real scenario (existing `gen_pack.sh` script), check the existing script to contain
the bootstrap code suggested by the [script template](template/gen_pack.sh#L119-L124):

```sh
if [[ -n "${GEN_PACK_LIB_PATH}" ]] && [[ -f "${GEN_PACK_LIB_PATH}/gen-pack" ]]; then
  . "${GEN_PACK_LIB_PATH}/gen-pack"
else
  . <(curl -sL "https://raw.githubusercontent.com/Open-CMSIS-Pack/gen-pack/main/bootstrap")
fi
```

This makes the script recognizing the environment variable `GEN_PACK_LIB_PATH` to overwrite the library include path.
Setting this variable to the root folder of the Git repository makes any subsequent call of the script to use the
development version of the library instead of the requested release version (via `REQUIRED_GEN_PACK_LIB`).

For example, while on a shell inside the Git repository root one run the template script:

```sh
❯ GEN_PACK_LIB_PATH=$(pwd) ./templates/gen-pack.sh -v
gen_pack.sh> Loading gen-pack library <version> from <git repo dir>
```

## CI / Workflow

- GitHub Actions workflows are present in .github/workflows/ (e.g., linting, test, release).
- Ensure your branch passes CI checks before opening a PR.

## Versioning & Releases

- Tags follow semantic versioning (e.g., v0.11.3).  ￼
- When preparing a release:
- Update changelog or release notes if relevant.
- Ensure your changes are merged into main and the new tag pushed.
- Verify the library works as expected (e.g., by invoking template script).

## Troubleshooting

- If tests fail, check for differences in shell versions or OS platforms (Linux/macOS/Windows).
- On macOS: if standard tar does not support wildcards properly, install gnu-tar.  ￼
- If script fails due to missing command, ensure that dependencies (e.g., xmllint) are installed.

## Further reading

- See [README](README.md) for usage and overview of gen-pack.
- Refer to test/ for example test patterns.
- For wider context on software packs, see the Open-CMSIS-Pack specification.

⸻

Thank you for diving into development with gen-pack!
