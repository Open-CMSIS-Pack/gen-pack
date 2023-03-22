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
