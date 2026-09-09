# 📜 Lipi Sovereign Standard Library Manual

## Overview
The Lipi standard library (`std/`) is written in 100% pure Lipi code and relies directly on native Linux kernel syscalls. It requires zero shared libraries (`.so`), zero dynamic linking, and zero C runtime wrappers.

---

## Module Index

### 1. Core Runtime
- **`std/io.lp`**: Direct Linux kernel standard I/O and file descriptor routines (`কনসোল_লেখো`, `ফাইল_তৈরি`, `ফাইল_খোলো`, `ফাইল_পড়ো`, `ফাইল_লেখো`, `ফাইল_বন্ধ`).
- **`std/mem.lp`**: Direct heap page allocation via kernel `SYS_mmap` and `SYS_munmap`, raw byte/word read/write, `memcpy`, and `memset`.
- **`std/str.lp`**: UTF-8 string utilities, byte-by-byte comparisons (`strcmp`), length calculation, and ANSI TrueColor terminal formatting.
- **`std/math.lp`**: Fast integer arithmetic, absolute value, power, square root approximation, and min/max operations.
- **`std/time.lp`**: Nanosecond-accurate time retrieval via `SYS_clock_gettime` (CLOCK_REALTIME & CLOCK_MONOTONIC).

### 2. Systems & Concurrency
- **`std/kernel.lp`**: Bare-metal Multiboot-1 specification (0x1BADB002) header generator and physical VGA Text Mode framebuffer (0xB8000).
- **`std/thread.lp`**: Native kernel multithreading using `SYS_clone` (Syscall 56), TLS thread stacks, and spinlocks.
- **`std/event.lp`**: Scalable asynchronous event notification using Linux kernel `epoll` (`epoll_create1`, `epoll_ctl`, `epoll_wait`).
- **`std/shm.lp`**: Cross-process shared memory IPC via POSIX shared memory and `SYS_mmap`.
- **`std/arena.lp`**: Ultra-fast O(1) Bump-pointer Arena memory allocator for high-throughput batch operations.

### 3. Networking & Cryptography
- **`std/net.lp`**: Direct Berkeley socket API via `SYS_socket`, `SYS_bind`, `SYS_listen`, `SYS_accept`, `SYS_connect`.
- **`std/tls.lp`**: RFC 8439 ChaCha20-Poly1305 symmetric cipher stream and TLS 1.3 frame serialization in pure Lipi.
- **`std/websocket.lp`**: RFC 6455 real-time bidirectional WebSocket binary framing and text opcode engine.
- **`std/crypto.lp`**: Hardware NIST FIPS 180-4 SHA-256 cryptographic digest engine.

### 4. Databases & Artificial Intelligence
- **`std/db.lp`**: Embedded B-tree indexed append-only binary vault database engine.
- **`std/hashmap.lp`**: Cache-conscious Robin Hood open-addressing hash table with backward-shift deletion.
- **`std/columnstore.lp`**: Vectorized columnar analytical query storage engine for fast aggregations.
- **`std/ai.lp`**: Pure silicon matrix math, dot-product, and cosine similarity vector operations.
- **`std/simd.lp`**: Vectorized matrix multiplication engine.
- **`std/gguf.lp`**: GGUF v3 model parser and Q4_0 4-bit quantized tensor inference engine.

### 5. Graphics & User Interfaces
- **`std/tui.lp`**: Full-screen ANSI terminal user interface with window panes, borders, and input loops.
- **`std/gfx.lp`**: 2D graphics rasterizer with lines, rectangles, circles, and 24-bit uncompressed BMP serialization.
- **`std/x11.lp`**: Pure socket-based X11 client protocol communicating directly with `/tmp/.X11-unix/X0`.
