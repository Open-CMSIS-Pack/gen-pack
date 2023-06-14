# Unit tests for gen-pack library

For each bash library source file this folder contains a `tests_<name>.sh` file
with unit tests for all functions.

The unit tests use the [shUnit2](https://github.com/kward/shunit2) test framework.

## Run unit tests

The unit tests can be executed all at once:

```bash
test $ ./run_all.sh
```

Individual test groups can be executed by running the `tests_<name>.sh` script
directly, for example:

```bash
test $ ./tests_gen_pack.sh
```

Specific test cases can be executed via the test group scripts by adding test
case names to the command line, for example:

```bash
test $ ./tests_gen_pack.sh -- test_add_dirs
```

## Run coverage

Code coverage for shell scripts can be gathered using
[`kcov`](https://github.com/SimonKagstrom/kcov).  In Ubuntu `kcov` is available
via `apt install kcov`. On Mac it can be installed through `brew install kcov`.
There is no binary distribution for Windows.

The coverage report can be created like the following:

```bash
test $ ./run_cov.sh
```

This will run all tests (except the integration tests) via `kcov`. The resports
are placed to `test/cov` folder. For each test suite a separate report is
created in the first place. Lastly, all reports are merged into a full report
placed to `test/cov/all`. The [index.html](test/cov/all/index.html) can be
opened in a web browser to inspect the coverage report.
