# Lipi 2.0 Complete Developer Manual & Architecture Reference
### Version: First 1.0 (Sovereign Edition) — Zero Dependency, Dual-Syntax & Direct Machine Code

---

## Table of Contents
1. [Executive Summary & The Sovereign Vision](#1-executive-summary--the-sovereign-vision)
2. [Toolchain Architecture & Binary Ecosystem](#2-toolchain-architecture--binary-ecosystem)
3. [Language Semantics & Syntax Specification](#3-language-semantics--syntax-specification)
   - [Variables and Dual-Numeral Systems](#variables-and-dual-numeral-systems)
   - [Control Flow & Branching](#control-flow--branching)
   - [Loops & Iteration](#loops--iteration)
   - [First-Class Functions](#first-class-functions)
   - [Structures & Data Modeling](#structures--data-modeling)
4. [Baremetal & Low-Level Systems Programming](#4-baremetal--low-level-systems-programming)
   - [Direct Linux x86_64 Syscalls](#direct-linux-x86_64-syscalls)
   - [Memory Model & Arena Allocation](#memory-model--arena-allocation)
   - [Multiboot 1 Specification & OS Bootstrapping](#multiboot-1-specification--os-bootstrapping)
5. [Pure Lipi Direct ELF Compiler (`elf_emitter.lp`)](#5-pure-lipi-direct-elf-compiler-elf_emitterlp)
6. [Package Ecosystem & Build Lifecycle (`lipipkg`)](#6-package-ecosystem--build-lifecycle-lipipkg)
7. [Editor Tooling: VS Code Extension & LSP Server](#7-editor-tooling-vs-code-extension--lsp-server)
8. [Production Showcase: High-Performance HTTP Engine](#8-production-showcase-high-performance-http-engine)

---

## 1. Executive Summary & The Sovereign Vision
Lipi (লিপি) is an advanced general-purpose, self-hosted, systems programming language engineered for complete software sovereignty. It bridges native silicon efficiency with natural human expression across multiple languages, featuring native bilingual support for Bengali (বাংলা) and English.

Key Architectural Milestones:
- **Zero Runtime Dependencies:** Lipi compiles to self-contained, statically linked Linux ELF64 binaries requiring 0% Python, 0% GCC, and 0% Libc.
- **Direct Silicon Emission:** The compiler encodes x86_64 machine instructions in memory, outputting standard ELF executables directly.
- **Bilingual AST Equivalence:** Identical abstract syntax trees are generated regardless of whether code is written using Bengali keywords (`যদি`, `কাজ`, `গঠন`) or English keywords (`if`, `fn`, `struct`).

---

## 2. Toolchain Architecture & Binary Ecosystem
The Lipi toolchain resides under `bin/`:

```
lipi/
├── bin/
│   ├── lipc             # Universal compiler CLI (C & Direct ELF targets)
│   ├── lipc_bin         # Native self-hosted C-codegen compiler
│   ├── lipc_native_elf  # Native standalone direct-to-ELF machine code compiler
│   ├── lipi             # Native runner & interactive REPL
│   ├── lipipkg          # Sovereign package manager & build tool
│   ├── lipils           # Language Server Protocol (LSP) daemon
│   └── lipidbg          # Interactive bytecode & assembly debugger
```

### Command Reference
- **Run script immediately:**
  ```bash
  ./bin/lipi tests/01_hello.lp
  ```
- **Compile via Native C Codegen:**
  ```bash
  ./bin/lipc tests/01_hello.lp -o my_app
  ./my_app
  ```
- **Compile to Zero-GCC, Zero-Libc Machine Code:**
  ```bash
  ./bin/lipc --direct-elf tests/01_hello.lp -o my_baremetal_app
  ./my_baremetal_app
  ```

---

## 3. Language Semantics & Syntax Specification

### Variables and Dual-Numeral Systems
Lipi seamlessly supports ASCII digits (`0-9`) alongside Bengali Unicode digits (`০-৯`):

```lipi
// English syntax
pi = 3.14159
radius = 10
area = pi * radius * radius

// Bengali syntax
ধরি ব্যাসার্ধ = ১০
ধরি ক্ষেত্রফল = ৩.১৪১৫৯ * ব্যাসার্ধ * ব্যাসার্ধ

say "Calculated area: " + area
বলো "বাংলা ফলাফল: " + ক্ষেত্রফল
```

### Control Flow & Branching
```lipi
if status == 200
    say "Success"
elif status == 404
    say "Resource Missing"
else
    say "Unhandled Error"
```

In Bengali syntax:
```lipi
যদি অবস্থা == ২০০
    বলো "সফল"
নাহলে_যদি অবস্থা == ৪০৪
    বলো "পাওয়া যায়নি"
নাহলে
    বলো "অজানা ত্রুটি"
```

### Loops & Iteration
Lipi provides three idiomatic loop constructs:
1. **Range Loop:** `for i in 1..10` or `প্রতিটি i ভেতরে ১..১০`
2. **While Loop:** `while cond` or `যতক্ষণ শর্ত`
3. **Repeat Count:** `repeat N` or `N বার বলো`

```lipi
// Range loop with step
for i in 1..20 step 2
    say "Odd number: " + i

// Bengali iteration
প্রতিটি ধাপ ভেতরে ১..৫
    বলো "ধাপ নং: " + ধাপ
```

### First-Class Functions
Functions are declared with `fn` (or `কাজ`) using space-delimited parameter signatures:

```lipi
fn compute_hypotenuse a b
    sum_sq = (a * a) + (b * b)
    return sqrt(sum_sq)

h = compute_hypotenuse(3, 4)
say "Hypotenuse: " + h
```

### Structures & Data Modeling
Lipi structures define user types:

```lipi
struct Point3D
    x
    y
    z

p = Point3D()
p.x = 10
p.y = 20
p.z = 30
say "Point at: " + p.x + ", " + p.y + ", " + p.z
```

---

## 4. Baremetal & Low-Level Systems Programming

### Direct Linux x86_64 Syscalls
Lipi provides first-class raw access to the kernel through `syscall`:

```lipi
// sys_write: syscall(1, fd, buf, count)
msg = "Kernel-level write via Lipi\n"
syscall(1, 1, msg, len(msg))

// sys_getpid: syscall(39)
my_pid = syscall(39, 0, 0, 0)
say "PID: " + my_pid
```

### Memory Model & Arena Allocation
The Lipi runtime manages memory through fixed arenas and linear virtual memory mappings via `sys_mmap` (syscall 9). This eliminates external memory allocator dependencies (`malloc`, `free`) and delivers deterministic real-time latency.

### Multiboot 1 Specification & OS Bootstrapping
All direct ELF binaries synthesized by Lipi's `elf_emitter.lp` contain a standard Multiboot 1 header embedded at offset 124:
- **Magic:** `0x1BADB002` (`464367618`)
- **Flags:** `0x00000000` (`0`)
- **Checksum:** `0xE4524FFE` (`3830599678`)

This allows Lipi binaries to be directly booted on QEMU or real x86_64 hardware without an underlying Linux operating system.

---

## 5. Pure Lipi Direct ELF Compiler (`elf_emitter.lp`)
The centerpiece of Lipi's sovereignty is `src/compiler/elf_emitter.lp`. Written in 100% pure Lipi, this component implements:
- Direct bytecode synthesis of x86_64 OP-codes (`push_rbp`, `mov_reg_imm64`, `syscall`, `sub_rsp`, `call`, etc.)
- In-memory ELF64 file header (64 bytes) and Program Header (56 bytes, `PT_LOAD`, `PF_R | PF_W | PF_X`)
- Multiboot 1 header embedding
- Direct binary byte output using `file_write_bytes`

Invoking the pure Lipi compiler:
```bash
./bin/lipi src/compiler/elf_emitter.lp tests/01_hello.lp /tmp/my_sovereign_bin
chmod +x /tmp/my_sovereign_bin
/tmp/my_sovereign_bin
```

---

## 6. Package Ecosystem & Build Lifecycle (`lipipkg`)
`lipipkg` is Lipi's native package manager.

### Manifest (`lipi.toml`)
```toml
[package]
name = "my_app"
version = "1.0.0"
authors = ["Engineer <dev@lipi.sh>"]
entry = "src/main.lp"

[dependencies]
lipi-json = ">=1.0.0"
```

### Commands
```bash
lipipkg init <name>   # Create a new Lipi project skeleton
lipipkg build         # Compile according to lipi.toml
lipipkg test          # Execute all tests under tests/
lipipkg run           # Run the application entry point
```

---

## 7. Editor Tooling: VS Code Extension & LSP Server
The official VS Code extension is packaged in `lipi-vscode/`:
- Comprehensive TextMate syntax grammar (`lipi.tmLanguage.json`)
- Snippet library (`snippets/lipi.json`)
- Bilingual brackets and indentation engine (`language-configuration.json`)
- Language Server Protocol integration via `bin/lipils`

### Installation
```bash
cp -r lipi-vscode ~/.vscode/extensions/oshim.lipi-language-1.0.0
```

---

## 8. Production Showcase: High-Performance HTTP Engine
The `apps/web_server/server.lp` application demonstrates a production-grade HTTP/1.1 web server architecture:
- Non-blocking pipeline
- Middleware chain (Access Logger, Security/Auth Token Guard)
- REST Routing (`/`, `/api/health`, `/api/info`, `/api/echo`, `/admin`)
- Standard HTTP Wire format response generation with CRLF delimiters

Run:
```bash
./bin/lipc apps/web_server/server.lp -o bin/web_server && ./bin/web_server
```

---

## Conclusion
Lipi 2.0 fulfills the vision of a truly autonomous, self-sufficient programming language. With 100% native machine code emission, complete bilingual syntax, kernel syscall integration, and dedicated editor support, Lipi stands ready for global production systems engineering.
