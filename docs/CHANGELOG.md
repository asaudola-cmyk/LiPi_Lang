# Changelog

All notable changes to the Lipi programming language are documented in this file.

## [1.0.1] — Current (`main`)

### Core Language, ABI, Runtime & Compiler Honesty
- **Tagged Enums / Algebraic Data Types (ADTs), Compile-Time Monomorphized Generics & Scoped Modules** (`src/compiler/driver.lp`, `pipeline.lp`, `type_checker.lp`, `x86_64/{codegen_core.lp,prescan.lp,synthesizer.lp,codegen_postfix.lp,codegen_expr.lp,codegen_stmt.lp}`):
  - Added first-class `enum` / `ধরন` ADTs (generic & concrete, e.g. `enum Result<T, E>`, `Option<T>`, `Shape`) backed by GC-traced `ADT0` cells with a zero-overhead 2-bit payload tag mask, statement & value-returning `match` variant destructuring, and `?` operator ADT unwrap/early-return.
  - Added compile-time monomorphized generic functions & structs (`fn pair_sum<T>`, `struct Box<T>`, `fn unbox_add<T>(bx: Box<T>, delta: T) -> T`) with explicit (`<float>`, `<int>`, `<str>`) and inferred specialization (0% runtime boxing).
  - Added scoped module visibility (`pub fn`/`pub struct`/`pub enum`/`pub const`) with strict compile-time private-access rejection across both `alias.sym`/`alias::sym` and `from "mod" import a, b as c` while maintaining 100% backwards compatibility for modules with no `pub` declarations.
- **Sovereign Multi-Dependency ELF64 `.so` Loader, Full System V AMD64 C-ABI & Zero-Overhead `LSYM0` Stack Traces** (`utso/core/ffi_sovereign.lp`, `utso/core/c_abi_call.lp`, `x86_64/runtime_trace.lp`):
  - Upgraded pure-Lipi `ffi_sovereign.lp` to load & execute complex multi-dependency system shared libraries (`libfreetype.so.6` v2.13.2 + `libpng16`/`libbrotlidec`/`libbz2`/`libz`, `DT_SYMTAB`/`DT_GNU_HASH`, `RELRO`, TLS, IFUNC) with 0% `ld.so`/`libc`/`libm`.
  - Upgraded `c_abi_call.lp` with full System V AMD64 `c_abi_invoke6` / `c_abi_call` (6 GPR args `rdi..r9`, >6 stack args, `XMM0..XMM7` IEEE-754 double args/return, and W^X capturing Lipi closure callbacks driving native `qsort`).
  - Added zero-overhead `LSYM0` `.rodata` symbol tables providing live `stack_trace()`, trace preservation across `defer` unwinding in `catch`, and automatic uncaught `throw` backtraces with function names and source line numbers.
- **ARM64 & RISC-V 64 Full Feature Parity** (`src/compiler/backend/targets/{riscv64,arm64}/runtime_parity.lp`, `codegen_core.lp`, `codegen_expr.lp`, `codegen_stmt.lp`, `synthesizer.lp`):
  - Ported first-class mutable capturing closures (`CLOS` 0x434C4F53, PC-relative `AUIPC+ADDI` on RV64 & `ADR` on ARM64, heap-boxed upvalue cells, indirect `JALR`/`BLR`), native `DICT0` HashMaps (32B collision-free list/dict headers, FNV-1a string+int hashing, linear probing, tombstones, 2x auto-rehash), native `ByteBuffer` intrinsics, LIFO `defer` replay, and compound assignments (`+=`, `-=`, `*=`, `/=`, `%=`) to both RISC-V 64 and ARM64 (Linux ELF64 & macOS Mach-O). Verified live execution inside Lipi's pure-Lipi RV64 VM (`--run-rv64`, 0% QEMU).
- **Dict Float Preservation, Cross-Frame `defer` Unwinding on `throw`, Null Struct Deref Protection & Stage 3 Diagnostics** (`x86_64/{runtime_dict.lp,runtime_helpers.lp,codegen_*.lp,synthesizer.lp}`, `type_checker.lp`):
  - Preserved IEEE-754 float value tags in `DICT0` lookups across `str()` and binary arithmetic; wired cross-frame LIFO `defer` execution on `throw` unwinding; added catchable `NullPointerException` guards on null struct field dereferences; enabled strict Stage 3 undefined-function diagnostics (supporting indirect/chained closure calls) and stripped Stage 8 debug dumps.
- **Multithreaded `CLONE_VM` Cooperative STW Auto-GC** (`src/compiler/backend/targets/x86_64/runtime_mt_gc.lp`, `utso/os/thread.lp`): Eliminated `SIGSEGV (139)` under multithreaded Auto-GC via a bare-metal 1,024-slot thread stack registry, `IN_SYSCALL` futex tracking, deadlock-free `SIGURG (23)` async spin-preemption (guarding slab/`__alloc` spinlocks), and full all-thread stack + dynamic RW global scanning.
- **Universal Top-Level Non-Integer Globals** (`prescan.lp`, `codegen_stmt.lp`, `synthesizer.lp`, `pipeline.lp`): Top-level strings, lists, structs, floats, and forward-referenced globals (`G_STR`, `G_LIST`, `G_KEEP`, etc.) now initialize cleanly in dynamically-sized RW `.data`/`.bss` (no 448-slot cap) and are traced by GC while preserving function-local lowercase shadowing safety.
- **Untyped Float Call-Site Monomorphization** (`codegen_core.lp`, `prescan.lp`, `synthesizer.lp`, `codegen_expr.lp`): Calling untyped functions with `float` arguments (e.g., `add_untyped(1.25, 2.75)`) automatically specializes a zero-overhead native SSE2 double clone (`__mono_f_f`) while keeping integer call sites untouched.
- **First-Class Silicon `DICT0` HashMap Literals & Dynamic `IntMap`** (`runtime_dict.lp`, `runtime_helpers.lp`, `codegen_expr.lp`, `type_checker.lp`, `pipeline.lp`, `utso/core/hashmap.lp`): Added native Robin-Hood GC-traced `DICT0` literals (`{ "alpha": 10 }`, `{}`, `{:}`, `dict()`, `has_key`, `del_key`, `keys`, `values`) with polymorphic `_lipi_list_get`/`_lipi_list_set`/`_lipi_len` dispatch and dynamic auto-resizing `IntMap`.
- **Closure Mutable Upvalues, Inline `if ; end`, & Order-Independent CLI Flags** (`codegen_core.lp`, `codegen_stmt.lp`, `pipeline.lp`, `src/tools/lipi.lp`): Upgraded upvalue escape analysis to box outer- and inner-mutated captures across all closure forms (single-expr, brace, multiline, top-level); fixed single-line `if 1 == 2 x = 1; x = 2 end` semicolon parsing; upgraded `lipi build` & `lipi fmt` to accept arbitrary multi-flag combinations in any order before or after filenames (`lipi build --strict-types file.lp`, `lipi build --kavach file.lp`).
- Implemented true System V AMD64 Stack ABI (`src/compiler/backend/targets/x86_64/codegen_core.lp`, `codegen_expr.lp`, `codegen_postfix.lp`): arguments `0..5` pass in `rdi..r9` and arguments `6..N-1` spill cleanly onto the 16-byte-aligned call stack (`[rbp + 16 + (i - 6)*8]`), eliminating the 12-argument limit and `%r12–%r15` clobbering.
- Added 12 native x86_64 ERMS (`rep movsb`) `ByteBuffer` and binary-safe `ByteSlice` runtime intrinsics (`buf_new`, `buf_write_mem`, `buf_write_byte`, `buf_write_str`, `buf_to_str`, `bytes_to_str`, `buf_len`, `buf_ptr`, `buf_clear`, `buf_get_byte`, `buf_free`, `buf_slice`) plus `float_to_str`/`print_float` semantic registrations (`runtime_io.lp`, `runtime_helpers.lp`, `type_checker.lp`).
- Upgraded `_lipi_exc_slot_ptr` per-thread exception state from 16 fixed slots to 16 fast L1 inline slots plus a lazy `SYS_mmap` 4,096-slot lock-free CAS open-addressing overflow table (**4,112 concurrent threads**).
- Added auto-boxed 8-byte GC upvalue cells for mutable closures (both local and escaping closures such as `make_counter()`), eliminated `alloc_sz = 1024` bloat on anonymous `{...}` literals, and added automatic struct return-type propagation across `return` statements (`codegen_stmt.lp`, `synthesizer.lp`).
- Added file-level module namespace isolation (`import "path" as alias` + `alias::symbol` mangling) in `src/compiler/driver.lp` while preserving exact top-down chunk ordering.
- Implemented multi-level chained lvalue assignments (`o.inn.arr[1] = 99`, `+=`, `m[i][j]`, `arr[0].inn.arr[0]`) across x86_64 and ARM64 backends, and replaced silent assignment fallthroughs with explicit `[Syntax Error]` diagnostics on invalid lvalue targets.
- Added value-returning `match` expressions (`res = match x ... end` and braced `match x { ... }`) with contextual soft-keyword disambiguation so existing identifiers named `match` (`match = 1`, `if match == 1`) remain valid.
- Added multi-line block closures (`fn(a, b) => { ... }`, `fn(a, b)\n...\nend`, `|a: int, b: int| => { ... }`) with optional `: Type` parameter annotations.
- Added first-class scoped memory regions (`region ... end` / `অঞ্চল ... শেষ`) with deterministic arena rollback and OS physical page return on block exit.
- Added `--strict-types` compile-time struct layout verification (`src/compiler/driver_cli.lp`, `src/compiler/backend/targets/x86_64/prescan.lp`, `codegen_core.lp`, `codegen_expr.lp`, `codegen_postfix.lp`) with automatic struct return-type inference, struct array-element type propagation, and hard errors on colliding untyped field offsets or missing fields.

### Pure-Lipi Core, OS, Concurrency, WAL Storage & Networking (`utso/`)
- **Dynamic HashMap & RFC 8259 JSON**: Added GC-traced Robin-Hood string-keyed `StrDict` (`dict_new`/`set`/`get`/`get_or`/`has`/`delete` with backward-shift delete/`keys`/`values`/`free`) in `utso/core/hashmap.lp`; upgraded `utso/core/json_fast.lp` and `utso/core/json.lp` with IEEE-754 `f64` float parsing (`FAST_JSON_FLOAT`), `O(N)` `ByteBuffer` escaping/unescaping/serialization, and `O(1)` `StrDict` object indexing.
- **OS Environment, Process, FS, PTY & Kernel IPC**: Upgraded `utso/os/env.lp` with mutable `StrDict` environment storage (`env_set`/`env_unset`/`env_all` inherited by child processes) and arbitrary-size `/proc/self/environ` loading; upgraded `utso/os/process.lp` with `O(N)` `ByteBuffer` capture and `process_capture_full` (separate stdout/stderr/stdin pipes, `SYS_poll(7)` multiplexing, `SIGKILL` timeout); upgraded `utso/os/fs.lp` with partial-write loops, `fs_write_atomic` (`fsync`+`rename`), `fs_lock`/`fs_unlock` (`SYS_flock`), and `O(N)` `fs_read_lines`/`fs_read_dir`; added pure-kernel Linux PTY driver `utso/os/pty.lp` (`/dev/ptmx`, `TIOCSPTLCK`, `TIOCGPTN`, `TIOCSCTTY`, `TIOCSWINSZ`); added real kernel pipes (`SYS_pipe2`), `AF_UNIX` socketpairs/stream sockets, and `SYS_memfd_create`+`MAP_SHARED` SHM to `utso/os/ipc.lp`.
- **Linux `SYS_futex` Sync & Worker ThreadPool**: Added `utso/core/sync.lp` (included by `utso/os/thread.lp` and `utso/core/concurrency.lp`) providing Drepper 3-state `FutexMutex`, zero-lost-wakeup `FutexCondvar`, single-word atomic `FutexRwLock`, zero-spin blocking `MPSC` ring channel, and joinable `CLONE_VM` OS worker `ThreadPool`.
- **Crash-Safe Pure-Lipi Binary WAL KV Engine**: Replaced `O(N^2)` array copies in `utso/core/db.lp` with `O(1)` `StrDict` indexing and added disk-persisted `db_open` / `db_compact` / `db_close` / `db_get_opt` featuring binary framed records, IEEE 802.3 CRC-32 verification, `SYS_flock` exclusive locking, `SYS_fsync` durability, torn crash tail auto-truncation (`SYS_ftruncate`), and atomic snapshot compaction.
- **Fast TCP, Portable TLS CA, Real-Time SSE, Full DNS & Concurrent Epoll HTTP/WS Server**: Upgraded `utso/net/tcp.lp` & `utso/core/net.lp` to `O(N)` `bytes_to_str` reads and microsecond `SO_RCVTIMEO`/`SO_SNDTIMEO`; upgraded `utso/net/tls/tls13.lp` with `O(N)` `tls_bytes_to_string` and portable `SSL_CERT_FILE` + multi-distro CA discovery; upgraded `utso/net/http.lp` with `http_put`/`http_delete`/`http_patch`, chunked request body decoding, and incremental real-time SSE streaming (`http_post_stream`/`http_get_stream` over HTTP & HTTPS TLS 1.3); upgraded `utso/net/dns_client.lp` with tab/space `/etc/hosts` (IPv4 & IPv6), UDP `TC=1` TCP fallback, `0xC0` pointer decompression, recursive CNAME following, and `AAAA` resolution; upgraded `utso/net/ws_engine.lp` & `utso/net/server_production.lp` with exact Linux x86_64 12-byte `EPOLL_PACKED` multi-connection reactor, dynamic HTTP/SSE/WS routing (`prod_route_add`, `prod_ws_route_add`, `prod_sse_*`), chunked POST decoding, and full RFC 6455 WebSockets (`Ping`/`Pong`, fragmentation reassembly, binary NUL-safe frames, and `Close` handshake).

### Deterministic Memory Runtime, String/List GC & OS Page Return
- Routed all dynamic strings, lists, structs, closures, and file buffers through a unified 32-byte Magic-XOR-header segregated slab + large-block allocator (`_lipi_user_alloc`) with ERMS `rep stosq` zero-on-reuse and adaptive auto-GC (`max(512 KB, 2x live)`).
- Upgraded `_lipi_gc_collect` to an `O(N)` Magic-XOR conservative mark-sweep collector supporting `STR0` interior string pointers, idle slab payload scrubbing, and dead heap tail shrinking (`>= 64 KB`), plus `gc_live_bytes()`, `gc_set_threshold(bytes)`, and `gc_set_auto(0|1)`.
- Added Linux `SYS_madvise(MADV_DONTNEED)` physical page reclamation across `_lipi_arena_reset`, `_lipi_arena_free_all`, `_lipi_user_free` (`>= 8 KB`), `_lipi_gc_collect`, and `utso/core/memory.lp` (`silicon_madvise_dontneed` / `madvise_dontneed`). Verified live via `/proc/self/status` `VmRSS`: 100k–300k temp strings remain bounded at `~388–616 KB`, and 15–20 MB bursts return physical RAM to Linux (`19,760 KB → 616 KB` via `gc_collect()`, `14,624 KB → 616 KB` via `region ... end`).

### Pure-Kernel Hardware & Media Core (`utso/`)
- Added `utso/os/wayland.lp`: binary Wayland wire protocol over `AF_UNIX`, `SYS_memfd_create`, `SYS_ftruncate`, `MAP_SHARED`, `SYS_sendmsg`/`SYS_recvmsg` `SCM_RIGHTS` FD passing, and `xdg_wm_base` ping/pong dispatch (0% `libwayland`).
- Added `utso/core/simd_raster.lp`: pure-Lipi `ARGB8888` 2D software compositor with 64-bit QWORD paired-pixel clear, Porter-Duff `SRC_OVER` alpha blending, SDF anti-aliased rounded rects, Xiaolin Wu AA lines, and 8-bit glyph mask blitting.
- Added `utso/core/ttf.lp` & `utso/core/shaper.lp`: pure-Lipi TrueType/SFNT parser (`head`, `maxp`, `hhea`, `hmtx`, `cmap` Format 4 & 12, `loca`, `glyf`, `GSUB`, `GPOS`), `ttf_rasterize_gid`, and complete OpenType `GSUB` (Types 1–7) + `GPOS` (Types 1/2/4/6/9) complex script shaper supporting Bengali (`bng2`/`beng` conjuncts `ক্ষ`, split vowels `ো`/`ৌ`, pre-base matra `ি`/`ে`/`ৈ` reordering, Reph `র+্`), Arabic (`isol`/`init`/`medi`/`fina`, mandatory `rlig` `لا`, Mark-to-Base anchors, RTL), and Latin (`liga`/`kern`) with 0% FreeType/HarfBuzz.
- Upgraded `utso/core/png.lp`: full RFC 2083 PNG decoder supporting all 5 color types (Grayscale 0, RGB 2, Indexed `PLTE`+`tRNS` 3, Gray+Alpha 4, RGBA 6), 1/2/4/8/16-bit depths, `tRNS` transparency, and 7-pass Adam7 interlacing (0% `libpng`/`zlib`).
- Upgraded `utso/core/string.lp`: converted `string_join`/`str_join`, `str_repeat`/`string_repeat`, and `str_reverse` from `O(N^2)` concatenation loops to `O(N)` native ERMS `ByteBuffer`.
- Added `utso/net/http2/client.lp` & TLS 1.3 ALPN `"h2"` client support (`utso/net/tls/tls13.lp`): full RFC 9113 multiplexed HTTP/2 client over cleartext `h2c` and TLS 1.3 + ALPN `"h2"` with HPACK static/dynamic/Huffman coding, `PING`, `WINDOW_UPDATE`, `CONTINUATION`, `RST_STREAM`, and `GOAWAY` (0% `nghttp2`/OpenSSL).
- Upgraded `utso/core/ffi_sovereign.lp` & fixed `utso/core/c_abi_call.lp` (`mov rcx, r8` REX prefix `0x4C`): full pure-Lipi ELF64 dynamic linker with `PT_DYNAMIC`, recursive BFS `DT_NEEDED` dependency loading, `O(1)` `DT_GNU_HASH`, `R_X86_64_COPY`, `R_X86_64_IRELATIVE` (IFUNC), Variant-II `PT_TLS` + `SYS_arch_prctl(ARCH_SET_FS)` + CSPRNG `%fs:0x28` stack canary, `DT_INIT_ARRAY` constructors, and Pure-Lipi C-ABI Shim Table (verified live loading & executing system `libz.so.1` `zlibVersion`/`crc32`/`compress2`/`uncompress` with 0% `ld.so`/`dlopen`/`libc`).

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
- Upgraded all process-level termination paths across every native target, stdlib module, and CLI tool to thread-group-safe `SYS_exit_group` (Linux x86_64 `231`, ARM64 & RISC-V `94`, standalone `arm64_emitter.lp`, PE32+ `ExitProcess` rewriter + `__win64_dyn_syscall`, macOS x86_64/ARM64 Mach-O Darwin BSD `SYS_exit` translator, RISC-V VM emulator, `_start` stubs, `exit()`, `process_exit()`, `panic()`, `lipi_exit()`, unhandled `throw`, `__alloc` OOM panic, and all native CLI tools), while preserving single-thread `SYS_exit` (`60`) exclusively for `thread_exit()`, raw `sys_exit()` wrappers, and spawned thread trampolines so detached OS threads never hang process exit.
- Added `tests/test_v101_compiler_opt_regalloc.lp`, `tests/test_v101_deep_upgrades_e2e.lp`, `tests/test_core_language_and_memory.lp`, `tests/test_core_pure_kernel_media.lp`, `tests/test_wave1_abi_buf_closures_modules.lp`, `tests/test_wave3_os_pty_futex_waldb.lp`, `tests/test_wave4_net_sse_dns_epoll_ws.lp`, `tests/test_exit_group_multithreaded.lp`, `tests/test_wave_a_mt_gc_globals.lp`, `tests/test_wave_b_mono_dict_closures_cli.lp`, `tests/test_wave_c_join_png_http2.lp`, `tests/test_wave_d_shaper_ffi.lp`, `tests/test_wave_e_core_fixes.lp`, `tests/test_wave_f_ffi_cabi_trace.lp`, `tests/test_wave_g_adts_generics_modules.lp`, and `tests/test_wave_h_arm64_riscv64_parity.lp`, expanding the regression suite to 274 tests (`274/274` passing) and clean ecosystem compile sweeps (`utso/` + `aati/` + `examples/`).

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
