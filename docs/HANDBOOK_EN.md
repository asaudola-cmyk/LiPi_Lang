# 📜 Lipi 2.0 Sovereign Developer Manual & Systems Reference
### Version: First 1.0 (Sovereign Release) — Pure Machine Code & Bilingual Silicon Engine

---

## Table of Contents
1. [Executive Summary & The Sovereign Vision](#1-executive-summary-the-sovereign-vision)
2. [Sovereign Toolchain Architecture & Binary Ecosystem](#2-sovereign-toolchain-architecture-binary-ecosystem)
3. [Modern Lipi 2.0 Syntax & Dual-Numeral System](#3-modern-lipi-20-syntax-dual-numeral-system)
   - [Variables & Dual-Numeral System](#variables-dual-numeral-system)
   - [Control Flow & Branching](#control-flow-branching)
   - [Loops & Iteration](#loops-iteration)
   - [Functions & Signatures](#functions-signatures)
   - [Custom Structures & Data Modeling](#custom-structures-data-modeling)
4. [Object-Oriented Struct Methods & Calling ABI](#4-object-oriented-struct-methods-calling-abi)
5. [Direct Silicon Architecture: x86_64 & ARM64 Emitters](#5-direct-silicon-architecture-x86_64-arm64-emitters)
6. [Native Multithreading, Concurrency & Memory Arenas](#6-native-multithreading-concurrency-memory-arenas)
7. [First-Class Web Engine & HTTP Router (`std/web.lp`)](#7-first-class-web-engine-http-router-stdweblp)
8. [Baremetal Systems Programming & Kernel Syscalls](#8-baremetal-systems-programming-kernel-syscalls)
9. [Autonomous Toolchain Suite (`lipidbg`, `lipirepl`, `lipipkg`)](#9-autonomous-toolchain-suite-lipidbg-lipirepl-lipipkg)
10. [Package Management & Manifest Specification (`lipipkg.toml`)](#10-package-management-manifest-specification-lipipkgtoml)
11. [Visual Studio Code & Language Server Protocol (LSP)](#11-visual-studio-code-language-server-protocol-lsp)

---

## 1. Executive Summary & The Sovereign Vision

**Lipi 2.0** is an autonomous general-purpose, self-hosted systems programming language engineered for uncompromising software sovereignty and maximum hardware efficiency. It seamlessly bridges native silicon execution with natural human expression across Bengali (বাংলা) and English.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      The Lipi Sovereign Triad                               │
│                                                                             │
│   1. ZERO DEPENDENCY       2. DIRECT SILICON       3. BILINGUAL EQUIVALENCE │
│   • 0% C Runtime (libc)    • Standalone ELF64      • Identical AST Nodes    │
│   • 0% Compiler (GCC/LLVM) • x86_64 & ARM64        • Native Bengali Script  │
│   • 0% External Linker     • Baremetal Multiboot 1 • Standard English       │
└─────────────────────────────────────────────────────────────────────────────┘
```

Lipi eliminates the fragility and supply-chain vulnerabilities of foreign toolchains. Programs written in Lipi compile directly to native Linux ELF64 machine code, executing instructions directly on the physical processor without intermediary C code, runtime virtual machines, or external dynamic libraries (`.so`).

---

## 2. Sovereign Toolchain Architecture & Binary Ecosystem

The complete Lipi toolchain is self-contained within the `bin/` directory:

| Binary | Role & Functional Description |
|---|---|
| `bin/lipc` | Universal sovereign compiler CLI (direct ELF64 machine code generator) |
| `bin/lipi` | High-speed script executor and native runner |
| `bin/lipipkg` | Sovereign package and dependency management engine |
| `bin/lipirepl` | Autonomous interactive shell with live CPU register and memory inspection |
| `bin/lipidbg` | Standalone ELF binary structure diagnostic and hardware stack debugger |
| `bin/lipils` | Official Language Server Protocol (LSP) engine for IDE integration |

### Quickstart CLI Workflow
```bash
# 1. Execute a Lipi script immediately
./bin/lipi examples/01_hello_world/main.lp

# 2. Compile directly to standalone ELF64 machine code (Zero GCC, Zero Libc)
./bin/lipc src/compiler/elf_emitter.lp tests/01_hello.lp build/hello_app
chmod +x build/hello_app
./build/hello_app

# 3. Launch the live interactive REPL
./bin/lipirepl

# 4. Diagnose an ELF binary structure
./bin/lipidbg build/hello_app
```

---

## 3. Modern Lipi 2.0 Syntax & Dual-Numeral System

Lipi 2.0 syntax emphasizes clean, expressive, and minimalist readability. It completely discards syntactic clutter:
- **No curly braces** (`{}`)
- **No statement semicolons** (`;`)
- **No mandatory colons** (`:`) after conditions or function headers
- Block structure is cleanly and deterministically governed by **4-space or tab indentation**.

### Variables & Dual-Numeral System
Lipi provides native first-class support for both Roman numerals (`0-9`) and Bengali Unicode numerals (`০-৯`):

```lipi
// English syntax
language = "Lipi 2.0"
version = 2
pi = 3.14159
is_active = true

// Bengali syntax
ধরি ভাষা = "লিপি ২.০"
ধরি সংস্করণ = ২
ধরি সক্রিয় = সত্য

say "Welcome to " + language
বলো "সংস্করণ: " + সংস্করণ
```

### Control Flow & Branching
Branching requires no parentheses around predicates and no trailing colons:

```lipi
// English syntax
if status == 200
    say "HTTP 200 OK: Request succeeded"
elif status == 404
    say "HTTP 404: Resource not found"
else
    say "Unhandled HTTP status: " + status

// Bengali syntax
যদি বয়স >= ১৮
    বলো "প্রাপ্তবয়স্ক নাগরিক"
নাহলে_যদি বয়স >= ১৩
    বলো "কিশোর"
নাহলে
    বলো "শিশু"
```

### Loops & Iteration
Lipi provides three clear, high-performance looping constructs:
1. `while cond` / `যতক্ষণ শর্ত` (conditional while loop)
2. `for i in start..end` / `প্রতিটি i ভেতরে শুরু..শেষ` (range iteration)
3. `repeat N` / `N বার বলো` (fixed count iteration)

```lipi
// 1. Range loop
for i in 1..5
    say "Loop iteration: " + i

প্রতিটি ধাপ ভেতরে ১..৫
    বলো "বাংলা কাউন্টার: " + ধাপ

// 2. Fixed repetition
repeat 3
    say "Executing task at silicon speed"

৩ বার বলো "জয় লিপি!"

// 3. While loop
n = 5
while n > 0
    say "Countdown: " + n
    n = n - 1
```

### Functions & Signatures
Functions are declared with `fn` (or `কাজ`) using space-separated argument identifiers:

```lipi
// English minimal function syntax
fn multiply a b
    return a * b

// Bengali function syntax
কাজ যোগফল(ক, খ)
    ধরি ফলাফল = ক + খ
    ফেরত ফলাফল

say "Multiplication result: " + multiply(6, 7)
বলো "যোগের ফলাফল: " + যোগফল(১০, ২০)
```

### Custom Structures & Data Modeling
Composite data records are defined via `struct` (or `গঠন`):

```lipi
struct Student
    name
    roll
    department

// Instantiation & field assignment
s = Student()
s.name = "Shakil Ahmed"
s.roll = 101
s.department = "Computer Science & Engineering"

say s.name + " | Roll: " + s.roll + " | Dept: " + s.department
```

---

## 4. Object-Oriented Struct Methods & Calling ABI

Lipi 2.0 supports first-class **Object-Oriented Struct Methods** via `fn Struct.method self arg1 arg2`. This equips developers with modern encapsulation while retaining the baremetal speed of zero-cost static dispatch.

### 4.1 Method Definition & Encapsulation
Methods are declared with explicit type association:

```lipi
struct Point
    x
    y

// Modern Lipi 2.0 Struct Method
fn Point.set_xy self new_x new_y
    self.x = new_x
    self.y = new_y
    return self

fn Point.distance_squared self other
    dx = self.x - other.x
    dy = self.y - other.y
    return (dx * dx) + (dy * dy)

// Method invocation using dot notation
p1 = Point()
p1.set_xy(10, 20)

p2 = Point()
p2.set_xy(14, 23)

dist = p1.distance_squared(p2)
say "Distance squared between points: " + dist
```

In Bengali syntax:
```lipi
গঠন আয়তক্ষেত্র
    দৈর্ঘ্য
    প্রস্থ

কাজ আয়তক্ষেত্র.সেট self l w
    self.দৈর্ঘ্য = l
    self.প্রস্থ = w
    ফেরত self

কাজ আয়তক্ষেত্র.ক্ষেত্রফল self
    ফেরত self.দৈর্ঘ্য * self.প্রস্থ

জমি = আয়তক্ষেত্র()
জমি.সেট(২০, ১০)
বলো "আয়তক্ষেত্রের মোট ক্ষেত্রফল: " + জমি.ক্ষেত্রফল()
```

### 4.2 Compiler Resolution & Register Passing Calling Convention
When compiling an OOP call `p1.set_xy(10, 20)`:
1. **Symbol Mangling:** The compiler resolves the struct type of `p1` and targets the internal symbol `lipi_fn_Point_set_xy`.
2. **AMD64 (x86_64) Hardware ABI:**
   - The `self` pointer is moved into `%rdi` (Argument 1).
   - `new_x` is moved into `%rsi` (Argument 2).
   - `new_y` is moved into `%rdx` (Argument 3).
   - Subsequent arguments map to `%rcx`, `%r8`, `%r9`, and stack frames.
   - Return value is delivered via `%rax`.
3. **AArch64 (ARM64) Hardware ABI:**
   - The `self` pointer is moved into register `X0` (Argument 1).
   - `new_x` is moved into register `X1` (Argument 2).
   - `new_y` is moved into register `X2` (Argument 3).
   - Subsequent arguments map to `X3` through `X7`.
   - Return value is delivered via `X0`.
4. **Zero Overhead:** No virtual function table (vtable) pointer is stored in the object layout, eliminating memory bloat and pipeline cache misses.

---

## 5. Direct Silicon Architecture: x86_64, ARM64 & WebAssembly Emitters

Lipi implements first-class native machine code and bytecode generators written entirely in pure Lipi:
- **x86_64 ELF64 Emitter:** [`src/compiler/elf_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/elf_emitter.lp)
- **ARM64 (AArch64) ELF64 Emitter:** [`src/compiler/arm64_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/arm64_emitter.lp)
- **WebAssembly (WASM) Binary Emitter:** [`src/compiler/wasm_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/wasm_emitter.lp)

```
                       ┌────────────────────────┐
                       │    Lipi Source (.lp)   │
                       └───────────┬────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
       ┌─────────────────────────┐   ┌─────────────────────────┐
       │   x86_64 ELF64 Emitter  │   │   ARM64 ELF64 Emitter   │
       ├─────────────────────────┤   ├─────────────────────────┤
       │ • 64-byte Elf64_Ehdr    │   │ • 64-byte Elf64_Ehdr    │
       │ • 4KB Page Alignment    │   │ • 64KB Page Alignment   │
       │ • Multiboot 1 Embedded  │   │ • Fixed 32-bit Opcodes  │
       │ • 2-byte xor Peephole   │   │ • X8 Syscall Convention │
       └────────────┬────────────┘   └────────────┬────────────┘
                    ▼                             ▼
       ┌─────────────────────────┐   ┌─────────────────────────┐
       │ Standalone Linux Binary │   │ Standalone Linux Binary │
       │   (0% C / 0% Libc)      │   │   (0% C / 0% Libc)      │
       └─────────────────────────┘   └─────────────────────────┘
```

### 5.1 Embedded Multiboot 1 Specification
All x86_64 ELF binaries generated by Lipi include a Multiboot 1 header embedded at offset 124:
- **Magic:** `0x1BADB002` (464367618)
- **Flags:** `0x00000000` (0)
- **Checksum:** `0xE4524FFE` (3830599678)

This enables Lipi executables to boot directly on baremetal PC hardware or inside virtual machines (QEMU, KVM, VirtualBox) without an existing host operating system:
```bash
qemu-system-x86_64 -kernel build/hello_app
```

### 5.2 Peephole Machine Code Optimization (`xor reg32, reg32`)
When assigning zero to any register or initializing variables, the Lipi emitter avoids the 10-byte instruction `movabsq $0, %rax` (`48 B8 00 00 00 00 00 00 00 00`). Instead, it synthesizes the 2-byte instruction:
```asm
31 C0        ; xor %eax, %eax
```
- **80% Code Size Reduction:** 2 bytes versus 10 bytes.
- **Architectural Zero-Extension:** Under AMD64 rules, writing to a 32-bit register automatically clears the upper 32 bits of the full 64-bit register.
- **Zero-Cycle Silicon Execution:** Hardware Register Alias Tables (RAT) recognize self-XOR as a dependency-breaking idiom, clearing registers in 0 clock cycles without consuming execution ALUs.

---

## 6. Native Multithreading, Concurrency & Memory Arenas

Lipi delivers true hardware multicore concurrency through direct Linux kernel syscalls without `pthreads` or external runtime schedulers.

### 6.1 Kernel Thread Creation via `SYS_clone`
[`std/thread.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/thread.lp) invokes `SYS_clone` (syscall 56 on x86_64, syscall 220 on AArch64) with flags `CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD` (`69376` / `0x10F00`):

```lipi
include "std/thread.lp"
include "std/mem.lp"

// Allocate thread stack memory (64 KB) via SYS_mmap
stack_size = 65536
stack_base = syscall(9, 0, stack_size, 3, 34, -1, 0)
stack_top = stack_base + stack_size - 16

// Spawn true kernel thread
tid = থ্রেড_তৈরি(stack_top)

if tid == 0
    // Child thread context executing on a dedicated CPU core
    say "Child thread running concurrently in background..."
    থ্রেড_প্রস্থান(0)
else
    // Parent process context
    say "Parent process spawned child TID: " + tid
```

### 6.2 Atomic Spinlocks & Cooperative Yielding
Synchronization across threads is achieved with memory word locks:
```lipi
lock_addr = malloc(8)
mem_write(lock_addr, 0, 0) // Initialize to unlocked state

// Acquire spinlock (automatically yields CPU timeslice if contended)
স্পিনলক_আটক(lock_addr)

// Critical section: update shared state
shared_counter = shared_counter + 1

// Release spinlock
স্পিনলক_মুক্ত(lock_addr)
```
During lock contention, the waiting thread issues `SYS_sched_yield` (syscall 24), preventing CPU thermal throttling and power waste.

### 6.3 Bump-Pointer Arena Memory Allocator (`std/arena.lp`)
High-performance workloads utilize [`std/arena.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/arena.lp) for O(1) allocation and instant mass reclamation:
```lipi
include "std/arena.lp"

// Create a 2 MB memory arena pool directly from kernel pages
pool = অ্যারিনা_তৈরি(2097152)

// O(1) bump allocations aligned to 8-byte boundaries
buf1 = অ্যারিনা_বরাদ্দ(pool, 256)
buf2 = অ্যারিনা_বরাদ্দ(pool, 4096)

// Instant mass reclamation in 0 cycles
অ্যারিনা_রিসেট(pool)

// Release backing memory pool back to the Linux kernel
অ্যারিনা_ধ্বংস(pool)
```

---

## 7. First-Class Web Engine & HTTP Router (`std/web.lp`)

Lipi 2.0 provides an enterprise-grade standard web engine in [`std/web.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/web.lp), eliminating foreign web frameworks like Express, Flask, or Axum.

### 7.1 Core Components
- `WebRoute`: Record binding HTTP methods, path strings, and integer handler IDs.
- `WebRequest`: Structured context containing method, path, query parameters, and raw body.
- `WebResponse`: Structured envelope holding HTTP status codes, headers, and payload.

### 7.2 Production REST Microservice Example
```lipi
include "std/web.lp"

// 1. Initialize router and register route handlers
router = web_router_new()

web_get(router, "/", 1)
web_get(router, "/api/health", 2)
web_get(router, "/api/user", 3)
web_post(router, "/api/echo", 4)

// 2. Request dispatcher
fn handle_http_request raw_req
    method = web_parse_method(raw_req)
    path = web_parse_path(raw_req)
    handler_id = web_dispatch(router, method, path)

    if handler_id == 1
        return web_response_html("<h1>Lipi 2.0 Sovereign Web Server</h1>")

    if handler_id == 2
        return web_response_json("{\"status\":\"healthy\",\"compiler\":\"ELF64\"}")

    if handler_id == 3
        name = web_parse_param_str(raw_req, "name=")
        if len(name) == 0
            name = "Guest"
        return web_response_json("{\"user\":\"" + name + "\",\"tier\":\"sovereign\"}")

    if handler_id == 4
        return web_response_json("{\"message\":\"Payload accepted\"}")

    return web_response_not_found()

// 3. Serialize response to standard HTTP/1.1 wire protocol
res = handle_http_request("GET /api/health HTTP/1.1\r\n\r\n")
wire_bytes = web_serialize_response(res)
say wire_bytes
```

---

## 8. Baremetal Systems Programming & Kernel Syscalls

Lipi grants direct access to the underlying OS kernel through `syscall`:

```lipi
// Direct sys_write: syscall(1, fd, buf, count)
msg = "Kernel-level write direct to stdout\n"
syscall(1, 1, msg, len(msg))

// sys_getpid: syscall(39)
my_pid = syscall(39, 0, 0, 0)
say "Current Process ID: " + my_pid

// High-resolution clock: sys_clock_gettime (228)
// CLOCK_MONOTONIC = 1
ts = malloc(16)
syscall(228, 1, ts, 0, 0, 0)
seconds = mem_word_read(ts, 0)
nanos = mem_word_read(ts, 8)
say "Monotonic timestamp: " + seconds + "s " + nanos + "ns"
free(ts, 16)
```

---

## 9. Autonomous Toolchain Suite (`lipidbg`, `lipirepl`, `lipipkg`)

Lipi provides a comprehensive suite of developer tools written in pure Lipi.

### 9.1 `lipidbg` — Sovereign System Debugger
Located at [`src/tools/lipidbg.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipidbg.lp), `lipidbg` inspects compiled ELF binaries and runtime environments without GDB:
- Validates ELF magic bytes (`0x7F 'E' 'L' 'F'`).
- Verifies 64-bit architecture classification (`ELFCLASS64`).
- Assesses entry point virtual memory offsets and segment alignment.
- Inspects physical CPU stack pointers and live hardware registers.

```bash
./bin/lipidbg build/hello_app
```

### 9.2 `lipirepl` — Interactive Evaluation Shell
Located at [`src/tools/lipirepl.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipirepl.lp), `lipirepl` offers immediate feedback and low-level introspection:
- `:eval <expr>`: Evaluates arithmetic and logic expressions immediately.
- `:reg` / `:রেজিস্টার`: Dumps physical `%rsp` stack pointer and CPU clock (RDTSC).
- `:mem <addr> <len>`: Hex dump of raw virtual memory addresses.
- `:exit` / `:বিদায়`: Exits the interactive shell.

```bash
./bin/lipirepl
```

### 9.3 `lipipkg` — Sovereign Package Manager
Located at [`src/tools/lipipkg.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/tools/lipipkg.lp), `lipipkg` orchestrates the complete software lifecycle:
- `lipipkg init <name>`: Initializes a standard project structure.
- `lipipkg build`: Compiles `src/main.lp` into a standalone ELF binary.
- `lipipkg run`: Builds and runs the executable in a single pass.
- `lipipkg test`: Executes all automated test suites under `tests/`.
- `lipipkg clean`: Purges build artifacts and temporaries.

```bash
./bin/lipipkg init my_microservice
cd my_microservice
../bin/lipipkg build
../bin/lipipkg test
```

---

## 10. Package Management & Manifest Specification (`lipipkg.toml`)

Projects are configured using the standard [`lipipkg.toml`](file:///home/shafiullah/Documents/file/work/lipi/docs/LIPIPKG_TOML_SPEC.md) manifest:

```toml
[package]
name = "sovereign_service"
version = "1.0.0"
authors = ["Sovereign Team <dev@lipi.dev>"]
entry = "src/main.lp"

[dependencies]
std-web = ">=2.0.0"
std-crypto = ">=1.0.0"
```

---

## 11. Visual Studio Code & Language Server Protocol (LSP)

The official VS Code extension is packaged under `editors/vscode/`:
- Comprehensive bilingual TextMate syntax grammar (`lipi.tmLanguage.json`).
- Smart indentation and bracket matching (`language-configuration.json`).
- Code snippets (`snippets/lipi.json`).
- First-class Language Server Protocol daemon (`bin/lipils`).

### Installation
```bash
mkdir -p ~/.vscode/extensions/lipi-lang-2.0.0
cp -r editors/vscode/* ~/.vscode/extensions/lipi-lang-2.0.0/
```
Restart Visual Studio Code to enable syntax highlighting and editing support for all `.lp` and `.lipi` files.

---

## Conclusion
Lipi 2.0 represents a modern triumph in autonomous systems engineering: uniting bilingual syntax ergonomics with baremetal execution speed, direct silicon ELF generation, native multithreading, and zero third-party dependencies.
