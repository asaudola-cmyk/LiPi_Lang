# Standard Library & Workspace Packages Reference

Lipi's libraries are organized into two layers:

1. **`utso/`** — Core standard library (freestanding primitives, memory, syscalls, crypto, networking, OS/CPU interfaces).
2. **`aati/`** — 31 signed workspace packages managed by `aati` (`aati.toml` / `aati.lock`).

---

## Core Standard Library (`utso/`)

### Top-Level Convenience Modules

| Module | Purpose |
|---|---|
| `utso/syscalls.lp` | Raw Linux x86_64 kernel syscall wrappers |
| `utso/memory.lp`, `utso/arena.lp` | Kernel `mmap`/`munmap` allocator, raw byte/word memory access, bump arenas |
| `utso/io.lp`, `utso/fmt.lp` | File I/O, stdout/stderr, formatting helpers |
| `utso/string.lp`, `utso/unicode.lp` | UTF-8 string utilities, slicing, splitting, Unicode rune decoding |
| `utso/math.lp` | Integer and floating-point math utilities |
| `utso/collections.lp`, `utso/hashmap.lp` | Lists, dynamic arrays, hash maps |
| `utso/option.lp`, `utso/result.lp`, `utso/error.lp` | Option/Result error handling types |
| `utso/concurrency.lp`, `utso/channel.lp` | Kernel threads (`SYS_clone`), atomics, spinlocks, channels |
| `utso/time.lp` | Monotonic clocks, timestamps, RDTSC cycle reads |
| `utso/socket.lp`, `utso/net.lp` | TCP/UDP sockets, DNS, HTTP, TLS 1.3 |
| `utso/crypto.lp` | Cryptographic primitives entry point |
| `utso/ffi.lp` | Native ELF shared-object loader and C ABI call helpers |

### Core Subdirectories

- **`utso/core/`**:
  - `kavach_capsule.lp` — Signed `LPKC` W^X code capsules, `REL32` bounds verification, and lock-free `KavachRing` IPC
  - `ffi_sovereign.lp`, `c_abi_call.lp` — Strict W^X ELF64 shared-object loader (`.rela.dyn`, `SHF_ALLOC` / `.dynstr`) and System V AMD64 ABI invocation
  - `json.lp`, `json_fast.lp`, `regex.lp`, `fiber_reactor.lp`, `formal_proof.lp`, `simd.lp`, `fs.lp`, `gc.lp`, `graphics_2d.lp`
- **`utso/crypto/`**:
  - `sha256.lp`, `sha512.lp`, `sha1.lp`, `base64.lp`, `random.lp`
  - `aes.lp` (AES-128/256-GCM), `advanced.lp` (ChaCha20-Poly1305)
  - `x25519.lp`, `ed25519.lp`, `p256_ecdsa.lp` (NIST P-256 & P-384 ECDSA), `rsa.lp` (RSA-PSS & PKCS#1 v1.5)
  - `x509.lp` (RFC 5280 chain validation, RFC 6125 hostname/wildcard validation, `/etc/ssl/certs/ca-certificates.crt` loader)
  - `pqc.lp`, `zkp.lp`, `pairing.lp`, `plonk.lp`
- **`utso/net/`**:
  - `tls/tls13.lp`, `tls/record.lp` — Pure-Lipi TLS 1.3 client with PKI and `CertificateVerify` enforcement
  - `tls13_server.lp` — Pure-Lipi TLS 1.3 server (X25519, `HelloRetryRequest`, ECDSA P-256 + Ed25519, `ALPN: http/1.1`)
  - `http.lp`, `http2/`, `http3.lp`, `quic.lp`, `websocket.lp`, `ws_engine.lp`, `ws_wire.lp`
  - `dns_pure.lp`, `dns_client.lp`, `tcp.lp`, `tcp_server.lp`, `udp.lp`, `io_uring_reactor.lp`, `io_uring_ring.lp`, `grpc.lp`, `grpc_server.lp`, `server_production.lp`
- **`utso/cpu/`**: `avx512_native.lp`, `avx512_gemm.lp`, `amx_vnni.lp`
- **`utso/io/`**: `uring.lp`, `uring_sqpoll.lp`, `reactor.lp`, `dma.lp`, `nvme_direct.lp`
- **`utso/os/`**: `syscalls.lp`, `process.lp`, `thread.lp`, `ipc.lp`, `shm.lp`, `fs.lp`, `vfs.lp`, `env.lp`, `path.lp`, `unikernel.lp`, `build_unikernel.lp`, `boot/`, `drivers/`
- **`utso/tools/`**: `cli.lp`, `repl.lp`, `test_runner.lp`, `profiler.lp`, `debugger.lp`, `lsp/`

---

## Workspace Packages (`aati/` — 31 Packages)

Every package under `aati/` contains an `aati.toml` manifest and an Ed25519-signed `lipi.sig` verified by `./bin/aati verify-lock aati.lock`.

| Package | Directory | Summary |
|---|---|---|
| `crypto_vault` | `aati/crypto_vault` | High-level cryptographic helpers and vault primitives |
| `json_toolkit` | `aati/json_toolkit` | Streaming JSON parser and serializer |
| `lipi_ai` | `aati/lipi_ai` | Tensor ops, GGUF model loader, and local inference engine |
| `lipi_blockchain` | `aati/lipi_blockchain` | Merkle trees, EVM bytecode interpreter, and consensus primitives |
| `lipi_boot` | `aati/lipi_boot` | Multiboot ELF kernel entry and bare-metal boot helpers |
| `lipi_browser` | `aati/lipi_browser` | HTML5 DOM parser, CSS Flexbox layout, and framebuffer renderer |
| `lipi_dataframe` | `aati/lipi_dataframe` | Columnar DataFrame analytics engine |
| `lipidb` | `aati/lipidb` | Embedded key-value and MVCC storage engine with WAL |
| `lipi_engine3d` | `aati/lipi_engine3d` | Software 3D rasterizer, linear algebra, and scene graph |
| `lipi_fs` | `aati/lipi_fs` | Copy-on-write filesystem and virtual file table |
| `lipi_gpu` | `aati/lipi_gpu` | SPIR-V binary emitter and compute pipeline helpers |
| `lipi_grpc` | `aati/lipi_grpc` | Binary gRPC wire protocol and Protobuf varint/TLV codec |
| `lipi_gui` | `aati/lipi_gui` | Framebuffer, X11, TUI, and declarative UI primitives |
| `lipi_http_client` | `aati/lipi_http_client` | HTTP/1.1 and verified TLS 1.3 HTTPS client with chunked decoding |
| `lipi_hypervisor` | `aati/lipi_hypervisor` | Linux KVM virtualization interface |
| `lipi_ide` | `aati/lipi_ide` | LSP engine and workspace indexer primitives |
| `lipi_iot` | `aati/lipi_iot` | MQTT protocol codec, sensor telemetry, and GPIO helpers |
| `lipi_jwt` | `aati/lipi_jwt` | RFC 7519 JWT creation and verification |
| `lipi_media` | `aati/lipi_media` | WAV audio synthesis and video canvas primitives |
| `lipi_mobile` | `aati/lipi_mobile` | Touch event dispatcher and responsive layout engine |
| `lipi_p2p` | `aati/lipi_p2p` | Peer-to-peer networking and DHT discovery |
| `lipi_quantum` | `aati/lipi_quantum` | State-vector quantum gate simulator |
| `lipi_registry` | `aati/lipi_registry` | Package registry server and SemVer parser |
| `lipi_security` | `aati/lipi_security` | Seccomp syscall filtering and sandbox policy primitives |
| `lipi_sql` | `aati/lipi_sql` | Dynamic relational SQL engine with CRC-32 `fsync` WAL and checkpointing |
| `lipi_swarm` | `aati/lipi_swarm` | Multi-agent RPC mesh and consensus helpers |
| `lipi_torch` | `aati/lipi_torch` | Tensor autograd and neural network layers |
| `lipi_web` | `aati/lipi_web` | HTTP web server, routing, middleware, and thread-safe WAL-backed job queue |
| `math_extra` | `aati/math_extra` | Extended numeric, linear algebra, and matrix utilities |
| `sovereign_mesh` | `aati/sovereign_mesh` | Peer-to-peer mesh protocol and distributed routing |
| `web_router` | `aati/web_router` | Radix-tree HTTP router |
