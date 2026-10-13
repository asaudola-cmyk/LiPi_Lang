# 👑 Awesome LiPi (অসাধারণ লিপি)

> **A curated collection of delightful LiPi libraries, tools, frameworks, and resources.**  
> LiPi is the world's first bilingual direct silicon programming language (0% C, 0% Libc, 0% LLVM).

[![LiPi Version](https://img.shields.io/badge/version-1.0.0-00ffcc.svg)](https://github.com/asaudola-cmyk/LiPi_Lang)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Regression Tests](https://img.shields.io/badge/tests-203%2F203%20PASS-brightgreen.svg)](tests/)
[![Binary Independence](https://img.shields.io/badge/libc-0%25-blueviolet.svg)](src/compiler/)

---

## 📑 Contents

- [Official Developer Toolchain](#-official-developer-toolchain)
- [Foundational Packages](#-foundational-packages)
- [Web & Networking](#-web--networking)
- [Database & Storage](#-database--storage)
- [Systems, Runtimes & Concurrency](#-systems-runtimes--concurrency)
- [Cryptography & Security](#-cryptography--security)
- [Silicon AI & Scientific Computing](#-silicon-ai--scientific-computing)
- [Editor & IDE Extensions](#-editor--ide-extensions)
- [Examples & Showcase Applications](#-examples--showcase-applications)

---

## 🛠️ Official Developer Toolchain

- [`lipi`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipi.lp) — Universal sovereign master CLI driver (replaces gcc, cargo, make, and go).
- [`lipc`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/driver_cli.lp) — Direct silicon machine code compiler with multi-target emitters (ELF64, PE32+, Mach-O, WASM).
- [`lipipkg`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipipkg.lp) — Autonomous Ed25519 cryptographic package manager, Git resolver, and built-in registry daemon.
- [`lipilsp`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipilsp.lp) — High-performance Language Server Protocol daemon for IDE integration.
- [`lipidbg`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipidbg.lp) — Pure `sys_ptrace` native machine code debugger with hardware register introspection.
- [`lipirepl`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipirepl.lp) — Interactive REPL shell with instant hardware cycle evaluation and JIT statement execution.
- [`lipifmt`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipifmt.lp) — Canonical Tri-Syntax code formatter.

---

## 📦 Foundational Packages

The following packages are pre-verified, cryptographically signed with RFC 8032 Ed25519, and ready to install via `lipipkg`:

| Package | Description | Status | Installation |
|---|---|---|---|
| [`web_router`](file:///home/shafiullah/Documents/file/work/lipi/packages/web_router) | Zero-allocation radix-tree HTTP request router with parameter decoding | ✅ Verified | `lipipkg add web_router` |
| [`crypto_vault`](file:///home/shafiullah/Documents/file/work/lipi/packages/crypto_vault) | NIST FIPS 180-4 SHA-256 and Ed25519 cryptographic authentication suite | ✅ Verified | `lipipkg add crypto_vault` |
| [`lipi_sql`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_sql) | Pure LiPi relational query engine, table algebra, and in-memory indexing | ✅ Verified | `lipipkg add lipi_sql` |
| [`json_toolkit`](file:///home/shafiullah/Documents/file/work/lipi/packages/json_toolkit) | Zero-leak JSON parser, serializer, and JSONPath querying engine | ✅ Verified | `lipipkg add json_toolkit` |
| [`math_extra`](file:///home/shafiullah/Documents/file/work/lipi/packages/math_extra) | High-precision complex numbers, trigonometry, matrix algebra, and geometry | ✅ Verified | `lipipkg add math_extra` |

---

## 🌐 Web & Networking

- [`utso/net/socket.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/net/socket.lp) — Direct Linux kernel raw TCP/UDP socket driver without libc.
- [`utso/net/http.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/net/http.lp) — Pure RFC 7230 / RFC 7231 HTTP/1.1 client (`http_get`, `http_post`) and request serializer.
- [`packages/lipi_web/engine.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_web/engine.lp) — High-throughput HTTP web engine with response streaming and JSON serialization.
- [`utso/net/websocket.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/net/websocket.lp) — RFC 6455 full-duplex WebSocket server protocol implementation.

---

## 💾 Database & Storage

- [`packages/lipidb/pg_wire.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipidb/pg_wire.lp) — Pure PostgreSQL 3.0 binary wire protocol client connecting to live Postgres servers over raw TCP.
- [`packages/lipidb/mysql_wire.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipidb/mysql_wire.lp) — Native MySQL wire protocol client implementation.
- [`packages/lipidb/btree.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipidb/btree.lp) — Slotted-page 4KB B+Tree storage engine with disk serialization.
- [`examples/lipidkv_cache/`](file:///home/shafiullah/Documents/file/work/lipi/examples/lipidkv_cache) — Production in-memory Redis-compatible key-value cache and store.

---

## ⚙️ Systems, Runtimes & Concurrency

- [`src/runtime/async/fiber.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/runtime/async/fiber.lp) — M:N lightweight fiber scheduler with 8KB user-space stacks and 9-register fast context switching.
- [`utso/os/syscalls.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/os/syscalls.lp) — Multi-OS native system call table (Linux, macOS Darwin `0x2000000`, Windows PE64).
- [`packages/lipi_hypervisor/kvm.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_hypervisor/kvm.lp) — Linux Kernel-based Virtual Machine (KVM) hypervisor controller and vCPU manager.
- [`utso/os/kernel_multiboot.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/os/kernel_multiboot.lp) — Bare-metal x86_64 Multiboot2 unikernel entry point.

---

## 🔐 Cryptography & Security

- [`utso/crypto.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/crypto.lp) — NIST FIPS 180-4 SHA-256 and SHA-512 cryptographic digests.
- [`utso/crypto/advanced.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/crypto/advanced.lp) — RFC 8032 Ed25519 digital signature generation and verification.
- [`utso/crypto/tls.lp`](file:///home/shafiullah/Documents/file/work/lipi/utso/crypto/tls.lp) — Pure LiPi TLS 1.3 record layer and AES-128-GCM authentication.

---

## 🧠 Silicon AI & Scientific Computing

- [`packages/lipi_ai/tensor.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_ai/tensor.lp) — N-dimensional tensor engine with AVX2 SIMD matrix multiplication (GEMM).
- [`packages/lipi_ai/llm/transformer.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_ai/llm/transformer.lp) — Scaled Dot-Product Attention, Softmax, and Rotary Position Embeddings (RoPE).
- [`packages/lipi_quantum/shor.lp`](file:///home/shafiullah/Documents/file/work/lipi/packages/lipi_quantum/shor.lp) — Shor's quantum period-finding with continued fraction expansion.

---

## 💻 Editor & IDE Extensions

- [`editors/vscode/`](file:///home/shafiullah/Documents/file/work/lipi/editors/vscode) — Official Visual Studio Code extension:
  - Full Tri-Syntax highlighting (Bengali indentation, English indentation, `@fn` meta-syntax).
  - Code snippets, language configuration, and Language Server Protocol client.
  - VSIX package: `dist/lipi-language-1.0.0.vsix`.

---

## 🚀 Installation & Quick Start

Install the complete LiPi toolchain with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
```

Create and run your first sovereign application:

```bash
lipipkg init my_app
cd my_app
lipipkg build
./build/app
```

Launch the interactive REPL shell:

```bash
lipi repl
```
