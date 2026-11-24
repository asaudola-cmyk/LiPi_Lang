# Lipi Architecture

This document describes the architecture of the Lipi compiler, runtime, memory safety model, cryptography/networking stack, and durable storage subsystems.

## 1. Self-Hosting Compiler Pipeline

Lipi compiles source files directly to native machine code without GCC, Clang, LLVM, or `libc`. The compiler resides under `src/compiler/` and is built through a deterministic 3-stage self-hosting bootstrap starting from `src/boot/lipi-seed`.

```text
Source (.lp / .লিপি)
   │
   ▼
[1. Module Bundler & Lexer]        src/compiler/frontend/lexer.lp
   │  Resolves include/import DAG (utso/, aati/, local files);
   │  normalizes Bengali, English, and @-directive tokens + Bengali numerals
   ▼
[2. Parser & AST Construction]     src/compiler/frontend/parser.lp
   │  Single unified AST across all three syntax dialects
   ▼
[3. Semantic & Safety Analysis]    src/compiler/semantics/
   │  Type checking, scope resolution, mathematical/closed-form analysis,
   │  optional --kavach affine ownership + silicon_* hardware boundary check
   ▼
[4. SSA Middle-End & Regalloc]     src/compiler/middleend/
   │  AST → SSA IR lowering, constant folding, algebraic loop proofs,
   │  linear-scan register allocation
   ▼
[5. Target Codegen & Formats]      src/compiler/backend/
      ├── x86_64   → Static-PIE ELF64 (Linux), PE32+ (Windows), Mach-O (macOS), Multiboot2
      ├── ARM64    → AArch64 ELF64 / Mach-O + NEON
      ├── RISC-V   → RV64I/M/V ELF64
      └── WASM     → WebAssembly binary (.wasm)
```

### Bootstrap Determinism & Binary Security Invariants

- **Stage 1 → Stage 2 → Stage 3 equivalence**: `lipi-seed` builds Stage 1 (`lipc_s1`), Stage 1 builds Stage 2 (`lipc_s2`), and Stage 2 builds Stage 3 (`lipc_s3`). CI verifies byte-for-byte identity (`cmp lipc_s2 lipc_s3`).
- **Static-PIE & W^X (`0 RWE`)**: Emitted Linux ELF64 binaries are statically linked `ET_DYN` (PIE) executables with zero dynamic interpreter (`ld.so` / `libc`) and zero `RWE` writable+executable program segments.

## 2. Memory Model, Deterministic Regions & Static Safety (`--kavach` / `--strict-types`)

Lipi exposes three coordinated memory layers with direct Linux kernel page return (`SYS_madvise(MADV_DONTNEED)`):

1. **Unified Magic-XOR Segregated Slab + Mark-Sweep GC (`_lipi_user_alloc` / `_lipi_gc_collect`)**: All dynamic strings, lists, structs, closures, and file buffers allocate through a thread-safe 9-bucket slab + large-block allocator with 32-byte Magic-XOR (`0x4C474331A55A5AA5 ^ ptr`) headers, ERMS `rep stosq` zero-on-reuse, and double-free guards. The `O(N)` conservative mark-sweep collector reclaims unreachable strings/lists/structs, scrubs idle slab payload words, adapts its auto-GC threshold (`max(512 KB, 2x live)`), and shrinks dead heap tails (`>= 64 KB`) or large freed blocks (`>= 8 KB`) back to Linux physical RAM via `SYS_madvise(MADV_DONTNEED)`. Tunable via `gc_collect()`, `gc_live_bytes()`, `gc_set_threshold(bytes)`, and `gc_set_auto(0|1)`.
2. **Deterministic Scoped Memory Regions (`region ... end` / `অঞ্চল ... শেষ`)**: Captures `arena_mark()` on block entry and deterministically rolls back allocations and returns freed physical pages (`SYS_madvise(MADV_DONTNEED)`) on block exit with zero GC pause.
3. **Direct Kernel Memory (`utso/memory.lp`, `utso/syscalls.lp`)**: Direct page allocation via `SYS_mmap` / `SYS_munmap` and `madvise_dontneed()` (`silicon_madvise_dontneed`) for systems code.

When compiled with `--kavach` (or `--কবচ`):

- The static analyzer tracks allocation ownership to flag leaks and use-after-free paths at compile time.
- Raw hardware primitives (`syscall`, `mem_write`, `mem_read`) are restricted exclusively to functions prefixed with `silicon_` or `সিলিকন_`, isolating unsafe hardware boundaries cleanly from application code.
- Core tools (`lipifmt`, `lipidoc`, `lipi_akhara`) are continuously dogfooded under `--kavach` in CI.

When compiled with `--strict-types`:

- Enforces zero-collision struct field resolution across inferred struct return types, typed parameters, and struct array literals, rejecting ambiguous untyped field offsets and missing struct fields with hard compile errors.

## 3. W^X Code Capsules & Native FFI Isolation

To load binary code safely without introducing RWX memory pages:

- **Signed W^X Capsules (`utso/core/kavach_capsule.lp`)**: Defines the `LPKC` binary capsule format signed with RFC 8032 Ed25519. Code pages are mapped `PROT_READ | PROT_WRITE`, populated and verified (including signed 32-bit `REL32` overflow checks), and transitioned via `SYS_mprotect` to `PROT_READ | PROT_EXEC` before execution. Includes `KavachRing`, a lock-free shared-memory IPC ring buffer.
- **Native ELF Shared-Object Loader (`utso/core/ffi_sovereign.lp`)**: Parses ELF64 headers, maps each `PT_LOAD` segment with strict W^X permissions (never `PROT_READ | PROT_WRITE | PROT_EXEC`), applies `.rela.dyn` relocations, and resolves symbols through `SHF_ALLOC` sections and `sh_link` `.dynstr` tables.

## 4. Cryptography, X.509 PKI & TLS 1.3 Stack

All cryptographic and TLS protocols are implemented directly in Lipi without OpenSSL or system TLS libraries:

- **Primitives (`utso/crypto/`)**:
  - Hashes & KDFs: SHA-256 (`sha256.lp`), SHA-384/512 (`sha512.lp`), HKDF-SHA256/384.
  - AEAD Ciphers: AES-128-GCM, AES-256-GCM (`aes.lp`), ChaCha20-Poly1305 (`advanced.lp`).
  - Asymmetric & Key Exchange: X25519 (`x25519.lp`), Ed25519 (`ed25519.lp`), NIST P-256 & P-384 ECDSA (`p256_ecdsa.lp`), RSA-PSS & RSASSA-PKCS#1 v1.5 (`rsa.lp`).
- **X.509 Certificate Validation (`utso/crypto/x509.lp`)**:
  - ASN.1 DER parsing, RFC 5280 chain signature and `BasicConstraints` verification, certificate validity window checking, RFC 6125 hostname and wildcard verification (rejecting TLD wildcard spoofing such as `*.com`), and system PEM trust-store loading from `/etc/ssl/certs/ca-certificates.crt`.
- **TLS 1.3 Client (`utso/net/tls/tls13.lp`) & HTTPS (`utso/net/http.lp`, `aati/lipi_http_client/`)**:
  - Full cryptographic `CertificateVerify` enforcement for Ed25519, ECDSA P-256/P-384, and RSA-PSS, RFC 8446 16,384-byte record chunking, DNS resolution (`utso/net/dns_pure.lp`), and multi-MB chunked HTTP transfer support.
- **TLS 1.3 Server (`utso/net/tls13_server.lp`)**:
  - X25519 key agreement, RFC 8446 §4.1.4 `HelloRetryRequest` handling, AES-128-GCM / AES-256-GCM / ChaCha20-Poly1305 record protection, browser-compatible NIST P-256 (`0x0403`), NIST P-384 (`0x0503` + SHA-384), and Ed25519 (`0x0807`) signing, SNI multi-domain certificate selection (exact + RFC 6125 single-label wildcards), RFC 8446 PSK Session Resumption (`NewSessionTicket` + constant-time `pre_shared_key` binder verification + `psk_dhe_ke`), and ALPN `h2` / `http/1.1` negotiation. Verified against `openssl s_client -tls1_3` and `curl --tlsv1.3`.
- **HTTP/2 Wire Engine (`utso/net/http2/server.lp`)**:
  - Pure-Lipi RFC 7540 HTTP/2 framing (`SETTINGS`/`ACK`, `PING`/`ACK`, `HEADERS` with `PADDED`/`PRIORITY`, `DATA` chunking, `GOAWAY`) and RFC 7541 HPACK header compression with an `O(1)` canonical Appendix B Huffman decoder. Supports both cleartext `h2c` (TCP prior knowledge) and encrypted `h2` over Pure-Lipi TLS 1.3 ALPN `"h2"`, verified live against `curl` / `nghttp2`.

## 5. Durable WAL Storage & Concurrency

- **Relational SQL Engine (`aati/lipi_sql/src/sql.lp`)**: Dynamic tables and rows, interned text storage, multi-column schema support, CRC-32 `SYS_fsync` write-ahead logging and checkpointing, explicit ACID transactions (`BEGIN`/`COMMIT`/`ROLLBACK` with reverse-LIFO undo log and staged WAL flush on commit), WAL-persisted `O(1)` secondary hash indexes (`CREATE INDEX`), `O(N + M)` `INNER`/`LEFT` hash joins, and `GROUP BY` aggregations (`COUNT`, `SUM`, `MIN`, `MAX`, `AVG`).
- **Persistent Job Queue (`aati/lipi_web/job_queue.lp`)**: Single-lock thread-safe queue over Linux futex/spinlock primitives with CRC-32 `SYS_fsync` WAL durability, automatic `RUNNING` → `PENDING` crash recovery on restart, and log compaction.

## 6. Package Management & Supply-Chain Integrity (`aati`)

`aati` (`src/tools/aati.lp`) manages workspace packages defined in `aati.toml`:

- Computes SHA-256 content digests over package source files and signs/verifies `lipi.sig` manifests with Ed25519.
- Validates workspace integrity against `aati.lock` (`./bin/aati verify-lock aati.lock`) across all 31 packages in `aati/`.
