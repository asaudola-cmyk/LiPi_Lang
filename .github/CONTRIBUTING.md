# 👑 Contributing to LiPi (লিপি) Sovereign Language

> *"লিপি কারো নিয়ম মানে না, নিজের নিয়ম নিজে বানায়। লিপি কারো পথে চলে না, নিজের পথে নিজে চলে; পথ না থাকলে লিপি নিজেই পথ তৈরি করে।"*

Welcome to the **LiPi Sovereign Universe**. LiPi is the world's first bilingual (Bengali + English) system programming language and computing universe that compiles directly to raw machine code on silicon with **0% C, 0% GCC, 0% LLVM, 0% libc, and 0% external host dependencies**.

---

## 🏛️ The Five Sovereign Iron Laws of LiPi

Every contribution to LiPi must adhere to these five architectural iron laws:

### 1. Zero External Dependency (0% C / 0% Libc)
LiPi does not use libc, standard C runtime, GNU binutils, or LLVM. All system calls are direct Linux/UNIX kernel invocations via raw assembly instructions (`syscall` on x86_64, `svc #0` on ARM64, `ecall` on RISC-V). Never introduce any C runtime bindings or external linkers into the core compiler or standard universe.

### 2. The Golden 35KB File Invariant
Every compiler source file inside `src/compiler/` **must strictly be $\le 35,000$ bytes in size**.
- **WHY:** LiPi's self-hosting micro-pipeline compiles source modules with linear register allocation and zero register spills. Small, focused, single-responsibility modules ensure deterministic compiler bootstrapping without stack blowouts.
- Any pull request containing a compiler file $> 35,000$ bytes will be automatically rejected by CI.

### 3. Tri-Syntax Parity
LiPi supports three syntax dialects simultaneously mapped to the same Abstract Syntax Tree (AST):
1. **Bengali Native Syntax**: `@কাঠামো`, `@ফাংশন`, `যদি`, `নাহলে`, `যতক্ষণ`, `ফেরত`
2. **English Canonical Syntax**: `struct`, `fn`, `if`, `else`, `while`, `return`
3. **Directive System Syntax**: `@struct`, `@fn`, `@if`, `@else`, `@while`, `@end`

New features in standard libraries (`universe/`) should provide both canonical English and native Bengali aliases.

### 4. Deterministic 4-Stage Bootstrap Closure
Any change to `src/compiler/` must maintain 100% bit-for-bit reproducibility across self-hosting compiler stages:
```bash
bin/lipc src/compiler/driver_cli.lp bin/lipc_stage2
bin/lipc_stage2 src/compiler/driver_cli.lp bin/lipc_stage3
bin/lipc_stage3 src/compiler/driver_cli.lp bin/lipc_stage4
cmp bin/lipc_stage3 bin/lipc_stage4 # Exit code must be exactly 0
```

### 5. 100% Test Pass Rate
All master regression tests in `tests/run_tests.lp` must pass 100% without any warnings, skipped tests, or flakiness.

---

## 🚀 Development Workflow

### 1. Prerequisites
- Linux OS (x86_64, ARM64, or RISC-V 64)
- LiPi seed binary (`bin/lipc`)
- No GCC, Clang, Python, or Make required!

### 2. Building the Compiler
To recompile the micro-pipeline compiler binary:
```bash
bin/lipc src/compiler/driver_cli.lp bin/lipc
```

### 3. Running the Regression Suite
```bash
bin/lipc tests/run_tests.lp /tmp/run_tests && /tmp/run_tests
```

### 4. Running the Ecosystem Build
To verify all 22 sovereign ecosystem targets:
```bash
./bin/lipi-build
```

---

## 📁 Codebase Structure

```
lipi/
├── bin/                   # Compiled sovereign binaries (lipc, lipi, lipi-build)
├── docs/                  # Architectural specs, handbook, and tutorials
├── packages/              # Sovereign package ecosystem (10 enterprise packages)
├── src/
│   ├── compiler/          # Micro-pipeline compiler modules (strictly <= 35KB each)
│   │   ├── diagnostics/   # Color themes, line index, source map, suggestions
│   │   ├── frontend/      # Lexer, tokenizer, AST expressions & statements
│   │   ├── semantics/     # Type checker, scope, symbol table, ownership check
│   │   └── backend/
│   │       ├── formats/   # Direct binary writers: ELF, Mach-O, PE, DWARF v4
│   │       ├── regalloc/  # Linear scan register allocation
│   │       └── targets/   # x86_64, ARM64, WASM, RISC-V direct synthesizers
│   ├── runtime/           # Bare-metal syscall stubs and arena allocators
│   └── tools/             # CLI drivers, LSP server, and code formatters
├── tests/                 # Master regression suite (177+ automated tests)
└── universe/              # Sovereign standard library (Web, Net, Crypto, AI, OS, DB)
```

---

## 📜 Pull Request Guidelines

1. **Self-Contained Commits**: Keep changes atomic and well-documented with clear WHY rationale.
2. **Invariant Check**: Verify all modified compiler files are within 35,000 bytes:
   ```bash
   python3 -c 'import os; [print(f"VIOLATION: {os.path.join(r, f)}") for r, d, fs in os.walk("src/compiler") for f in fs if f.endswith(".lp") and os.path.getsize(os.path.join(r, f)) > 35000]'
   ```
3. **Run 4-Stage Bootstrap**: Ensure `cmp stage3 stage4 == 0`.
