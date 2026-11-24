# Changelog

All notable changes to the Lipi programming language are documented in this file.

## [1.0.1] — Current (`main`)

### Core Language & Compiler Honesty
- Implemented multi-level chained lvalue assignments (`o.inn.arr[1] = 99`, `+=`, `m[i][j]`, `arr[0].inn.arr[0]`) across x86_64 and ARM64 backends, and replaced silent assignment fallthroughs with explicit `[Syntax Error]` diagnostics on invalid lvalue targets.
- Added value-returning `match` expressions (`res = match x ... end` and braced `match x { ... }`) with contextual soft-keyword disambiguation so existing identifiers named `match` (`match = 1`, `if match == 1`) remain valid.
- Added multi-line block closures (`fn(a, b) => { ... }`, `fn(a, b)\n...\nend`, `|a: int, b: int| => { ... }`) with optional `: Type` parameter annotations.
- Added first-class scoped memory regions (`region ... end` / `অঞ্চল ... শেষ`) with deterministic arena rollback and OS physical page return on block exit.
- Added `--strict-types` compile-time struct layout verification (`src/compiler/driver_cli.lp`, `src/compiler/backend/targets/x86_64/prescan.lp`, `codegen_core.lp`, `codegen_expr.lp`, `codegen_postfix.lp`) with automatic struct return-type inference, struct array-element type propagation, and hard errors on colliding untyped field offsets or missing fields.

### Deterministic Memory Runtime, String/List GC & OS Page Return
- Routed all dynamic strings, lists, structs, closures, and file buffers through a unified 32-byte Magic-XOR-header segregated slab + large-block allocator (`_lipi_user_alloc`) with ERMS `rep stosq` zero-on-reuse and adaptive auto-GC (`max(512 KB, 2x live)`).
- Upgraded `_lipi_gc_collect` to an `O(N)` Magic-XOR conservative mark-sweep collector supporting `STR0` interior string pointers, idle slab payload scrubbing, and dead heap tail shrinking (`>= 64 KB`), plus `gc_live_bytes()`, `gc_set_threshold(bytes)`, and `gc_set_auto(0|1)`.
- Added Linux `SYS_madvise(MADV_DONTNEED)` physical page reclamation across `_lipi_arena_reset`, `_lipi_arena_free_all`, `_lipi_user_free` (`>= 8 KB`), `_lipi_gc_collect`, and `utso/core/memory.lp` (`silicon_madvise_dontneed` / `madvise_dontneed`). Verified live via `/proc/self/status` `VmRSS`: 100k–300k temp strings remain bounded at `~388–616 KB`, and 15–20 MB bursts return physical RAM to Linux (`19,760 KB → 616 KB` via `gc_collect()`, `14,624 KB → 616 KB` via `region ... end`).

### Pure-Kernel Hardware & Media Core (`utso/`)
- Added `utso/os/wayland.lp`: binary Wayland wire protocol over `AF_UNIX`, `SYS_memfd_create`, `SYS_ftruncate`, `MAP_SHARED`, `SYS_sendmsg`/`SYS_recvmsg` `SCM_RIGHTS` FD passing, and `xdg_wm_base` ping/pong dispatch (0% `libwayland`).
- Added `utso/core/simd_raster.lp`: pure-Lipi `ARGB8888` 2D software compositor with 64-bit QWORD paired-pixel clear, Porter-Duff `SRC_OVER` alpha blending, SDF anti-aliased rounded rects, Xiaolin Wu AA lines, and 8-bit glyph mask blitting.
- Added `utso/core/ttf.lp`: pure-Lipi TrueType (`.ttf` / SFNT) parser (`head`, `maxp`, `hhea`, `hmtx`, `cmap` Format 4 & 12, `loca` 16/32-bit, `glyf` quadratic Bézier contours) and 4x4 supersampled AA scanline rasterizer (0% FreeType).
- Added `utso/core/png.lp`: pure-Lipi RFC 2083 PNG encoder/decoder with IEEE CRC-32, Adler-32, RFC 1950/1951 DEFLATE Inflate (Stored/Fixed/Dynamic Huffman + LZ77), and all 5 PNG scanline filters (0% `libpng`/`zlib`).

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
- Added `tests/test_v101_compiler_opt_regalloc.lp`, `tests/test_v101_deep_upgrades_e2e.lp`, `tests/test_core_language_and_memory.lp`, and `tests/test_core_pure_kernel_media.lp`, expanding the regression suite to 262 tests (`262/262` passing).

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
