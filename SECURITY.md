# Security Policy

## Reporting a Vulnerability

Please report suspected security vulnerabilities privately using
[GitHub private vulnerability reporting](https://github.com/Open-CMSIS-Pack/gen-pack/security/advisories/new).
Do not disclose vulnerability details in public issues or pull requests before
coordinating with the maintainers.

Include the following where possible:

- The affected library version/tag or commit SHA.
- A description of the vulnerability and its potential impact.
- A minimal `gen_pack.sh`, relevant PDSC and other input files, and steps to reproduce.
- The operating system, Bash version, and relevant tool versions.
- For CI-specific issues, the workflow, token permissions, and prerequisites.
- Any suggested mitigation or fix.

Remove credentials, tokens, and other sensitive data from examples and logs.

## Affected Versions

Please report suspected vulnerabilities in any revision of this library. If
possible, check whether the issue also affects the current `main` branch.
Maintainers will assess affected revisions and discuss remediation through the
private report. This policy does not establish a support or backport schedule
for historical commits.

## Scope and Security Boundaries

This project provides a Bash library for generating CMSIS packs, used on local
developer machines and in CI. Relevant components include the `gen-pack` entry
point, `bootstrap`, `lib/`, `template/`, and the reusable library-update workflow
in `.github/workflows/update-lib.yml`.

Caller-provided `gen_pack.sh` scripts, configuration written as shell code, and
`preprocess`/`postprocess` hooks execute with the caller's permissions and must be
trusted. They are not sandboxed. Bootstrap also downloads and sources executable
library code; the template fetches bootstrap from `main` while the library
version is selected by `REQUIRED_GEN_PACK_LIB`. Treat these executable sources
and local library installations as part of the build's trust boundary.

PDSC files, dependency indexes, downloaded schemas, filenames, and changelog text
are data processed by the library and its tools. Security properties relevant to
reports include preventing these inputs from becoming unintended shell commands,
preventing unintended file access or modification through paths or symlinks, and
protecting downloaded dependencies and cached files from unauthorized replacement.

File operations should respect the caller's explicitly configured input, build,
output, and cache locations. Selecting source files outside the pack root is a
supported feature; reports should explain which intended boundary is crossed.
Relevant impacts include unintended deletion or overwriting of files, disclosure
of credentials or unrelated files in generated packs, and tampering with pack
contents or release metadata.

For the reusable update workflow, also consider repository content and metadata
processed with write permissions or access to the supplied token. Use the minimum
permissions required, and avoid running untrusted pull request code with secrets
or write access.

Please explain the attacker-controlled input, the affected operation, and the
permissions or access required to reproduce a report. The properties above
describe security expectations, not a claim that every input is safely handled.

## Coordinated Disclosure

Please use the private report to coordinate investigation, remediation, and
public disclosure with the maintainers. Response and remediation times depend
on the issue; this policy makes no fixed response-time commitment.

For ordinary bugs, feature requests, and suggestions to improve this policy,
use the repository's public issues or pull requests. If you are unsure whether
an issue has security implications, report it privately first.
