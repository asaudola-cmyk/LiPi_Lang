# 👑 Lipi Universe Standard Library — Complete API Reference

> **Version:** First 1.0 (প্রথম ১.০) — Sovereign  
> **Architecture:** Direct Machine Code (x86_64, ARM64, WASM)  
> **Zero-Libc / Zero-C / Zero-Python:** 100% Guaranteed Native Silicon  

Welcome to the official, authoritative API reference for **Lipi Universe** (`universe/`).
Lipi is an autonomous, bilingual, high-performance systems and application language
designed from scratch without reliance on GCC, LLVM, Clang, POSIX libc, or external runtimes.

The **Universe** standard library consolidates over 280 modules and 73,000 lines of pure machine-code
algorithms across 14 canonical domains, unified by Directed Acyclic Graph (DAG) layering.

---

## 📑 Table of Contents

1. [Domain 1: Grand Prelude & Unified Umbrella Gateways](#1-grand-prelude--unified-umbrella-gateways)
2. [Domain 2: Core Memory, Arena & Low-Level Foundations](#2-core-memory-arena--low-level-foundations)
3. [Domain 3: High-Throughput Web Engine & HTTP Framework](#3-high-throughput-web-engine--http-framework)
4. [Domain 4: Embedded Database, B+Tree & ACID Storage (LipiKV)](#4-embedded-database-btree--acid-storage-lipikv)
5. [Domain 5: Silicon AI, Vector Mathematics & Tensor Engine](#5-silicon-ai-vector-mathematics--tensor-engine)
6. [Domain 6: Sovereign Networking & Asynchronous Wire Protocols](#6-sovereign-networking--asynchronous-wire-protocols)
7. [Domain 7: FIPS Cryptography, True Kernel Entropy & TLS 1.3](#7-fips-cryptography-true-kernel-entropy--tls-13)
8. [Domain 8: Direct Hardware Framebuffer GUI & 2D Rasterizer](#8-direct-hardware-framebuffer-gui--2d-rasterizer)
9. [Domain 9: Operating System, Syscalls & Bare-Metal Unikernel](#9-operating-system-syscalls--bare-metal-unikernel)
10. [Domain 10: Sovereign Package Management (MPM 2.0)](#10-sovereign-package-management-mpm-20)
11. [Domain 11: Direct GPU SPIR-V Compute & Shader Compiler](#11-direct-gpu-spir-v-compute--shader-compiler)
12. [Domain 12: Silicon CPU Hardware Acceleration & SIMD (AVX2 / AVX-512)](#12-silicon-cpu-hardware-acceleration--simd-avx2--avx-512)
13. [Domain 13: Autonomous Mobile Android DEX Synthesis](#13-autonomous-mobile-android-dex-synthesis)
14. [Domain 14: Universal Code Assimilation & Multi-Language Transpiler](#14-universal-code-assimilation--multi-language-transpiler)
15. [Bilingual English ⇄ Bengali Keyword & Function Dictionary](#15-bilingual-english--bengali-dictionary)

---

## 1. Grand Prelude & Unified Umbrella Gateways

The Lipi standard library provides 7 domain umbrella gateways at `universe/*.lp`.
Instead of manually remembering hundreds of deep internal submodule paths, developers can
import domain gateways directly:

```lipi
import "universe/lipi_universe" // Master prelude (Collections, Arena, SIMD, Crypto, JSON)
import "universe/web"           // High-concurrency web server and routing
import "universe/db"            // Embedded LipiKV, B+Tree, and WAL storage
import "universe/ai"            // AI Tensors, Matrix Multiplication, GGUF
import "universe/net"           // Sockets, HTTP/2, WebSocket, gRPC
import "universe/crypto"        // SHA-256, AES-GCM, TLS 1.3, Entropy
import "universe/gui"           // Direct /dev/fb0 framebuffer and UI chrome
import "universe/os"            // Bare-metal kernel, direct syscalls, threads
```

### Gateway Functions

| Function Signature | Bengali Alias | Description |
| :--- | :--- | :--- |
| `lipi_universe_stats()` | `লিপি_ইউনিভার্স_পরিসংখ্যান()` | Displays active standard library domains, module counts, and hardware verification status. |
| `lipi_hardware_info()` | `লিপি_হার্ডওয়্যার_তথ্য()` | Probes CPUID hardware capabilities (AVX2, AVX-512, cacheline sizes) directly. |
| `lipi_arena_new(capacity)` | `লিপি_নতুন_অ্যারিনা(ক্ষমতা)` | Instantiates a 64-byte aligned sovereign memory arena. |
| `lipi_sha256(s)` | `লিপি_শা২৫৬(লেখা)` | Computes NIST FIPS 180-4 256-bit hexadecimal cryptographic hash. |
| `lipi_db_open(path, capacity)` | `লিপি_ডিবি_ওপেন(পাথ, ক্ষমতা)` | Opens or creates an ACID LipiKV database with Write-Ahead Logging. |
| `lipi_gui_open(w, h)` | `লিপি_গুই_ওপেন(প্রস্থ, উচ্চতা)` | Initializes direct hardware Linux framebuffer or virtual display buffer. |

## 2. Core Memory, Arena & Low-Level Foundations

Direct 64-bit address manipulation and deterministic memory allocation.
Lipi never relies on C malloc/free or POSIX sbrk.

### Module: `universe/core/memory.lp`
- `mem_alloc(bytes) -> ptr`: Allocates contiguous memory via raw Linux kernel SYS_mmap.
- `mem_free(ptr, bytes) -> i64`: Releases memory pages directly to the kernel via SYS_munmap.
- `mem_read_u8(ptr, offset) -> i64`: Reads single unsigned 8-bit byte.
- `mem_write_u8(ptr, offset, val) -> i64`: Writes single unsigned 8-bit byte.
- `mem_read_u32(ptr, offset) -> i64`: Reads 32-bit unsigned integer.
- `mem_write_u32(ptr, offset, val) -> i64`: Writes 32-bit unsigned integer.
- `mem_read_u64(ptr, offset) -> i64`: Reads 64-bit unsigned integer.
- `mem_write_u64(ptr, offset, val) -> i64`: Writes 64-bit unsigned integer.

### Module: `universe/core/arena.lp`
- `arena_create(capacity) -> Arena`: Initializes a high-speed bump-pointer memory arena.
- `arena_alloc(arena, size) -> ptr`: Rapid O(1) contiguous allocation without page fragmentation.
- `arena_alloc_aligned(arena, size, alignment) -> ptr`: Allocates memory strictly aligned to hardware boundaries (e.g. 64-byte AVX-512 cachelines).
- `arena_reset(arena) -> i64`: Rewinds bump offset to 0 for instant bulk reclamation.

### Module: `universe/core/string.lp`
- `str_len(s) -> i64`: Instant O(1) STR0 length lookup.
- `str_concat(s1, s2) -> string`: Zero-copy concatenator with STR0 capacity expansion.
- `str_sub(s, start, end) -> string`: In-place string slice.
- `to_str(val) -> string`: Universal integer/value string formatter.
- `to_int(val) -> i64`: Robust zero-libc integer parser.
- `float_from_str(s) -> f64`: Pure software IEEE-754 decimal parser.
- `str_split(s, sep) -> array`: High-speed string splitter.

### Module: `universe/core/json_fast.lp`
- `fast_json_parse(json_str) -> doc`: Zero-copy linear-time JSON deserializer.
- `fast_json_get(doc, obj_idx, key) -> node_idx`: Fast key lookup.
- `fast_json_get_str(doc, node_idx) -> string`: Extracts unescaped string payload.
- `fast_json_get_int(doc, node_idx) -> i64`: Extracts numeric integer value.
- `fast_json_path(doc, root, path_str) -> node_idx`: Traverses dotted path (e.g. `"user.stats.score"`).

## 3. High-Throughput Web Engine & HTTP Framework

100% native asynchronous HTTP/1.1 and HTTP/2 engine with zero external dependencies.

### Module: `universe/web.lp` & `universe/web/engine.lp`
- `web_app_create() -> WebApp`: Constructs an asynchronous HTTP web application.
- `web_route(app, method, path, handler_fn) -> i64`: Registers high-speed router endpoints with exact and wildcard prefix support.
- `web_listen_and_serve(app, port) -> i64`: Binds non-blocking TCP socket and processes connections via Linux epoll reactor.
- `http_response_ok(body, content_type) -> string`: Packages standard `200 OK` HTTP envelope.
- `http_response_json(json_body) -> string`: Formats `application/json` response with correct `Content-Length` headers.
- `http_response_not_found() -> string`: Packages `404 Not Found` response.

```lipi
import "universe/web"

app = web_app_create()
web_route(app, "GET", "/api/health", @fn(req) return http_response_json("{\"status\":\"ok\"}") @end)
web_listen_and_serve(app, 8080)
```

## 4. Embedded Database, B+Tree & ACID Storage (LipiKV)

Autonomous embedded transactional database engine combining disk B+Tree indexing,
LRU Buffer Pool page cache, and Write-Ahead Logging (WAL).

### Module: `universe/db.lp` & `universe/db/engine.lp`
- `lipi_db_open(path, frame_capacity) -> Database`: Opens or initializes ACID database.
- `db_put(db, key, value) -> i64`: Atomically writes entry to WAL, syncs to disk, and updates memory B+Tree.
- `db_get(db, key) -> string`: Queries value by key through B+Tree and Page Cache.
- `db_delete(db, key) -> i64`: Removes entry under strict WAL logging.
- `db_checkpoint(db) -> i64`: Flushes dirty buffer frames to disk and safely truncates WAL.
- `db_close(db) -> i64`: Syncs pages, closes file descriptors, and releases resources.

### Module: `universe/db/kv.lp` (In-Memory Key-Value Store)
- `KV_create(bucket_count) -> KV`: Instantiates lock-free in-memory key-value dictionary.
- `KV_set(kv, key, val) -> i64`: Stores key-value mapping.
- `KV_get(kv, key) -> string`: Retrieves value.
- `KV_delete(kv, key) -> i64`: Deletes key.

## 5. Silicon AI, Vector Mathematics & Tensor Engine

Direct machine code vector arithmetic, SIMD GEMM matrix multiplication,
activation functions, and native GGUF LLM weight ingestion.

### Module: `universe/ai.lp` & `universe/ai/tensor_engine.lp`
- `tensor_new(rows, cols) -> Tensor`: Allocates 2D tensor in aligned memory.
- `tensor_matmul(A, B) -> Tensor`: Computes General Matrix Multiplication (GEMM) via AVX2 / AVX-512 register tiling.
- `tensor_dot(v1, v2, len) -> i64`: Computes vector dot product in single-instruction SIMD.
- `tensor_relu(t) -> Tensor`: In-place Rectified Linear Unit activation.
- `tensor_sigmoid(t) -> Tensor`: Pure software polynomial Sigmoid transformation.

### Module: `universe/ai/gguf.lp`
- `gguf_open(path) -> GgufModel`: Ingests binary GGUF LLM model headers and tensor metadata.
- `gguf_get_tensor(model, name) -> TensorRef`: Direct zero-copy memory mapped tensor slice.

## 6. Sovereign Networking & Asynchronous Wire Protocols

Raw Linux Berkeley Socket abstraction with direct Linux AMD64 syscall dispatching.

### Module: `universe/net.lp` & `universe/net/socket.lp`
- `socket_tcp() -> fd`: Creates raw `AF_INET (2)`, `SOCK_STREAM (1)` socket.
- `socket_bind(fd, port) -> i64`: Binds network interface without libc `sockaddr_in` overhead.
- `socket_listen(fd, backlog) -> i64`: Places socket into passive listening state.
- `socket_accept(fd) -> client_fd`: Accepts incoming client connection.
- `socket_connect(ip, port) -> fd`: Initiates outbound TCP connection.
- `socket_send(fd, data, len) -> i64`: Direct `SYS_sendto` socket transmission.
- `socket_recv(fd, buf, max_len) -> i64`: Direct `SYS_recvfrom` socket reception.
- `ws_frame_encode(opcode, payload) -> string`: Encodes RFC 6455 WebSocket frame.
- `ws_frame_decode(raw_frame) -> FrameData`: Validates masking key and decodes payload.

## 7. FIPS Cryptography, True Kernel Entropy & TLS 1.3

FIPS 180-4 compliant cryptographic suite with zero OpenSSL or external C dependencies.

### Module: `universe/crypto.lp` & `universe/crypto/sha256.lp`
- `lipi_sha256(s) -> string`: Computes deterministic 64-character hex SHA-256 digest.
- `sha256_init() -> Sha256Context`: Initializes streaming hashing state.
- `sha256_update(ctx, data) -> Sha256Context`: Feeds arbitrary byte streams or strings.
- `sha256_final(ctx) -> array`: Finalizes block padding and returns 32 raw digest bytes.
- `crypto_random_bytes(count) -> array`: Gathers true cryptographic entropy directly from Linux `SYS_getrandom (318)`.

### Module: `universe/crypto/advanced.lp` (NIST SP 800-38D)
- `aes_gcm_encrypt(key, iv, plaintext, aad) -> CipherResult`: Authenticated AES-GCM encryption with 128-bit GHASH authentication tag.
- `aes_gcm_decrypt(key, iv, ciphertext, tag, aad) -> PlainResult`: Constant-time authentication tag verification and decryption.

## 8. Direct Hardware Framebuffer GUI & 2D Rasterizer

Renders graphics directly onto Linux hardware `/dev/fb0` or virtual double-buffered memory.
Zero X11, Zero Wayland, Zero GPU driver dependencies.

### Module: `universe/gui.lp` & `universe/gui/framebuffer.lp`
- `lipi_gui_open(width, height) -> LipiFramebuffer`: Queries hardware screen info via `SYS_ioctl (16)` and establishes double-buffered backbuffer.
- `fb_draw_pixel(fb, x, y, color) -> i64`: Draws 32-bit ARGB pixel at dynamic stride offset.
- `fb_read_pixel(fb, x, y) -> i64`: Inspects color value of backbuffer pixel.
- `fb_fill_rect(fb, x, y, w, h, color) -> i64`: High-speed clipped rectangle fill.
- `fb_window_create(fb, x, y, w, h, title) -> i64`: Renders complete desktop window chrome (Mantle header, border, close button, title text).
- `fb_draw_lipi_icon(fb, x, y) -> i64`: Rasterizes the official Lipi Brand Icon (Cyan vertical stem `#00C2FF`, Magenta base `#FF007A`, Gold loop `#FFD700`).
- `fb_button_create(fb, x, y, w, h, label, is_pressed) -> i64`: Interactive GUI button widget.
- `fb_flip(fb) -> i64`: Blits backbuffer to front video memory for tear-free display.
- `lipi_fb_close(fb) -> i64`: Releases framebuffer video mappings.

## 9. Operating System, Syscalls & Bare-Metal Unikernel

Bare-metal Ring-0 execution and raw Linux kernel ABI bindings.

### Module: `universe/os/syscalls.lp`
- `sys_open(path, flags, mode) -> fd`: Linux SYS_open (syscall 2).
- `sys_close(fd) -> i64`: Linux SYS_close (syscall 3).
- `sys_read(fd, buf, count) -> i64`: Linux SYS_read (syscall 0).
- `sys_write(fd, buf, count) -> i64`: Linux SYS_write (syscall 1).
- `sys_mmap(addr, len, prot, flags, fd, off) -> ptr`: Linux SYS_mmap (syscall 9).
- `sys_munmap(addr, len) -> i64`: Linux SYS_munmap (syscall 11).
- `sys_exit(code)`: Terminates process via Linux SYS_exit (syscall 60).

### Module: `universe/os/kernel_multiboot.lp`
- `kernel_synthesize_multiboot2_image(output_bin)`: Generates raw x86_64 Multiboot2 bootable ELF image with VGA 0xB8000 and COM1 UART 0x3F8 drivers for QEMU bare-metal boot.

## 10. Sovereign Package Management (MPM 2.0)

Deterministic package management with SHA-256 cryptographically locked dependency trees.
- `mpm init`: Initializes a pristine `lipi.pkg` project manifest.
- `mpm add <pkg>`: Registers package dependency and updates manifest.
- `mpm install`: Resolves Directed Acyclic Graph (DAG) and generates bit-for-bit reproducible `lipi.lock`.
- `mpm verify`: Validates hash integrity of all installed artifacts against lockfile.

---

## 11. Direct GPU SPIR-V Compute & Shader Compiler

Pure Lipi binary compiler synthesizing Khronos standard SPIR-V 1.0 binary modules.
- `spirv_build_vector_add_kernel() -> SpirvModule`: Generates Vulkan/OpenCL compute shader.
- `spirv_write_binary(mod, path) -> i64`: Emits byte-aligned SPIR-V binary directly to disk.

---

## 12. Silicon CPU Hardware Acceleration & SIMD (AVX2 / AVX-512)

Direct machine code instruction synthesis exploiting 256-bit YMM and 512-bit ZMM silicon registers.
- `vector_sum_hardware(ptr, count) -> i64`: 8-wide / 16-wide parallel arithmetic reduction.
- `avx512_gemm_4x4_tile(a, b, c, lda, ldb, ldc)`: 4x4 register-tiled matrix multiplication microkernel without stack spills.
- `cpu_has_avx2() -> i64`: Runtime CPUID hardware feature detection.
- `cpu_has_avx512() -> i64`: Probes AVX-512 Foundation (F) and Vector Length Extensions (VL).

---

## 13. Autonomous Mobile Android DEX Synthesis

Pure sovereign DEX bytecode synthesizer producing installable Android binaries without JVM, Gradle, or Android SDK.
- `dex_create_apk(package_name, activity_name) -> ApkBytes`: Emits Android Dalvik Executable with valid Adler32 and SHA-1 checksum headers.
- `LipiNativeActivity.lipi`: Sovereign mobile application entry point.

---

## 14. Universal Code Assimilation & Multi-Language Transpiler

In-memory AST lowering engine converting legacy languages into canonical Lipi 2.0 source.
- `assimilate_python_source(py_code) -> string`: Lowers Python function definitions, indentation blocks, and control flow into pure Lipi AST.
- `assimilate_c_source(c_code) -> string`: Strips C-style braces, semicolon delimiters, and types into idiomatic Lipi syntax.
- `assimilate_file_to_lipi(in_path, out_path) -> i64`: Complete end-to-end file migration pipeline.

---

## 15. Bilingual English ⇄ Bengali Dictionary

Lipi is the world's first fully bilingual sovereign programming language.
Any English keyword or function in Universe can be interchanged with its canonical Bengali equivalent.

| English Keyword / Function | Bengali Keyword / Function | Domain |
| :--- | :--- | :--- |
| `say` / `print` / `println` | `বলো` / `দেখাও` | Standard Output |
| `if` / `elif` / `else` | `যদি` / `নাহলে_যদি` / `নাহলে` | Control Flow |
| `while` / `for` | `যতক্ষণ` / `জন্য` | Iteration Loops |
| `return` | `ফেরত` | Function Termination |
| `lipi_universe_stats()` | `লিপি_ইউনিভার্স_পরিসংখ্যান()` | Grand Prelude |
| `lipi_hardware_info()` | `লিপি_হার্ডওয়্যার_তথ্য()` | Silicon Introspection |
| `lipi_arena_new()` | `লিপি_নতুন_অ্যারিনা()` | Core Arena Memory |
| `lipi_sha256()` | `লিপি_শা২৫৬()` | Cryptography |
| `lipi_db_open()` | `লিপি_ডিবি_ওপেন()` | Database Engine |
| `lipi_gui_open()` | `লিপি_গুই_ওপেন()` | Framebuffer GUI |
| `to_int()` | `লিপি_ইন্টে_রূপান্তর()` | String Conversion |
| `str_upper()` | `বড়_অক্ষর()` | String Case |
| `str_lower()` | `ছোট_অক্ষর()` | String Case |
| `str_trim()` | `ছাঁটাই()` | String Cleaning |

---

> *Generated autonomously by Lipi Sovereign DocGen Engine (`tools/universe_docgen.lp`).*
> *100% Pure Lipi Machine Code Engine | 0% Libc | 0% Python | 0% C.*
