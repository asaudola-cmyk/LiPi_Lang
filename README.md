# Lipi (লিপি)

[![CI](https://github.com/asaudola-cmyk/LiPi_Lang/actions/workflows/lipi-ci.yml/badge.svg)](https://github.com/asaudola-cmyk/LiPi_Lang/actions/workflows/lipi-ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English | [বাংলা (Bengali)](README.bn.md)

Lipi is a self-hosted, statically compiled bilingual (Bengali and English) systems programming language. The compiler, runtime, standard library, and developer toolchain are written in Lipi and emit native machine code directly without GCC, Clang, LLVM, or `libc`.

## Overview

- **Self-hosted native compiler (`src/compiler/`)**: Compiles Lipi directly to static-PIE Linux x86_64 ELF64 binaries (`0 RWE` segments), Windows PE32+, macOS Mach-O, ARM64, RISC-V 64, and WebAssembly. Deterministic 3-stage self-bootstrap from `src/boot/lipi-seed`.
- **Zero external runtime dependencies**: Programs invoke OS kernel syscalls directly (`syscall` on Linux x86_64) with no dynamic loader or C runtime dependency.
- **Bilingual syntax**: Supports Bengali keywords and numerals, English keywords, and `@`-directive syntax within a single unified AST.
- **Static safety (`--kavach`) & W^X isolation**: Optional compile-time ownership/leak checking and hardware-boundary enforcement (`silicon_*` prefix), paired with signed `LPKC` W^X code capsules (`utso/core/kavach_capsule.lp`) and W^X ELF shared-object loading (`utso/core/ffi_sovereign.lp`).
- **Native cryptography, TLS 1.3 & HTTP/2**: Pure-Lipi implementations of SHA-256/384/512, AES-128/256-GCM, ChaCha20-Poly1305, X25519, Ed25519, NIST P-256/P-384 ECDSA, RSA-PSS/PKCS#1 v1.5, RFC 5280/6125 X.509 validation, TLS 1.3 client/server (SNI multi-domain, P-256/P-384/Ed25519 signing, PSK session resumption, ALPN `h2`/`http/1.1`), and RFC 7540/7541 HTTP/2 (`h2c` & `h2` with HPACK Huffman decoding) (`utso/crypto/`, `utso/net/`).
- **Durable relational storage & developer toolchain**: CRC-32 `fsync` WAL-backed SQL engine with `BEGIN`/`COMMIT`/`ROLLBACK` ACID transactions, secondary hash indexes, `INNER`/`LEFT` hash joins, and `GROUP BY` aggregations (`aati/lipi_sql/`), thread-safe WAL job queue (`aati/lipi_web/`), plus native CLI (`lipi`), Ed25519 package manager (`aati`), formatter (`lipifmt`), LSP (`lipilsp`), debugger (`lipidbg`), doc generator (`lipidoc`), REPL (`lipirepl`), and ELF inspector (`lipi_akhara`).

## Quick Example

English syntax:

```lipi
fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

fn main
    say "5! = " + to_str(factorial(5))
    return 0

main()
```

Bengali syntax:

```lipi
ফাংশন ফ্যাক্টোরিয়াল সংখ্যা
    যদি সংখ্যা <= ১
        ফেরত ১
    ফেরত সংখ্যা * ফ্যাক্টোরিয়াল(সংখ্যা - ১)

ফাংশন প্রধান
    বলো "৫! = " + to_str(ফ্যাক্টোরিয়াল(৫))
    ফেরত ০

প্রধান()
```

Compile and run:

```bash
./bin/lipc hello.lp -o hello
./hello

# Or compile and run via the unified CLI
./bin/lipi run hello.lp
```

## Build from Source

No C compiler, Python, or LLVM installation is required on Linux x86_64.

```bash
git clone https://github.com/asaudola-cmyk/LiPi_Lang.git
cd LiPi_Lang
make
```

`make` bootstraps `bin/lipc` from `src/boot/lipi-seed` through Stage 1 → Stage 2 and builds the full native toolchain into `bin/`.

### Run Tests

```bash
# Run the full regression test suite (266 tests)
./bin/lipi test

# Verify Ed25519 signatures and lockfile across all 31 aati/ packages
./bin/aati verify-lock aati.lock
```

### Install

Linux / macOS:

```bash
./install.sh
```

Windows (PowerShell):

```powershell
.\install.ps1
```

## Toolchain Commands

| Command | Description |
|---|---|
| `lipc <file.lp> -o <out>` | Direct compiler (`--target=windows\|macos\|arm64\|riscv64\|wasm`, `--kavach`) |
| `lipi build <file.lp> -o <out>` | Compile a native binary |
| `lipi run <file.lp>` | Compile and execute a source file |
| `lipi test` | Run the regression test suite |
| `lipi bench [--quick]` | Run compile-time and runtime hardware benchmarks |
| `lipi aati <cmd>` / `aati <cmd>` | Package manager (`init`, `add`, `build`, `sign`, `verify`, `verify-lock`) |
| `lipi fmt <file.lp> [-w]` | Source code formatter |
| `lipi lsp` | Language Server Protocol daemon (`lipilsp`) |
| `lipi debug <binary>` | Native `ptrace` debugger (`lipidbg`) |
| `lipi akhara` | Binary inspector and local playground (`lipi_akhara`) |
| `lipi repl` | Interactive REPL |
| `lipi self-build` | 3-stage deterministic self-hosting bootstrap verification |

## Repository Structure

```text
LiPi_Lang/
├── src/
│   ├── boot/           # Genesis bootstrap seed (lipi-seed, seed.b64)
│   ├── compiler/       # Frontend, semantics, SSA middle-end, multi-target backends
│   ├── runtime/        # Async runtime, VM, and WASM runtime support
│   ├── toolkit/        # Shared library modules for developer tools
│   └── tools/          # Native CLI binaries (lipi, aati, lipilsp, lipifmt, lipidbg, ...)
├── utso/               # Core standard library (syscalls, memory, io, crypto, net, cpu, os)
├── aati/               # 31 signed ecosystem packages (see aati.toml and aati.lock)
├── tests/              # Regression test suite (262 tests registered in tests/run_tests.lp)
├── examples/           # Runnable example programs
├── benchmarks/         # Benchmark harnesses and cross-language reference implementations
├── editors/vscode/     # VS Code extension (TextMate grammar, snippets, LSP client)
├── scripts/            # Verification and asset helper scripts
├── docs/               # Technical documentation
├── Makefile            # Bootstrap, build, test, and packaging targets
├── aati.toml           # Root workspace manifest
└── aati.lock           # Cryptographic lockfile for all 31 aati/ packages
```

### Standard Library (`utso/`) and Packages (`aati/`)

- **Core library (`utso/`)**: `core/`, `cpu/`, `crypto/`, `io/`, `net/`, `os/`, `sys/`, `tools/`, plus top-level entry modules (`arena.lp`, `channel.lp`, `collections.lp`, `concurrency.lp`, `error.lp`, `ffi.lp`, `fmt.lp`, `hashmap.lp`, `math.lp`, `memory.lp`, `option.lp`, `result.lp`, `socket.lp`, `string.lp`, `syscalls.lp`, `time.lp`, `unicode.lp`).
- **Workspace packages (`aati/`, 31 packages)**:
  - **Networking & Web**: `lipi_web`, `web_router`, `lipi_http_client`, `lipi_grpc`, `lipi_jwt`, `lipi_p2p`, `sovereign_mesh`, `lipi_swarm`, `lipi_browser`
  - **Storage & Data**: `lipi_sql`, `lipidb`, `lipi_fs`, `lipi_dataframe`, `json_toolkit`
  - **Security & Packaging**: `crypto_vault`, `lipi_security`, `lipi_registry`
  - **Compute, AI & Math**: `lipi_ai`, `lipi_torch`, `lipi_gpu`, `lipi_quantum`, `math_extra`, `lipi_blockchain`
  - **Systems, UI & Media**: `lipi_boot`, `lipi_hypervisor`, `lipi_iot`, `lipi_gui`, `lipi_engine3d`, `lipi_media`, `lipi_mobile`, `lipi_ide`

## Benchmarks

Run `./bin/lipi bench --quick` locally to measure on your hardware. Lipi separates compile-time algebraic constant folding (**Tier I**) from runtime-seeded unfoldable workloads (**Tier II**).

Sample local measurements (`./bin/lipi bench --quick`, Linux x86_64):

| Workload | Category | Observed Result |
|---|---|---|
| Dynamic Xorshift64\* (1M iters, runtime-seeded) | Tier II (unfoldable compute) | `1,879 µs` (`531 M ops/s`, ~7 cycles/op) |
| Dynamic 64 KiB Slab Scan (1 MiB) | Tier II (memory bandwidth) | `205 µs` (`5,112 MB/s`) |
| Segregated Slab Alloc/Free (50K pairs) | Tier II (allocator) | `352 µs` (`7 ns/pair`, `0 B` heap delta) |
| Inline Integer Equality Branch (1M iters) | Tier II (control flow) | `1,302 µs` (`767 M ops/s`) |
| Constant 10M Modulo Loop Fold (`O(N)` → `O(1)`) | Tier I (compile-time fold) | `650 ns` (`84 cycles`) |

See [docs/BENCHMARKS.md](docs/BENCHMARKS.md) for methodology details and cross-language benchmark sources.

## Editor Support

The VS Code extension source lives directly in [editors/vscode/](editors/vscode/). Building with `make` packages `dist/lipi-language-1.0.1.vsix`:

```bash
make
code --install-extension dist/lipi-language-1.0.1.vsix
```

See [editors/vscode/README.md](editors/vscode/README.md) for manual installation instructions.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — Compiler pipeline, target emitters, memory model, TLS 1.3, and W^X isolation
- [Language Guide](docs/LANGUAGE_GUIDE.md) — Bilingual syntax and language reference
- [Standard Library Reference](docs/STANDARD_LIBRARY.md) — `utso/` modules and `aati/` workspace packages
- [Benchmarks](docs/BENCHMARKS.md) — Benchmark methodology and how to run locally
- [Changelog](docs/CHANGELOG.md) — Release history
- [Examples](examples/README.md) — Runnable sample programs
- [Contributing](.github/CONTRIBUTING.md) & [Security Policy](.github/SECURITY.md)

## License

MIT License — see [LICENSE](LICENSE).
