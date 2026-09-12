# 🏛️ Lipi 2.0 Sovereign Architecture Specification

## Abstract
The **Lipi Sovereign Programming Language** is an autonomous, bilingual systems programming language and toolchain engineered for absolute software independence. Lipi compiles high-level, human-readable source code directly into native 64-bit Linux Executable and Linkable Format (ELF64) binaries.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Lipi Sovereign Toolchain Flow                         │
│                                                                             │
│   [Bengali Source (.lp)] ──┐                                                │
│                            ├─► [Bilingual Lexer] ──► [Recursive AST Parser] │
│   [English Source (.lp)] ──┘                                      │         │
│                                                                   ▼         │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │                         SSA IR & Optimization                         │ │
│   │   • Constant Folding          • Granlund-Montgomery Strength Reduction│ │
│   │   • Dead Code Elimination     • 2-Byte Peephole Zero-Init Optimization│ │
│   └───────────────────────────────────┬───────────────────────────────────┘ │
│                                       │                                     │
│                     ┌─────────────────┴─────────────────┐                   │
│                     ▼                                   ▼                   │
│      [AMD64 ELF64 Silicon Emitter]        [AArch64 ELF64 Silicon Emitter]   │
│      • RegAlloc: %r12-%r15, %rdi-%r9      • RegAlloc: X0-X7, X19-X28        │
│      • Direct Syscall ABI (sys_*)         • Linux AArch64 Syscall ABI (X8)  │
│      • Multiboot 1 Embedded Kernel        • 64KB Page Alignment             │
│                     │                                   │                   │
│                     ▼                                   ▼                   │
│           [Standalone ELF64]                  [Standalone ELF64]            │
│         (0% C / 0% GCC / 0% Libc)           (0% C / 0% GCC / 0% Libc)       │
└─────────────────────────────────────────────────────────────────────────────┘
```

The Lipi toolchain operates with **Zero Foreign Dependencies**:
- **0% C Runtime (`libc`):** Does not link against `glibc`, `musl`, or any external C standard library.
- **0% Compiler Infrastructure (`gcc`, `clang`, `llvm`):** Machine instructions are synthesized byte-by-byte in memory.
- **0% External Assembler or Linker (`as`, `ld`, `lld`):** ELF64 file headers, program headers, and relocation tables are written directly to disk.
- **0% Virtual Machine or Interpreter Overhead:** Produces native silicon machine code executed directly by the CPU.

---

## 1. Direct Silicon Architecture & Multi-Platform Emitters

Lipi features twin first-class silicon emitters written in 100% pure Lipi code:
1. **x86_64 (AMD64) ELF64 Emitter:** [`src/compiler/elf_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/elf_emitter.lp)
2. **ARM64 (AArch64) ELF64 Emitter:** [`src/compiler/arm64_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/arm64_emitter.lp)

### 1.1 x86_64 Direct Machine Code Generation
The x86_64 emitter translates Lipi AST constructs into raw x86_64 machine instructions:

- **ELF64 Layout:**
  - `Elf64_Ehdr` (64 bytes): ELF Magic (`0x7F 'E' 'L' 'F'`), Class 2 (64-bit), Data 1 (Little-Endian), OS/ABI 0 (System V), Machine 62 (`EM_X86_64`), Entry Virtual Address `0x401000`.
  - `Elf64_Phdr` (56 bytes): Type 1 (`PT_LOAD`), Flags 7 (`PF_R | PF_W | PF_X`), Virtual Address `0x400000`, File Size = Memory Size.
  - Page Alignment Padding: 3,976 zero-bytes to align code execution cleanly at page boundary `0x1000` (file offset 4,096).
  - `.text` Segment: Emits variable-length x86_64 instructions starting at virtual address `0x401000`.
  - `.rodata` Segment: Embedded static string literals and lookup tables positioned immediately after executable code.
- **Baremetal Multiboot 1 Specification:**
  - Embedded at byte offset 124 within the binary header.
  - Header Magic: `0x1BADB002` (464367618).
  - Flags: `0x00000000` (0).
  - Checksum: `0xE4524FFE` (3830599678), satisfying `-(magic + flags)`.
  - This enables any Lipi executable to boot directly on physical x86_64 silicon or hypervisors (QEMU, KVM, VirtualBox) without an underlying operating system.
- **Direct Kernel Syscall Mechanism:**
  - Invocations of `syscall(num, arg1, arg2, arg3, arg4, arg5, arg6)` load the syscall number into `%rax` and pass arguments through registers `%rdi`, `%rsi`, `%rdx`, `%r10`, `%r8`, `%r9` before issuing the 2-byte opcode `0x0F 0x05` (`syscall`).

### 1.2 ARM64 (AArch64) Direct Machine Code Generation
The ARM64 emitter delivers native execution on 64-bit ARM platforms (Apple Silicon via Linux VMs, Raspberry Pi 4/5, AWS Graviton, and Ampere servers):

- **AArch64 ELF64 Layout:**
  - `Elf64_Ehdr` (64 bytes): Machine Architecture 183 (`EM_AARCH64` / `0x00B7`).
  - Base Virtual Address: `0x400000` (`ARM64_ELF_BASE_VADDR`).
  - Kernel Page Alignment: 64 KB (`0x10000`) for modern Linux AArch64 enterprise kernels.
  - Total Header Overhead: 120 bytes (`ARM64_TOTAL_HDR_SIZE` = 64-byte file header + 56-byte program header).
  - Entry Point: `0x400078` (`0x400000 + 120`), executing immediately following the ELF headers without bloat.
- **AArch64 32-Bit Instruction Synthesis:**
  - Emits fixed-width 32-bit (4-byte) little-endian opcodes.
  - Data Processing: `ADD`, `SUB`, `MUL`, `SDIV`, `AND`, `ORR`, `EOR`, `MOVZ`, `MOVK`.
  - Memory Access: Immediate and register-offset `LDR` (load 64-bit register) and `STR` (store 64-bit register).
  - Control Flow: `B` (unconditional branch, 26-bit PC-relative), `B.cond` (conditional branch, 19-bit PC-relative), `BL` (branch with link to LR / X30), `RET` (return to address in X30).
- **Linux AArch64 Syscall ABI:**
  - Linux AArch64 adheres to the `asm-generic` unistd table:
    - Syscall number placed in register `X8` (e.g., `sys_write` = 64, `sys_read` = 63, `sys_exit` = 93, `sys_mmap` = 222).
    - Arguments passed across registers `X0`, `X1`, `X2`, `X3`, `X4`, `X5`.
    - Executed via `SVC #0` (`0xD4000001`). Return values delivered in register `X0`.

### 1.3 WebAssembly (WASM) Direct Binary Synthesis
The WebAssembly emitter ([`src/compiler/wasm_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/wasm_emitter.lp)) translates Lipi procedures directly into W3C WebAssembly 1.0 binary modules (`.wasm`) for execution in browsers, edge workers, and sandboxed runtimes (0% C, 0% LLVM, 0% Emscripten):

- **WASM Binary Layout:**
  - Magic Header: 4 bytes `0x00, 0x61, 0x73, 0x6D` (`\0asm`).
  - Version: 4 bytes little-endian `0x01, 0x00, 0x00, 0x00` (Version 1).
  - Canonical Sections:
    - Type Section (id 1): Vector of function type descriptors (`0x60`, parameter types vector, result types vector).
    - Function Section (id 3): Vector of type indices mapping module functions to type signatures.
    - Memory Section (id 5): Optional linear memory descriptors (page allocations).
    - Export Section (id 7): Export vector exposing public functions (`main`, `add`, `sub`, `mul`, `div_s`, `fib`) and memory.
    - Code Section (id 10): Function bodies containing compressed local variable declarations and stack bytecode instructions terminated by `0x0B` (`end`).
- **Mathematical LEB128 Integer Encoders:**
  - Unsigned LEB128 (`u32`): Encodes section sizes, vector element counts, and function/type indices.
  - Signed LEB128 (`s32`): Encodes positive and negative two's complement integer literals for `i32.const` immediates without host bitwise dependencies.
- **Core Virtual Stack Machine Instructions:**
  - Constant loading: `0x41` (`i32.const`).
  - Arithmetic: `0x6A` (`i32.add`), `0x6B` (`i32.sub`), `0x6C` (`i32.mul`), `0x6D` (`i32.div_s`), `0x6E` (`i32.div_u`).
  - Control Flow: `0x10` (`call`), `0x0F` (`return`), `0x04` (`if`), `0x05` (`else`), `0x0B` (`end`), `0x0C` (`br`), `0x0D` (`br_if`).
  - Variables: `0x20` (`local.get`), `0x21` (`local.set`), `0x22` (`local.tee`).
  - Comparisons: `0x45` (`i32.eqz`), `0x46` (`i32.eq`), `0x47` (`i32.ne`), `0x48` (`i32.lt_s`), `0x4C` (`i32.le_s`), etc.
- **Direct Memory Staging & Filesystem Commit:**
  - Binary bytes are assembled into memory buffers allocated via Linux `SYS_mmap`, validated byte-by-byte via `mem_byte_read`, and committed to disk via `file_write`.

---

## 2. Object-Oriented Struct Methods & ABI

Lipi 2.0 introduces first-class **Object-Oriented Struct Methods** that combine high-level object ergonomics with zero-cost low-level static dispatch.

### 2.1 Method Definition Syntax
Methods are declared with struct-type qualification:
```lipi
struct Point
    x
    y

// Modern Lipi 2.0 Method Definition
fn Point.set_xy self x y
    self.x = x
    self.y = y
    return self

fn Point.distance_squared self other
    dx = self.x - other.x
    dy = self.y - other.y
    return (dx * dx) + (dy * dy)
```

In Bengali syntax:
```lipi
গঠন বিন্দু
    x
    y

কাজ বিন্দু.নির্ধারণ self x y
    self.x = x
    self.y = y
    ফেরত self
```

### 2.2 Compiler Symbol Resolution & Name Mangling
When the compiler encounters `fn StructName.methodName self ...`:
1. It prefixes the symbol with the struct namespace: `lipi_fn_<StructName>_<methodName>`.
2. The initial parameter `self` is bound to the instance reference.
3. In-memory struct field access `self.field` compiles to fixed base-pointer displacement offsets `[reg + (field_index * 8)]`.

### 2.3 Register Passing Calling Convention
Method invocations `instance.method(arg1, arg2)` follow native hardware calling conventions with zero indirection:

#### AMD64 (System V x86_64) ABI
- `self` pointer is loaded into register `%rdi` (Argument 1).
- `arg1` is loaded into register `%rsi` (Argument 2).
- `arg2` is loaded into register `%rdx` (Argument 3).
- Subsequent arguments populate `%rcx`, `%r8`, `%r9`, and the stack.
- Return values are delivered in `%rax`.

#### AArch64 (ARM64) ABI
- `self` pointer is passed in register `X0` (Argument 1).
- `arg1` is passed in register `X1` (Argument 2).
- `arg2` is passed in register `X2` (Argument 3).
- Subsequent arguments populate registers `X3` through `X7`.
- Return values are delivered in `X0`.

Because methods are resolved at compile-time, there is **no virtual method table (vtable) indirection, no dynamic dispatch penalty, and no memory pointer chasing**.

---

## 3. Peephole Machine Code Optimization

The Lipi code generation pipeline includes targeted peephole optimizations designed for maximum code density and execution speed on modern superscalar processors.

### 3.1 Two-Byte Zero-Initialization Optimization (`xor reg32, reg32`)
In systems code, initializing variables, counters, accumulators, and return values to zero is the most frequent register operation.

#### The Problem with Naive Instruction Selection
A naive 64-bit immediate move:
```asm
movabsq $0, %rax       ; 0x48 0xB8 00 00 00 00 00 00 00 00 (10 bytes!)
```
This consumes 10 bytes of instruction cache and requires 8 bytes of immediate operand decoding.

#### The Lipi Peephole Solution
In [`src/compiler/elf_emitter.lp`](file:///home/shafiullah/Documents/file/work/lipi/src/compiler/elf_emitter.lp#L326-L338):
```lipi
fn x86_mov_reg_imm64 ctx reg val
    if val == 0
        // WHY: Peephole optimization: xor reg32, reg32 is only 2-3 bytes vs 10 bytes for mov reg64, 0
        // In AMD64, writing to a 32-bit register automatically zero-extends to the full 64-bit register
        rex = 0
        if reg >= 8
            rex = 69 // 0x45 (REX.RB)
        modrm = 192 + ((reg % 8) * 8) + (reg % 8)
        if rex > 0
            bb_put8(ctx, rex)
        bb_put8(ctx, 49) // 0x31 (xor r/m32, r32)
        bb_put8(ctx, modrm)
        return 0
```

#### Silicon Hardware Advantages:
1. **Architectural Zero-Extension:** Under AMD64 specifications, any write to a 32-bit register (such as `%eax`, `%edi`, `%r8d`) automatically and atomically zero-extends into the upper 32 bits of the full 64-bit register (`%rax`, `%rdi`, `%r8`).
2. **Byte Density:** Emitting `31 C0` (`xor %eax, %eax`) takes only **2 bytes**—an **80% reduction in code size** compared to 10-byte moves. Extended registers (`%r8`..`%r15`) require a 1-byte REX prefix (`45 31 C0`), taking only 3 bytes.
3. **Register Renaming & Dependency Breaking:** Modern x86 hardware execution engines recognize `xor reg, reg` as a dependency-breaking idiom. It executes in 0 cycles at the register alias table (RAT) stage without allocating an execution pipeline ALU unit.

---

## 4. First-Class Web Standard Library (`std/web.lp`)

Lipi 2.0 eliminates all legacy external web frameworks and C wrappers in favor of a sovereign, high-throughput standard web engine: [`std/web.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/web.lp).

### 4.1 Architectural Foundations
- **Direct Linux Socket Calls:** Binds directly to the operating system network stack via `SYS_socket` (syscall 41), `SYS_bind` (syscall 49), `SYS_listen` (syscall 50), and `SYS_accept` (syscall 43).
- **Sub-Microsecond Dispatch:** Routes are held in contiguous memory arrays and matched via linear byte scanning without recursive regex engine overhead.
- **Zero-Copy Parsing:** Extracts HTTP verbs (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`, `HEAD`), request paths, URL query strings, and headers without dynamic heap reallocation.
- **Wire-Format Response Serialization:** Constructs standards-compliant HTTP/1.1 response envelopes with explicit `Content-Length`, `Content-Type`, CORS headers, and CRLF (`\r\n`) delimiters.

```lipi
include "std/web.lp"

router = web_router_new()
web_get(router, "/", 1)
web_get(router, "/api/status", 2)
web_post(router, "/api/data", 3)

fn handle_request req
    route_id = web_dispatch(router, req.method, req.path)
    if route_id == 1
        return web_response_html("<h1>Lipi 2.0 Sovereign Web Server</h1>")
    if route_id == 2
        return web_response_json("{\"status\":\"healthy\",\"engine\":\"Lipi 2.0\"}")
    return web_response_not_found()
```

---

## 5. Native Multithreading & Memory Architecture

Lipi implements high-concurrency systems programming directly against the Linux kernel without `pthreads` or external threading libraries.

### 5.1 Kernel Thread Creation via `SYS_clone`
[`std/thread.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/thread.lp) invokes the Linux `SYS_clone` syscall (56 on x86_64, 220 on AArch64):
- **Clone Flags:**
  - `CLONE_VM` (`0x00000100` = 256): Shares virtual memory space with the parent process.
  - `CLONE_FS` (`0x00000200` = 512): Shares filesystem information.
  - `CLONE_FILES` (`0x00000400` = 1024): Shares open file descriptors.
  - `CLONE_SIGHAND` (`0x00000800` = 2048): Shares signal handlers.
  - `CLONE_THREAD` (`0x00010000` = 65536): Places child in the same thread group.
  - Combined Mask: `69376` (`0x10F00`).
- **Stack Allocation:** Thread stacks are allocated in memory via `SYS_mmap` (Syscall 9 on x86_64, Syscall 222 on AArch64) with `PROT_READ | PROT_WRITE` permissions. The stack pointer is aligned to a 16-byte boundary and passed to `SYS_clone`.

### 5.2 Atomic Spinlocks & Cooperative Yielding
Concurrency synchronization is managed through memory word locks:
- **Acquire (`স্পিনলক_আটক` / `spinlock_lock`):** Polls the atomic memory address. When contended, calls `SYS_sched_yield` (Syscall 24) to forfeit the current CPU timeslice, preventing CPU starvation and busy-wait thermal throttling.
- **Release (`স্পিনলক_মুক্ত` / `spinlock_unlock`):** Writes `0` to the lock memory address, enabling waiting worker threads to claim the critical section.

### 5.3 O(1) Bump-Pointer Arena Memory Allocator
[`std/arena.lp`](file:///home/shafiullah/Documents/file/work/lipi/std/arena.lp) implements linear bump allocation for high-throughput pipelines:
- Allocates contiguous blocks of physical memory directly from the kernel via `SYS_mmap`.
- Dispenses memory sequentially via an internal offset pointer aligned to 8-byte QWORD boundaries.
- **Instant Mass Reclamation:** Resetting the arena (`used = 0`) reclaims all allocations in **0 cycles** with zero memory fragmentation and zero pointer chasing.

---

## 6. The 5-Stage Nano-Compiler Engine Pipeline

```
[Lipi Source (.lp)]
       │
       ▼
[Stage 1: Lexical Analysis (টোকেনাইজার)]
       │ UTF-8 bilingual lexer, number scanner (ASCII 0-9 & Bengali ০-৯)
       ▼
[Stage 2: AST Parser (এএসটি_তৈরি)]
       │ Recursive-descent grammar, struct field layout, method bindings
       ▼
[Stage 3: SSA IR Optimizer (এসএসএ_আইআর)]
       │ Constant folding, strength reduction, algebraic simplification
       ▼
[Stage 4: Linear Scan RegAlloc (রেজিস্টার_বরাদ্দকরণ)]
       │ Live-range analysis, physical register binding (%r12-%r15 / X19-X28)
       ▼
[Stage 5: Silicon Machine Code Emitter (সিলিকন_ইমিটার)]
       │ x86_64 ELF64 / ARM64 ELF64 byte synthesis, Multiboot 1 embedding
       ▼
[Native Executable Binary (0% C, 0% GCC, 0% Libc, 0% LLVM)]
```

1. **Stage 1: Lexical Analysis:** Scans UTF-8 byte streams directly from memory or disk. Supports Bengali keywords (`যদি`, `কাজ`, `গঠন`, `ফেরত`) and English keywords (`if`, `fn`, `struct`, `return`) interchangeably, generating identical token streams.
2. **Stage 2: Abstract Syntax Tree Parsing:** Recursive-descent parser producing hierarchical syntax trees. Tracks indentation depth without curly braces or semicolons. Resolves struct fields and struct method declarations.
3. **Stage 3: SSA IR & Algebraic Optimization:** Converts expressions into Static Single Assignment form. Performs compile-time constant folding and converts expensive division operations into reciprocal multiplications via Granlund-Montgomery algorithms.
4. **Stage 4: Linear Scan Register Allocation:** Computes live ranges for inner-loop induction variables and accumulators. Maps hot variables directly to callee-saved registers (`%r12`–`%r15` on AMD64, `X19`–`X28` on AArch64), avoiding round-trips to the stack frame.
5. **Stage 5: Silicon Machine Code Synthesis:** Encodes raw opcodes, resolves jump labels via relocation backpatching, constructs standard ELF64 headers, embeds the Multiboot 1 specification header, and commits the binary to disk with `0755` executable permissions.
