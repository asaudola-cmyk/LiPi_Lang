# Changelog

All notable changes to the Lipi programming language are documented in this file.

## [1.0.0] — Current (`main`)

### Pure-Lipi Security, Networking, Isolation & Storage
- **Cryptography & X.509 PKI (`utso/crypto/`)**:
  - Added pure-Lipi NIST P-256 and P-384 ECDSA signing and verification (`p256_ecdsa.lp`).
  - Added pure-Lipi RSA-PSS and RSASSA-PKCS#1 v1.5 verification with modular exponentiation (`rsa.lp`).
  - Implemented RFC 5280 X.509 certificate chain validation (Root CA anchoring, BasicConstraints, validity period checks), RFC 6125 hostname/wildcard matching with TLD wildcard spoofing defense, and `/etc/ssl/certs/ca-certificates.crt` PEM trust store loading (`x509.lp`).
- **TLS 1.3 Client & Server (`utso/net/`)**:
  - Full cryptographic `CertificateVerify` enforcement in the TLS 1.3 client across Ed25519, ECDSA P-256/P-384, and RSA-PSS, plus RFC 8446 16,384-byte record fragmentation (`tls/tls13.lp`).
  - Pure-Lipi TLS 1.3 server with X25519 key exchange, HKDF-SHA256 key schedule, AES-128-GCM / ChaCha20-Poly1305 record protection, default browser-compatible ECDSA P-256 (`0x0403`) + Ed25519 (`0x0807`) signing, `ALPN: http/1.1`, and RFC 8446 §4.1.4 `HelloRetryRequest` support (`tls13_server.lp`).
  - Upgraded `utso/net/http.lp` and `aati/lipi_http_client/src/http_client.lp` for end-to-end verified HTTPS and multi-MB chunked transfer handling.
- **W^X Code Capsules & FFI (`utso/core/`)**:
  - Added signed `LPKC` W^X executable capsules and lock-free `KavachRing` shared-memory IPC (`kavach_capsule.lp`).
  - Hardened `ffi_sovereign.lp` ELF shared-object loader to enforce strict W^X `PT_LOAD` page permissions (eliminating RWX `mmap`), `.rela.dyn` relocation handling, and `SHF_ALLOC` + `sh_link` `.dynstr` symbol lookup.
- **Durable WAL Storage (`aati/lipi_sql/`, `aati/lipi_web/`)**:
  - Upgraded `aati/lipi_sql/src/sql.lp` with dynamic tables/rows, arbitrary multi-column WAL replay and checkpointing, text interning, and CRC-32 `SYS_fsync` durability.
  - Hardened `aati/lipi_web/job_queue.lp` with single-lock thread safety, CRC-32 `SYS_fsync` WAL persistence, crash recovery (`RUNNING` → `PENDING`), and log compaction.

### Self-Hosted Compiler & Toolchain
- Deterministic 3-stage self-hosting bootstrap (`src/boot/lipi-seed` → Stage 1 → Stage 2 → Stage 3 binary equivalence) with Static-PIE ELF64 output and `0 RWE` segments.
- Multi-target code generation: Linux x86_64 ELF64, Windows PE32+, macOS Mach-O, ARM64, RISC-V 64, and WebAssembly.
- Static ownership and hardware boundary verification mode (`--kavach`) dogfooded across `lipifmt`, `lipidoc`, and `lipi_akhara`.
- Native Ed25519 cryptographic package manager (`aati`) with `aati.lock` verification across all 31 workspace packages in `aati/`.
- Expanded regression suite to 258 automated tests (`./bin/lipi test`), standalone compile sweep across `utso/`, `aati/`, and `examples/`, and cross-platform CI (Linux, Windows PE32+, macOS Mach-O).

### Repository Cleanup
- Removed obsolete prototype directories, stale draft plans, unrelated external documentation, and outdated marketing assets so the repository contains clean source code, tests, tooling, and factual documentation.
