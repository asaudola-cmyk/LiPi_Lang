# Contributing to Lipi

Thank you for contributing to Lipi. Please keep changes clean, minimal, well-tested, and free of external runtime dependencies.

## Engineering Guidelines

1. **Zero External Runtime Dependencies**: Do not introduce Python, C/libc wrappers, LLVM, or external toolchains into `src/`, `utso/`, `aati/`, `tests/`, `benchmarks/`, or `scripts/`. CI enforces zero `.py`/`.pyc` files in these directories.
2. **Static-PIE & W^X (`0 RWE`)**: Emitted ELF64 binaries must remain Static-PIE with zero writable+executable segments.
3. **Bilingual Parity**: Language features should work consistently across English, Bengali, and `@`-directive syntax.
4. **Package Signatures (`aati.lock`)**: If you modify any package under `aati/`, re-sign it with `./bin/aati sign <pkg>` and update `aati.lock`, then verify with `./bin/aati verify-lock aati.lock`.

## Local Development & Verification

```bash
# Bootstrap compiler and build toolchain
make

# Run the full regression test suite (258 tests)
./bin/lipi test

# Verify deterministic 3-stage self-hosting bootstrap
./bin/lipc src/compiler/driver_cli.lp /tmp/lipc_s2 && chmod +x /tmp/lipc_s2
/tmp/lipc_s2 src/compiler/driver_cli.lp /tmp/lipc_s3 && chmod +x /tmp/lipc_s3
cmp /tmp/lipc_s2 /tmp/lipc_s3

# Verify all 31 workspace packages
./bin/aati verify-lock aati.lock
```

## Repository Layout

- `src/` — Bootstrap seed, compiler, runtime, toolkit, and CLI tools
- `utso/` — Core standard library
- `aati/` — Workspace packages
- `tests/` — Regression test suite
- `examples/` — Runnable examples
- `docs/` — Technical documentation

## Pull Request Checklist

- All tests pass (`./bin/lipi test`).
- New compiler/stdlib behavior includes focused tests in `tests/` registered in `tests/run_tests.lp`.
- Modified `utso/`, `aati/`, or `examples/` `.lp` files compile cleanly with `./bin/lipc`.
- Documentation stays accurate and concise.
