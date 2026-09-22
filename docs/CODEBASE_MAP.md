# 🗺️ LiPi Sovereign Language — Codebase Map & Directory Architecture

> **⚡ 100% Pure Direct Silicon Machine Code | 0% C | 0% Libc | 0% LLVM | 0% Host Dependencies**  
> **Sovereign Tri-Syntax: Native Bengali (`বাংলা`) + Canonical English + LiPi Directives (`@`)**

---

## 🏛️ Executive Structure: The "Big Three" Pillars

When exploring the LiPi codebase, code is organized into three distinct tiers based on architectural responsibility. Understanding this separation eliminates any confusion:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LIPI REPOSITORY ARCHITECTURE                      │
├─────────────────────────┬─────────────────────────┬─────────────────────────┤
│          src/           │        universe/        │        packages/        │
│   COMPILER & TOOLCHAIN  │    STANDARD LIBRARY     │   ENTERPRISE MODULES    │
├─────────────────────────┼─────────────────────────┼─────────────────────────┤
│ • 79 Modular Subsystems │ • 29 Universal Domains  │ • 10 Standalone Modules │
│ • 0% Libc / 0% C        │ • OS & Hardware Direct  │ • lipipkg.toml Manifest │
│ • Stage-3 Self-Hosting  │ • High-Level Abstraction│ • Decentralized P2P Hub │
│ • Emits ELF64/WASM/MachO│ • Crypto, Net, DB, GUI  │ • Router, JWT, Vault    │
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
```

1. **[`src/`](file:///home/shafiullah/Documents/file/work/lipi/src/) — The Sovereign Compiler & Toolchain Engine**
   - Contains the compiler itself, the minimal freestanding runtime, and toolchain CLI tools.
   - Used **only** during compilation and building of executables.
   - Built with strict adherence to the **Golden $\le 35,000$ bytes** per-module invariant.
2. **[`universe/`](file:///home/shafiullah/Documents/file/work/lipi/universe/) — The LiPi Universal Standard Library (Stdlib)**
   - The rich standard library that developers `import` and `include` when writing LiPi programs.
   - Provides direct, zero-overhead hardware and OS abstractions across 29 specialized domains (Crypto, Networking, GUI, In-Memory DB, AI/Tensors, Quantum, KVM Hypervisor).
3. **[`packages/`](file:///home/shafiullah/Documents/file/work/lipi/packages/) — Enterprise Ecosystem Packages**
   - Independent, versioned modules managed by the sovereign package manager (`lipi-pkg`).
   - Each package contains its own `lipipkg.toml` manifest, `src/` library code, and unit `tests/`.

---

## 📂 Root Directory Master Inventory

```
lipi/
├── .github/             # GitHub configuration, CI workflows, CONTRIBUTING.md & SECURITY.md
├── benchmarks/          # Empirical performance benchmarks vs C/C++/Go/Rust/Zig
├── build.lp             # Autonomous sovereign build pipeline (0% Shell, 0% Make)
├── docs/                # Architectural guides, handbooks, specifications, and books
├── examples/            # Ready-to-run showcase apps, tutorials, and benchmarks
├── install.sh           # Standalone curl installer for Linux x86_64
├── LICENSE              # MIT Open Source License
├── lipipkg.toml         # Root project package and workspace manifest
├── packages/            # Reusable ecosystem packages (crypto_vault, web_router, ...)
├── README.md            # Primary repository entry point and quickstart guide
├── scripts/             # Automation, benchmarking, and documentation generator scripts
├── src/                 # Compiler micro-pipeline, runtime, and tool implementations
├── tests/               # 187 master regression, hardware HDL, and AI parity test suites
└── universe/            # LiPi 30-domain standard library and hardware universe
```

---

## 🔬 Deep Dive: Directory Subsystems

### 1. [`src/`](file:///home/shafiullah/Documents/file/work/lipi/src/) — Compiler & Toolchain

- **`src/compiler/`**: The 79-module sovereign compiler pipeline:
  - `src/compiler/driver_cli.lp`: CLI entrypoint handling arguments (`-o`, `--target`, `-O2`, `-g`, `--shared`).
  - `src/compiler/driver.lp`: Recursive dependency resolver, include bundler, and phase telemetry.
  - `src/compiler/pipeline.lp`: 8-phase linear compiler pipeline orchestrator.
  - `src/compiler/frontend/`: Lexer, token stream, parser, and AST node definitions.
  - `src/compiler/semantics/`: Type checking, symbol tables, const evaluation, and ownership validation.
  - `src/compiler/middleend/`: AST-to-SSA lowering and 12-pass optimizer suite.
  - `src/compiler/backend/regalloc/`: Linear scan register allocation (0 register spills).
  - `src/compiler/backend/targets/`: Direct silicon synthesizers for `x86_64`, `arm64`, `riscv64`, and `wasm`.
  - `src/compiler/backend/formats/`: ELF64 executable, Mach-O, PE32+, DWARF v4/v5 debug, and PIC `.so` shared objects.
  - `src/compiler/diagnostics/`: Bilingual error rendering, source mapping, and suggestions.
- **`src/runtime/`**: Freestanding minimal runtime linked into every emitted binary:
  - `src/runtime/lipi_syscall.lp`: Direct Linux x86_64 / ARM64 syscall wrappers.
  - `src/runtime/lipi_gc.lp`: Mark-and-sweep memory manager.
  - `src/runtime/lipi_arena.lp`: High-throughput arena allocator.
- **`src/toolkit/`**: Reusable modules for developer tooling:
  - `src/toolkit/lsp/`: Language Server Protocol (JSON-RPC 2.0 parser, document store, handlers).
  - `src/toolkit/cli/`: Standardized command-line parsing and terminal UI utilities.
  - `src/toolkit/fmt/`: Indentation and AST-based code formatter engine.
- **`src/tools/`**: Top-level source code for standalone CLI utilities:
  - `src/tools/lipi.lp`: Main unified CLI runner (`lipi run`, `lipi build`, `lipi test`).
  - `src/tools/lipi_lsp.lp`: Standalone LSP server executable.
  - `src/tools/lipifmt.lp`: Standalone code formatter.
  - `src/tools/lipidbg.lp`: Standalone native debugger.
  - `src/tools/lipipkg.lp`: Standalone package manager.

---

### 2. [`universe/`](file:///home/shafiullah/Documents/file/work/lipi/universe/) — Standard Library

The Standard Library is organized by capability domain:
- **`universe/core/`**: Memory primitives, string operations, UTF-8 Bengali runes, collections, traits, and options.
- **`universe/crypto/`**: Hardware entropy (`SYS_getrandom`), SHA-256, AES-256-GCM, X25519, Ed25519, and X.509 PKI certificates.
- **`universe/net/`**: Direct silicon sockets, epoll event loops, TLS 1.3 in-process server, DNS resolver, and WebSocket.
- **`universe/os/`**: Direct POSIX/Linux syscall bindings, process execution, thread scheduler, and virtual filesystem (VFS).
- **`universe/db/`**: In-memory relational SQL engine, B+Tree, Write-Ahead Logging (WAL), and vector similarity search (HNSW).
- **`universe/gui/`**: Zero-X11 direct Linux framebuffer renderer, DRM/KMS graphics, ANSI TUI dashboard, and declarative UI.
- **`universe/ai/`**: Tensor compute engine, AVX2 SIMD matrix GEMM, and GGUF local LLM inference.
- **`universe/hypervisor/`**: Linux KVM direct virtualization and Ring-0 bare-metal unikernel launcher.
- **`universe/quantum/`**: Multi-qubit state vector simulation, Hadamard/CNOT gates, and quantum measurement.

---

### 3. [`packages/`](file:///home/shafiullah/Documents/file/work/lipi/packages/) — Enterprise Ecosystem Modules

| Package | Description | Key Capabilities |
| :--- | :--- | :--- |
| `packages/crypto_vault` | Enterprise Secret Management | Hardware entropy, salted password hashing, session tokens |
| `packages/web_router` | Zero-Copy Radix-Trie Routing | Parameterized URLs, path matching, middleware chains |
| `packages/lipi_jwt` | RFC 7519 JSON Web Tokens | Cryptographic token generation, expiration checks, tamper rejection |
| `packages/lipi_sql` | Embedded Relational Engine | In-memory relational tables, multi-column queries, transaction safety |
| `packages/json_toolkit` | High-Speed JSON Parser | Zero-copy JSON serialization, object extraction, array validation |
| `packages/lipi_dataframe` | Tabular Data Processing | Columnar slicing, statistics, filtering, data transformations |
| `packages/lipi_grpc` | High-Throughput RPC Engine | Protocol buffer serialization, framing, streaming RPCs |
| `packages/lipi_http_client` | Native HTTP/HTTPS Client | TLS-backed requests, header parsing, connection pooling |
| `packages/math_extra` | Advanced Mathematics | Complex numbers, vector mathematics, clamped operations |
| `packages/sovereign_mesh` | P2P Cluster Mesh | Peer discovery, distributed state synchronization |

---

### 4. [`bin/`](file:///home/shafiullah/Documents/file/work/lipi/bin/) — Standalone Toolchain Binaries

All binaries follow the standardized `lipi-<tool>` naming convention, while preserving legacy short forms as symlinks:

```bash
bin/lipc          # Primary Sovereign Modular Compiler (points to lipc_bin)
bin/lipi          # Unified Command Runner & In-Memory REPL
bin/lipi-lsp      # Language Server Protocol IDE Daemon (symlinked to lipilsp)
bin/lipi-fmt      # Canonical 3-Syntax Code Formatter (symlinked to lipifmt)
bin/lipi-pkg      # Ed25519 Cryptographic Package Manager (symlinked to lipipkg)
bin/lipi-dbg      # Native Linux PTrace System Debugger (symlinked to lipidbg)
bin/lipi-test     # Master Test Runner (symlinked to lipitest)
bin/lipi-build    # 22-Target Sovereign Build Pipeline (symlinked to lipibuild)
bin/lipi-doc      # Markdown Documentation Generator (symlinked to lipidoc)
bin/lipi-repl     # Standalone Interactive REPL Terminal (symlinked to lipirepl)
```

---

## 🚀 Navigation & Developer Workflow

### How to Compile a LiPi File
```bash
bin/lipc path/to/program.lp -o /tmp/program && /tmp/program
```

### How to Run All Tests
```bash
bin/lipc tests/run_tests.lp /tmp/run_tests && /tmp/run_tests
```

### How to Build the Entire Ecosystem
```bash
./bin/lipi-build
```

### Where to Add New Features
- **Compiler features**: Add modular passes in [`src/compiler/`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/). Keep every file $\le 35,000$ bytes!
- **Standard library primitives**: Add domain files in [`universe/`](file:///home/shafiullah/Documents/file/work/lipi/universe/).
- **Reusable community libraries**: Create a new package in [`packages/<name>/`](file:///home/shafiullah/Documents/file/work/lipi/packages/) with a valid `lipipkg.toml`.
- **Regression tests**: Add tests in [`tests/`](file:///home/shafiullah/Documents/file/work/lipi/tests/) and register them in [`tests/run_tests.lp`](file:///home/shafiullah/Documents/file/work/lipi/tests/run_tests.lp).
