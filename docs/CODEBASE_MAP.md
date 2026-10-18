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
│          src/           │          utso/          │        aati/        │
│   COMPILER & TOOLCHAIN  │   GENESIS PRIMITIVES    │   SOVEREIGN PACKAGES    │
├─────────────────────────┼─────────────────────────┼─────────────────────────┤
│ • 79 Modular Subsystems │ • Silicon Primitives    │ • 18+ Sovereign Packages│
│ • 0% Libc / 0% C        │ • OS & Syscall Gateway  │ • lipipkg.toml Manifest │
│ • Stage-3 Self-Hosting  │ • High-Speed Allocators │ • Decentralized P2P Hub │
│ • Emits ELF64/WASM/MachO│ • Crypto, Net, IO, CPU  │ • AI, DB, Web, GUI, FS  │
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
```

1. **[`src/`](file:///home/shafiullah/Documents/file/work/lipi/src/) — The Sovereign Compiler & Toolchain Engine**
   - Contains the compiler itself, the minimal freestanding runtime, and toolchain CLI tools.
   - Used **only** during compilation and building of executables.
   - Built with strict adherence to the **Golden $\le 35,000$ bytes** per-module invariant.
2. **[`utso/`](file:///home/shafiullah/Documents/file/work/lipi/utso/) — Genesis Silicon Primitives (`উৎস`)**
   - Pure silicon primitives that directly interface with hardware and Linux kernel syscalls.
   - Single-file genesis modules (`memory.lp`, `io.lp`, `string.lp`, `math.lp`, `socket.lp`, `crypto.lp`, `syscalls.lp`, `collections.lp`, `hashmap.lp`, `arena.lp`, `error.lp`, `option.lp`, `result.lp`, `channel.lp`, `concurrency.lp`, `time.lp`, `fmt.lp`, `unicode.lp`, `ffi.lp`).
   - Deep sub-layers in `utso/core/`, `utso/os/`, `utso/sys/`, `utso/net/`, `utso/crypto/`, `utso/cpu/`, `utso/io/`, `utso/tools/`.
3. **[`aati/`](file:///home/shafiullah/Documents/file/work/lipi/aati/) — Sovereign Domain Packages**
   - Independent, versioned domain packages managed by the sovereign package manager (`lipipkg`).
   - Each package contains its own `lipipkg.toml` manifest, sovereign modules, and unit tests.
   - Domain packages include `lipi_ai`, `lipidb`, `lipi_web`, `lipi_gui`, `lipi_engine3d`, `lipi_quantum`, `lipi_blockchain`, `lipi_hypervisor`, `lipi_swarm`, `lipi_iot`, `lipi_media`, `lipi_gpu`, `lipi_fs`, `lipi_mobile`, `lipi_p2p`, `lipi_security`, `lipi_boot`, `lipi_ide`, `lipi_registry`.

---

## 📂 Root Directory Master Inventory

```
lipi/
├── .github/             # GitHub configuration, CI workflows, CONTRIBUTING.md & SECURITY.md
├── build.lp             # Autonomous sovereign build pipeline (0% Shell, 0% Make)
├── docs/                # Architectural guides, handbooks, specifications, and books
├── examples/            # Ready-to-run showcase apps, tutorials, and benchmarks
├── install.sh           # Standalone curl installer for Linux x86_64
├── LICENSE              # MIT Open Source License
├── lipipkg.toml         # Root project package and workspace manifest
├── aati/            # Sovereign domain packages (lipi_ai, lipidb, lipi_web, ...)
├── README.md            # Primary repository entry point and quickstart guide
├── scripts/             # Automation, benchmarking, and documentation generator scripts
├── src/                 # Compiler micro-pipeline, runtime, and tool implementations
├── tests/               # 203 master regression, hardware HDL, and AI parity test suites
└── utso/                # Genesis silicon primitives (উৎস: memory, io, net, os, crypto, cpu, tools)
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

### 2. [`utso/`](file:///home/shafiullah/Documents/file/work/lipi/utso/) — Genesis Silicon Primitives (`উৎস`)

The Genesis Primitives are pure silicon building blocks:
- **`utso/` (Root Primitives):** `memory.lp`, `io.lp`, `string.lp`, `unicode.lp`, `math.lp`, `fmt.lp`, `collections.lp`, `hashmap.lp`, `arena.lp`, `error.lp`, `option.lp`, `result.lp`, `channel.lp`, `concurrency.lp`, `time.lp`, `syscalls.lp`, `socket.lp`, `crypto.lp`, `ffi.lp`.
- **`utso/core/`**: Memory paging, string operations, UTF-8 Bengali runes, collections, traits, and options.
- **`utso/crypto/`**: Hardware entropy (`SYS_getrandom`), SHA-256, AES-256-GCM, X25519, Ed25519, and X.509 PKI certificates.
- **`utso/net/`**: Direct silicon sockets, epoll event loops, TLS 1.3 in-process server, DNS resolver, and WebSocket.
- **`utso/os/`**: Direct POSIX/Linux syscall bindings, process execution, thread scheduler, and virtual filesystem (VFS).
- **`utso/cpu/`**: Direct AVX-512 GEMM matrix engine and hardware silicon acceleration.
- **`utso/io/`**: Direct Linux io_uring asynchronous ring buffers, PCIe NVMe MMIO storage controller, DMA engine.
- **`utso/tools/`**: In-engine debugger, profiler, interactive REPL, LSP server protocol, and test runner.

---

### 3. [`aati/`](file:///home/shafiullah/Documents/file/work/lipi/aati/) — Sovereign Domain Packages

| Package | Description | Key Capabilities |
| :--- | :--- | :--- |
| `aati/lipi_ai` | Autonomous AI & Tensor Engine | N-D tensors, reverse-mode autodiff, GGUF local LLM inference |
| `aati/lipidb` | Embedded ACID Database | LipiKV, B+Tree indexing, WAL crash recovery, Redis protocol |
| `aati/lipi_web` | Sovereign Full-Stack Web Framework | Sub-microsecond HTTP/1.1 & HTTP/2 routing, WebSockets, DOM-bypass |
| `aati/lipi_gui` | Sovereign GUI & Graphics | Linux `/dev/fb0` framebuffer, DRM/KMS, Bresenham canvas, desktop UI |
| `aati/lipi_gpu` | GPU Compute & SPIR-V Engine | Native SPIR-V binary code emission, compute shaders, DRM dumb-buffers |
| `aati/lipi_fs` | Filesystem Engine | Copy-on-Write LipiFS, raw Ext4 filesystem driver |
| `aati/lipi_blockchain` | Sovereign Blockchain Core | EVM-compatible VM, Merkle Patricia Trie, cryptographic ledger |
| `aati/lipi_quantum` | Quantum Computing Simulator | State vectors, superposition, quantum gates, Shor algorithm |
| `aati/lipi_hypervisor`| Bare-Metal Hypervisor | Linux KVM ioctl hardware virtualization, guest vCPU execution |
| `aati/lipi_swarm` | Distributed Swarm Engine | Actor concurrency model, distributed consensus, mesh routing |
| `aati/lipi_iot` | Embedded IoT & Edge Gateway | MQTT client, hardware sensor telemetry, edge gateway |
| `aati/lipi_media` | Pure Audio & Video Canvas | Pure WAV audio synthesis, video canvas blitting |
| `aati/lipi_mobile` | Mobile Platform Runtime | Mobile application engine, sandbox storage, event system |
| `aati/lipi_p2p` | P2P Network & Distribution | Kademlia DHT, peer-to-peer package distribution, registry |
| `aati/lipi_security` | Advanced Security & Proofs | Zero-knowledge proofs, JWT auth, seccomp sandbox |
| `aati/lipi_boot` | Bare-Metal Bootloader | UEFI and Multiboot bootloader, freestanding kernel |
| `aati/lipi_ide` | Sovereign IDE & Studio | IDE studio, syntax highlighter, integrated LSP client |
| `aati/lipi_registry` | Package Registry Hub | Decentralized package registry, SemVer 2.0.0 resolver |

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
- **Standard library primitives**: Add genesis primitives in [`utso/`](file:///home/shafiullah/Documents/file/work/lipi/utso/) or sovereign domain modules in [`aati/`](file:///home/shafiullah/Documents/file/work/lipi/aati/).
- **Reusable community libraries**: Create a new package in [`aati/<name>/`](file:///home/shafiullah/Documents/file/work/lipi/aati/) with a valid `lipipkg.toml`.
- **Regression tests**: Add tests in [`tests/`](file:///home/shafiullah/Documents/file/work/lipi/tests/) and register them in [`tests/run_tests.lp`](file:///home/shafiullah/Documents/file/work/lipi/tests/run_tests.lp).
