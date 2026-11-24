# Changelog

All notable changes to the Lipi programming language are documented in this file.

## [1.0.1] — Current (`main`)

### Compiler Middle-End & Register Allocation
- Fixed ABI safety during linear-scan register eviction (`src/compiler/backend/regalloc/linear_scan.lp`): call-spanning intervals now strictly evict only callee-saved candidates instead of inheriting caller-saved scratch registers.
- Tightened call-crossing live-interval analysis (`src/compiler/backend/regalloc/live_interval.lp`) to strict interior crossings (`start_pos < call_pos < end_pos`), eliminating false call-span flags on call results and last-use arguments.
- Extended SSA peephole optimization (`src/compiler/middleend/opt/passes/pass_peephole.lp`) with constant-chain reassociation (`(x + c1) + c2`, `(x - c1) - c2`), shift-chain folding (`(x << c1) << c2`), `x % 1 -> 0`, bitwise `-1` identities, and fixpoint accounting for in-place strength reductions.
- Synchronized `src/boot/lipi-seed` and `src/boot/seed.b64` with the hardened Stage-2 == Stage-3 deterministic compiler.

### TLS 1.3 Server & X.509 PKI
- Added RFC 5280 NIST P-384 X.509 certificate synthesis (`x509_build_signed_p384_cert` in `utso/crypto/x509.lp`) and ECDSA-SHA384 (`0x0503`) `CertificateVerify` handshake signing (`tls13_engine_set_p384_identity`).
- Added SNI multi-domain virtual-host certificate selection (`tls13_engine_add_sni_identity`) supporting exact hostnames and RFC 6125 single-label wildcards with TLD wildcard rejection.
- Implemented RFC 8446 TLS 1.3 Session Resumption (`NewSessionTicket`, `resumption_master_secret`, `psk_key_exchange_modes` `psk_dhe_ke`, constant-time `pre_shared_key` binder verification with tampered-binder rejection, and abbreviated resumed server flights).
- Added ALPN `"h2"` negotiation and binary-safe AEAD record encryption/decryption (`tls13_record_encrypt_raw` / `tls13_record_decrypt_raw`).

### HTTP/2 Wire Protocol (`utso/net/http2/server.lp`)
- Implemented pure-Lipi RFC 7540 HTTP/2 framing (`SETTINGS`/`ACK`, `PING`/`ACK`, `HEADERS` with `PADDED`/`PRIORITY`, `DATA`, `GOAWAY`) with graceful TCP `SHUT_WR` drain close to prevent premature `RST`.
- Implemented RFC 7541 HPACK header block decoding/encoding (static + dynamic tables) and an `O(1)` canonical RFC 7541 Appendix B Huffman decoder.
- Added live `h2c` (TCP prior knowledge) and `h2` (over Pure-Lipi TLS 1.3 ALPN `"h2"`) server drivers, verified live against `curl 8.5.0 / nghttp2 1.59.0`.

### Relational SQL Engine (`aati/lipi_sql/src/sql.lp`)
- Implemented explicit ACID transactions (`BEGIN` / `COMMIT` / `ROLLBACK`) with reverse-LIFO undo logging and staged WAL flushing (`SYS_fsync` only on `COMMIT`).
- Added WAL-persisted `O(1)` secondary hash indexes (`CREATE INDEX`, auto-maintained on `INSERT`/`UPDATE`/`DELETE`/`ROLLBACK`/checkpoint/replay).
- Added `O(N + M)` hash-based `INNER JOIN` and `LEFT JOIN` (`sql_inner_join`, `sql_left_join`) and `GROUP BY` aggregations (`COUNT`, `SUM`, `MIN`, `MAX`, `AVG`).

### CI, Hygiene & Testing
- Migrated remaining legacy `include "std/..."` tests to canonical `utso/` and `aati/` modules.
- Upgraded `.github/workflows/lipi-ci.yml` to Node 24 native Actions (`checkout@v7`, `setup-node@v7`, `upload-artifact@v7`, `download-artifact@v8`).
- Added `tests/test_v101_compiler_opt_regalloc.lp` and `tests/test_v101_deep_upgrades_e2e.lp` expanding the regression suite to 260 tests (`260/260` passing).

---

## [1.0.0]

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
