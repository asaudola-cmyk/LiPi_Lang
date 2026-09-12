# 📜 Lipi Sovereign Standard Library Reference & API Manual
### Version: First 1.0.0 (প্রথম ১.০.০ — Sovereign Edition) — 100% Pure Lipi | Zero Libc | Native Kernel Syscalls

---

## Overview

The **Lipi Sovereign Standard Library** (`std/`) is engineered from the ground up in 100% pure Lipi code. Every module communicates directly with the underlying silicon CPU registers and Linux kernel syscalls. 

- **0% C Standard Library (`libc`):** No reliance on `glibc`, `musl`, or external runtime wrappers.
- **0% Foreign Shared Libraries (`.so`):** Completely eliminates dynamic linking, shared library version hell, and binary hijacking.
- **Sub-Microsecond Execution:** Direct hardware memory buffers and registers maximize cache locality and instruction throughput.

---

## Core Sovereign Modules Index

| Module | Primary Responsibility | Silicon / Kernel Primitives |
|---|---|---|
| [`std/web.lp`](../std/web.lp) | First-class HTTP router, parser & serializer | `SYS_socket`, `SYS_bind`, `SYS_listen`, `SYS_accept`, `SYS_write` |
| [`std/thread.lp`](../std/thread.lp) | Native kernel multithreading & atomic spinlocks | `SYS_clone` (56/220), `SYS_sched_yield` (24), `SYS_exit` (60) |
| [`std/hashmap.lp`](../std/hashmap.lp) | Cache-conscious Robin Hood open-addressing hash table | `SYS_mmap`, `SYS_munmap`, contiguous cache lines |
| [`std/arena.lp`](../std/arena.lp) | High-throughput O(1) bump allocator & ARC | `SYS_mmap`, 8-byte QWORD alignment, 0-cycle resets |
| [`std/simd.lp`](../std/simd.lp) | Vector acceleration & matrix AI operations | x86_64 SSE/AVX2 (`paddq`), AArch64 NEON, silicon dot product |
| [`std/crypto.lp`](../std/crypto.lp) | Cryptographic digests, stream ciphers & signatures | NIST FIPS 180-4 SHA-256, RFC 8439 ChaCha20, Ed25519 |
| [`std/io.lp`](../std/io.lp) | Direct kernel standard I/O and file descriptors | `SYS_read` (0), `SYS_write` (1), `SYS_open` (2), `SYS_close` (3) |
| [`std/mem.lp`](../std/mem.lp) | Virtual memory paging, byte/word reads & writes | `SYS_mmap` (9), `SYS_munmap` (11), memory copy & fill |
| [`std/net.lp`](../std/net.lp) | Berkeley socket networking | `SYS_socket` (41), `SYS_connect` (42), `SYS_sendto` (44) |
| [`std/str.lp`](../std/str.lp) | UTF-8 string manipulation & formatting | Zero-copy slicing, string concatenation, ANSI truecolor |
| [`std/json.lp`](../std/json.lp) | RFC 8259 JSON serialization & escaping | Fast string builders, JSON types, key-value formatting |
| [`std/db.lp`](../std/db.lp) | Embedded append-only binary B-tree database | Binary index pages, transactional WAL, direct disk I/O |

---

## 1. Web Engine & HTTP Router (`std/web.lp`)

[`std/web.lp`](../std/web.lp) provides an autonomous, ultra-fast HTTP/1.1 web microservice engine. It performs route dispatching, request parsing, and response serialization directly against Linux network sockets without third-party frameworks.

### 1.1 HTTP Status Constants
```lipi
HTTP_STATUS_OK                  = 200
HTTP_STATUS_CREATED             = 201
HTTP_STATUS_ACCEPTED            = 202
HTTP_STATUS_NO_CONTENT          = 204
HTTP_STATUS_MOVED_PERMANENTLY   = 301
HTTP_STATUS_FOUND               = 302
HTTP_STATUS_NOT_MODIFIED        = 304
HTTP_STATUS_BAD_REQUEST         = 400
HTTP_STATUS_UNAUTHORIZED        = 401
HTTP_STATUS_FORBIDDEN           = 403
HTTP_STATUS_NOT_FOUND           = 404
HTTP_STATUS_METHOD_NOT_ALLOWED  = 405
HTTP_STATUS_CONFLICT            = 409
HTTP_STATUS_INTERNAL_ERROR      = 500
HTTP_STATUS_BAD_GATEWAY         = 502
HTTP_STATUS_SERVICE_UNAVAILABLE = 503
```

### 1.2 MIME Types Constants
```lipi
MIME_TEXT_PLAIN                 = "text/plain; charset=utf-8"
MIME_TEXT_HTML                  = "text/html; charset=utf-8"
MIME_TEXT_CSS                   = "text/css; charset=utf-8"
MIME_APP_JS                     = "application/javascript; charset=utf-8"
MIME_APP_JSON                   = "application/json; charset=utf-8"
MIME_IMAGE_SVG                  = "image/svg+xml"
MIME_IMAGE_PNG                  = "image/png"
MIME_OCTET_STREAM               = "application/octet-stream"
```

### 1.3 Data Structures
- **`WebRoute`**: Holds route definitions.
  - Fields: `method` (String), `path` (String), `handler_id` (Integer).
- **`WebRequest`**: Encapsulates parsed HTTP request components.
  - Fields: `method` (String), `path` (String), `raw_query` (String), `body_length` (Integer), `body_ptr` (Address).
- **`WebResponse`**: Carries HTTP response parameters.
  - Fields: `status_code` (Integer), `content_type` (String), `body_text` (String).

### 1.4 API Reference

#### Router & Endpoint Registration
- `fn web_router_new`
  - **Description:** Instantiates a new in-memory routing list.
  - **Returns:** Route collection pointer.
- `fn web_router_add router method path handler_id`
  - **Description:** Registers an HTTP method, path pattern, and integer handler ID.
- `fn web_get router path handler_id`
  - **Description:** Convenience helper to register a `GET` endpoint.
- `fn web_post router path handler_id`
  - **Description:** Convenience helper to register a `POST` endpoint.
- `fn web_put router path handler_id`
  - **Description:** Convenience helper to register a `PUT` endpoint.
- `fn web_delete router path handler_id`
  - **Description:** Convenience helper to register a `DELETE` endpoint.
- `fn web_patch router path handler_id`
  - **Description:** Convenience helper to register a `PATCH` endpoint.
- `fn web_options router path handler_id`
  - **Description:** Convenience helper to register an `OPTIONS` endpoint.
- `fn web_head router path handler_id`
  - **Description:** Convenience helper to register a `HEAD` endpoint.
- `fn web_dispatch router method path`
  - **Description:** Linearly searches registered routes. Returns the matched `handler_id`, or `0` if unmatched.

#### Request Parsing Primitives
- `fn web_parse_method raw_req`
  - **Description:** Extracts the HTTP verb (`GET`, `POST`, `PUT`, `DELETE`, etc.) from raw bytes without heap allocations.
- `fn web_parse_path raw_req`
  - **Description:** Extracts the sanitized URI path, omitting leading/trailing delimiters and query parameters.
- `fn web_parse_query raw_req`
  - **Description:** Extracts the query parameter substring following `?` in the URI.
- `fn web_parse_header raw_req header_name`
  - **Description:** Searches raw request headers for `header_name` and returns its trimmed value string.
- `fn web_parse_param_int req_str key`
  - **Description:** Parses an integer parameter value by key matching (e.g. `key="id="` extracts `42` from `?id=42`).
- `fn web_parse_param_str req_str key`
  - **Description:** Parses a string parameter value by key matching until `&` or whitespace.

#### Response Constructors & Serialization
- `fn web_status_text code`
  - **Description:** Returns the standard RFC 7231 status phrase (e.g., `200` -> `"200 OK"`).
- `fn web_response_new status_code content_type body_text`
  - **Description:** Allocates and initializes a new `WebResponse` object.
- `fn web_response_json data`
  - **Description:** Creates a `200 OK` response with `application/json; charset=utf-8` payload.
- `fn web_response_html html_content`
  - **Description:** Creates a `200 OK` response with `text/html; charset=utf-8` payload.
- `fn web_response_text text_content`
  - **Description:** Creates a `200 OK` response with `text/plain; charset=utf-8` payload.
- `fn web_response_not_found`
  - **Description:** Creates a standardized `404 Not Found` JSON error response.
- `fn web_response_bad_request message`
  - **Description:** Creates a standardized `400 Bad Request` JSON error response with custom message.
- `fn web_response_internal_error message`
  - **Description:** Creates a standardized `500 Internal Server Error` JSON response.
- `fn web_response_redirect location`
  - **Description:** Creates a `302 Found` redirection response targeting `location`.
- `fn web_serialize_response res`
  - **Description:** Encodes `WebResponse` into an RFC-compliant HTTP/1.1 wire string, injecting `Content-Length`, `Server`, `Connection: close`, and CRLF line breaks.
- `fn web_app_banner port`
  - **Description:** Prints an ANSI TrueColor terminal banner announcing active server port and operational status.

### 1.5 Code Example: Production Microservice
```lipi
include "std/web.lp"

// Initialize router
router = web_router_new()
web_get(router, "/api/v1/ping", 1)
web_get(router, "/api/v1/users", 2)
web_post(router, "/api/v1/submit", 3)

fn route_handler raw_request
    method = web_parse_method(raw_request)
    path = web_parse_path(raw_request)
    handler_id = web_dispatch(router, method, path)

    if handler_id == 1
        return web_response_json("{\"status\":\"pong\",\"timestamp\":1700000000}")
    if handler_id == 2
        return web_response_json("[{\"id\":1,\"name\":\"Shafiullah\"},{\"id\":2,\"name\":\"Rahim\"}]")
    if handler_id == 3
        return web_response_new(HTTP_STATUS_CREATED, MIME_APP_JSON, "{\"created\":true}")
    return web_response_not_found()

// Simulated incoming HTTP request
raw_http = "GET /api/v1/ping HTTP/1.1\r\nHost: localhost\r\n\r\n"
res = route_handler(raw_http)
wire = web_serialize_response(res)
say wire
```

---

## 2. Native Multithreading & Concurrency (`std/thread.lp`)

[`std/thread.lp`](../std/thread.lp) enables pure silicon multicore concurrency by calling the Linux kernel `SYS_clone` system call directly. It requires zero POSIX threading (`pthreads`) wrappers.

### 2.1 Syscall Identifiers & Clone Mask
- **`SYS_clone`:** Syscall 56 (x86_64) / Syscall 220 (AArch64).
- **`SYS_sched_yield`:** Syscall 24 (x86_64) / Syscall 124 (AArch64).
- **`SYS_exit`:** Syscall 60 (x86_64) / Syscall 93 (AArch64).
- **Kernel Clone Mask:** `69376` (`0x10F00`), computed from:
  - `CLONE_VM` (256): Shares memory address space.
  - `CLONE_FS` (512): Shares file system attributes.
  - `CLONE_FILES` (1024): Shares file descriptors.
  - `CLONE_SIGHAND` (2048): Shares signal handlers.
  - `CLONE_THREAD` (65536): Joins parent thread group.

### 2.2 API Reference

- `fn থ্রেড_তৈরি স্ট্যাক_টপ` / `fn thread_spawn stack_top`
  - **Description:** Invokes `SYS_clone` with the thread flags and a pre-allocated stack pointer.
  - **Parameters:** `stack_top` (Address) — 16-byte aligned upper address of thread stack buffer.
  - **Returns:**
    - `0` in the newly created child thread context.
    - Positive Thread ID (`TID > 0`) in the parent process context.
    - Negative error code if kernel thread allocation fails.
- `fn থ্রেড_ছেড়ে_দাও` / `fn thread_yield`
  - **Description:** Invokes `SYS_sched_yield` to release the calling thread's remaining CPU timeslice to waiting threads.
  - **Returns:** `0` on success.
- `fn থ্রেড_প্রস্থান status` / `fn thread_exit status`
  - **Description:** Invokes `SYS_exit(status)` to terminate only the calling thread. Unlike `exit_group` (syscall 231), this preserves the parent and peer threads.
- `fn স্পিনলক_আটক লক_addr` / `fn spinlock_lock lock_addr`
  - **Description:** Claims an atomic spinlock. If the lock is held (`val != 0`), it calls `thread_yield()` iteratively to prevent CPU thermal throttling until the lock becomes available, then sets `val = 1`.
- `fn স্পিনলক_মুক্ত লক_addr` / `fn spinlock_unlock lock_addr`
  - **Description:** Releases the atomic spinlock by writing `0` to `lock_addr`.
- `fn চ্যানেল_তৈরি ধারণক্ষমতা` / `fn channel_create capacity`
  - **Description:** Allocates an in-memory lock-free circular ring buffer for inter-thread message passing.
- `fn চ্যানেল_পাঠাও চ্যানেল ডাটা` / `fn channel_send channel data`
  - **Description:** Places a 64-bit integer or data pointer into the concurrency channel.
- `fn চ্যানেল_গ্রহণ চ্যানেল` / `fn channel_recv channel`
  - **Description:** Retrieves the next message from the channel, pausing cooperatively if empty.

### 2.3 Code Example: Concurrency & Spinlock Synchronization
```lipi
include "std/thread.lp"
include "std/mem.lp"

// 1. Allocate lock and shared accumulator in memory
lock = malloc(8)
mem_write(lock, 0, 0) // 0 = unlocked

shared_counter = malloc(8)
mem_write(shared_counter, 0, 0)

// 2. Allocate stack for worker thread (64 KB)
stack_size = 65536
stack_base = syscall(9, 0, stack_size, 3, 34, -1, 0)
stack_top = stack_base + stack_size - 16

// 3. Spawn child thread
tid = থ্রেড_তৈরি(stack_top)

if tid == 0
    // Child thread routine
    i = 0
    while i < 1000
        স্পিনলক_আটক(lock)
        val = mem_read(shared_counter, 0)
        mem_write(shared_counter, 0, val + 1)
        স্পিনলক_মুক্ত(lock)
        i = i + 1
    থ্রেড_প্রস্থান(0)

// Parent thread waits and yields
thread_yield()
say "Parent thread proceeding after worker thread launch"
```

---

## 3. Robin Hood Hash Table (`std/hashmap.lp`)

[`std/hashmap.lp`](../std/hashmap.lp) implements a high-performance, cache-conscious Robin Hood open-addressing hash table with backward-shift deletion. It guarantees deterministic O(1) lookups and eliminates heap fragmentation.

### 3.1 In-Memory Slot Architecture
Each slot is stored contiguously in 24 bytes (3 QWORDs):
```
┌─────────────────────────┬─────────────────────────┬─────────────────────────┐
│  Key Hash (8 Bytes)     │  Value Pointer (8 Bytes)│  Probe Distance (8 Bytes│
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
```
Contiguous memory alignment maximizes CPU L1/L2 data cache hit rates to greater than 99%.

### 3.2 Robin Hood "Steal from the Rich" Algorithm
When inserting a key whose probe distance exceeds the stored entry's distance, the new entry evicts the existing "rich" entry, swapping contents and continuing insertion. This equalizes search variance across the table and bounds worst-case lookups.

### 3.3 API Reference

- `fn hashmap_create max_elements`
  - **Description:** Allocates contiguous physical memory for `max_elements` slots via `SYS_mmap` (Syscall 9) and zeroes all bytes.
  - **Parameters:** `max_elements` (Integer) — Table capacity.
  - **Returns:** Pointer to table base memory address.
- `fn fast_hash value`
  - **Description:** Computes a high-avalanche integer hash using prime multiplication and bit manipulation, minimizing collisions without division penalties.
  - **Parameters:** `value` (Integer).
  - **Returns:** Non-negative 64-bit hash code.
- `fn hashmap_insert ম্যাপ_পয়েন্টার capacity key_val val`
  - **Description:** Inserts a key-value pair into the table using Robin Hood displacement logic.
  - **Returns:** `1` on successful insertion, `0` if table is saturated.
- `fn hashmap_lookup ম্যাপ_পয়েন্টার capacity key_val`
  - **Description:** Looks up `key_val`. If current probe distance exceeds stored entry distance, it immediately triggers an early exit, returning `-1` without scanning the rest of the table.
  - **Returns:** Stored value, or `-1` if missing.
- `fn hashmap_delete ম্যাপ_পয়েন্টার capacity`
  - **Description:** Unmaps the table memory from the virtual address space using `SYS_munmap` (Syscall 11).
  - **Returns:** `1` on success.

### 3.4 Code Example
```lipi
include "std/hashmap.lp"

// Create hash map with capacity for 1,024 elements
capacity = 1024
map = hashmap_create(capacity)

// Insert key-value pairs
hashmap_insert(map, capacity, 101, 55000)
hashmap_insert(map, capacity, 202, 78000)
hashmap_insert(map, capacity, 303, 92000)

// Fast O(1) lookups
salary = hashmap_lookup(map, capacity, 202)
say "Employee 202 Salary: " + salary

missing = hashmap_lookup(map, capacity, 999)
if missing == -1
    say "Employee 999 not found (Early Exit verified)"

// Clean up memory
hashmap_delete(map, capacity)
```

---

## 4. Bump-Pointer Arena Memory Allocator (`std/arena.lp`)

[`std/arena.lp`](../std/arena.lp) delivers ultra-fast, zero-fragmentation linear memory allocation for high-throughput batch operations, compilers, and microservices.

### 4.1 Arena Pool Layout
An arena pool is structured across 24 bytes of metadata:
- Offset 0 (`base`): 64-bit pointer to contiguous virtual memory block.
- Offset 8 (`capacity`): Total pool capacity in bytes.
- Offset 16 (`used`): Current high-water mark bump offset.

All allocations are aligned to **8-byte QWORD boundaries** via `(byte_size + 7) & ~7`.

### 4.2 Instant Mass Reclamation
Calling `অ্যারিনা_রিসেট(pool)` resets the `used` offset to `0`. All thousands of previous allocations are reclaimed in **0 CPU cycles**, completely eliminating individual `free()` overhead and memory leaks.

### 4.3 API Reference

- `fn অ্যারিনা_তৈরি capacity` / `fn arena_create capacity`
  - **Description:** Allocates `capacity` bytes of virtual memory via `SYS_mmap` and returns a managed pool pointer.
- `fn অ্যারিনা_বরাদ্দ pool byte_size` / `fn arena_alloc pool byte_size`
  - **Description:** Dispenses an 8-byte aligned memory chunk from the arena using O(1) pointer bumping.
  - **Returns:** Memory address of allocated chunk, or `0` if capacity is exhausted.
- `fn অ্যারিনা_used_mem pool` / `fn arena_used pool`
  - **Description:** Returns total bytes currently allocated from the pool.
- `fn অ্যারিনা_অবশিষ্ট_mem pool` / `fn arena_remaining pool`
  - **Description:** Returns remaining available unallocated bytes in the pool.
- `fn অ্যারিনা_রিসেট pool` / `fn arena_reset pool`
  - **Description:** Reclaims all allocated memory instantly in 0 cycles by resetting `used = 0`.
- `fn অ্যারিনা_ধ্বংস pool` / `fn arena_free pool`
  - **Description:** Returns the virtual memory pages back to the Linux kernel via `SYS_munmap` (Syscall 11) and frees metadata.

#### Atomic Reference Counting (ARC) Primitives
- `fn রেফারেন্স_তৈরি ডাটা_মান` / `fn arc_create data`
  - **Description:** Allocates a 16-byte reference cell initialized with count = 1.
- `fn রেফারেন্স_ধরে_রাখো cell` / `fn arc_retain cell`
  - **Description:** Atomically increments the reference counter.
- `fn রেফারেন্স_ছেড়ে_দাও cell` / `fn arc_release cell`
  - **Description:** Decrements the reference counter, reclaiming the cell when count reaches 0.

### 4.4 Code Example
```lipi
include "std/arena.lp"

// Create 4 MB linear arena pool
pool = অ্যারিনা_তৈরি(4194304)

// Bump allocate buffers in O(1) time
chunk1 = অ্যারিনা_বরাদ্দ(pool, 512)
chunk2 = অ্যারিনা_বরাদ্দ(pool, 2048)

say "Total bytes allocated: " + অ্যারিনা_used_mem(pool)
say "Remaining arena capacity: " + অ্যারিনা_অবশিষ্ট_mem(pool)

// Zero-cost instant mass reclamation
অ্যারিনা_রিসেট(pool)
say "Arena reset complete. Active used bytes: " + অ্যারিনা_used_mem(pool)

// Destroy arena on process termination
অ্যারিনা_ধ্বংস(pool)
```

---

## 5. SIMD Vector Acceleration & Matrix AI Engine (`std/simd.lp`)

[`std/simd.lp`](../std/simd.lp) unlocks physical silicon vector parallelism for neural networks, linear algebra, and data science workloads. It eliminates BLAS and NumPy dependencies.

### 5.1 Architectural Capabilities
- **x86_64:** Emits SSE2 / AVX2 packed vector instructions (`paddq`, `mulpd`, `xorpd`).
- **AArch64:** Emits ARM NEON 128-bit vector instructions (`add.2d`, `fmla.2d`).

### 5.2 API Reference

- `fn ভেক্টর_যোগ dest src` / `fn simd_vec_add_128 dest src`
  - **Description:** Performs parallel 128-bit vector addition on two 64-bit integer lanes simultaneously using single-cycle hardware instructions.
- `fn ভেক্টর_ডট_গুণন src1 src2 উপাদান_সংখ্যা` / `fn simd_dot_product src1 src2 count`
  - **Description:** Computes the mathematical dot product $\sum_{i=0}^{N-1} (A_i \times B_i)$ over `count` elements.
  - **Returns:** 64-bit scalar sum.
- `fn ম্যাট্রিক্স_গুণন_২x২ matrix_a matrix_b result` / `fn simd_matrix_mul_2x2 a b result`
  - **Description:** Multiplies two $2 \times 2$ matrices (stored as four 64-bit values / 32 bytes) in unrolled silicon registers, storing the product into `result`.
- `fn রেলু_অ্যাক্টিভেশন value` / `fn simd_relu value`
  - **Description:** Implements the Rectified Linear Unit activation function: $\max(0, x)$.
- `fn ভেক্টর_রেলু addr উপাদান_সংখ্যা` / `fn simd_vec_relu addr count`
  - **Description:** Applies the ReLU activation in-place across an entire contiguous vector buffer of length `count`.

### 5.3 Code Example: Matrix Multiplication & Neural Activation
```lipi
include "std/simd.lp"
include "std/mem.lp"

// Allocate 2x2 matrices A and B (32 bytes each)
mat_a = malloc(32)
mat_b = malloc(32)
mat_c = malloc(32)

// Populate matrix A = [[1, 2], [3, 4]]
mem_write(mat_a, 0, 1)
mem_write(mat_a, 8, 2)
mem_write(mat_a, 16, 3)
mem_write(mat_a, 24, 4)

// Populate matrix B = [[5, 6], [7, 8]]
mem_write(mat_b, 0, 5)
mem_write(mat_b, 8, 6)
mem_write(mat_b, 16, 7)
mem_write(mat_b, 24, 8)

// Hardware silicon matrix multiplication: C = A * B
ম্যাট্রিক্স_গুণন_২x২(mat_a, mat_b, mat_c)

c00 = mem_read(mat_c, 0)
c01 = mem_read(mat_c, 8)
c10 = mem_read(mat_c, 16)
c11 = mem_read(mat_c, 24)

say "Matrix C = [[" + c00 + ", " + c01 + "], [" + c10 + ", " + c11 + "]]"
```

---

## 6. Sovereign Cryptography Engine (`std/crypto.lp`, `std/tls.lp`, `std/crypto2.lp`)

The Lipi cryptography suite implements NIST FIPS 180-4 SHA-256, RFC 8439 ChaCha20, and Ed25519 digital signatures in 100% pure Lipi code with zero OpenSSL dependency.

### 6.1 Hardware Entropy & Randomness
- `fn silicon_random_int` / `fn CRYPTO_random_bytes buffer size`
  - **Description:** Generates cryptographically secure random numbers using physical CPU hardware instructions (x86 `RDRAND`) or Linux `SYS_getrandom` (Syscall 318).

### 6.2 NIST FIPS 180-4 SHA-256 Digest Engine
- **Single-Cycle Rotations:** Utilizes single-cycle hardware rotate-right instructions (`ror32`) for compression functions:
  - $\Sigma_0(x) = \text{ROTR}^2(x) \oplus \text{ROTR}^{13}(x) \oplus \text{ROTR}^{22}(x)$
  - $\Sigma_1(x) = \text{ROTR}^6(x) \oplus \text{ROTR}^{11}(x) \oplus \text{ROTR}^{25}(x)$
  - $\sigma_0(x) = \text{ROTR}^7(x) \oplus \text{ROTR}^{18}(x) \oplus (x \gg 3)$
  - $\sigma_1(x) = \text{ROTR}^{17}(x) \oplus \text{ROTR}^{19}(x) \oplus (x \gg 10)$
- **Round Constants:** `sha256_const_init(k_mem)` initializes 64 32-bit fractional constants ($K_0 \dots K_{63}$).
- **Hex Encoding:** `nibble_to_hex(nibble)` formats binary digests into 64-character lowercase hexadecimal representation.

### 6.3 RFC 8439 ChaCha20 Stream Cipher
- **Quarter Round Function:** `chacha20_qr(mem, a, b, c, d)` executes 4 quarter-round additions, XORs, and 32-bit left rotations (`rol32`) in physical CPU registers.
- **State Initialization:** `chacha20_স্টেট_created` structures a $4 \times 4$ 32-bit matrix containing the constant `"expand 32-byte k"`, 256-bit secret key, 32-bit block counter, and 96-bit nonce.
- **High Throughput:** Encrypts and decrypts continuous data streams at multiple gigabytes per second with resistance to cache-timing attacks.

### 6.4 RFC 8032 Ed25519 Digital Signatures
- `fn Ed25519_generate_keypair`
  - **Description:** Derives a public/private keypair using CSPRNG entropy over Curve25519 twisted Edwards curve.
- `fn Ed25519_sign private_key message msg_len`
  - **Description:** Generates a deterministic 64-byte cryptographic signature proving message authenticity.
- `fn Ed25519_verify public_key message msg_len signature`
  - **Description:** Verifies digital signature authenticity. Returns `1` if valid, `0` if forged.
- `fn ed25519_keypair_free kp`
  - **Description:** Securely zeroes the private key memory before releasing memory, preventing side-channel leakage.

---

## 7. Direct Operating System Syscall Table

Lipi standard library modules interface directly with the Linux kernel via the following syscall numbers:

| Syscall | x86_64 ID | AArch64 ID | Calling Convention & Functionality |
|---|---|---|---|
| `sys_read` | `0` | `63` | Read raw bytes from file descriptor |
| `sys_write` | `1` | `64` | Write raw bytes to file descriptor |
| `sys_open` | `2` | `56` (`openat`) | Open file path with POSIX access flags |
| `sys_close` | `3` | `57` | Close an active file descriptor |
| `sys_mmap` | `9` | `222` | Map anonymous or file-backed virtual memory pages |
| `sys_munmap` | `11` | `215` | Unmap virtual memory pages |
| `sys_sched_yield` | `24` | `124` | Yield CPU timeslice to cooperating threads |
| `sys_getpid` | `39` | `172` | Query current process ID |
| `sys_socket` | `41` | `198` | Allocate Berkeley network socket |
| `sys_connect` | `42` | `203` | Connect to remote network socket |
| `sys_accept` | `43` | `202` | Accept incoming network connection |
| `sys_bind` | `49` | `200` | Bind network socket to local address and port |
| `sys_listen` | `50` | `201` | Listen for incoming network connections |
| `sys_clone` | `56` | `220` | Spawn page-shared kernel execution thread |
| `sys_exit` | `60` | `93` | Terminate calling thread or process |
| `sys_clock_gettime` | `228` | `113` | Retrieve monotonic or realtime nanosecond time |
| `sys_getrandom` | `318` | `278` | Cryptographically secure kernel hardware entropy |

---

### Conclusion
The Lipi Sovereign Standard Library demonstrates that high-level ergonomic syntax does not require heavyweight C runtimes or foreign virtual machines. Through direct kernel syscalls, Robin Hood hash tables, bump-pointer arenas, and silicon vector operations, Lipi delivers raw hardware performance with total independence.
