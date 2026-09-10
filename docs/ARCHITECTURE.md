# 🏛️ Lipi 5-Stage Nano-Compiler Engine Architecture

## Abstract
The Lipi compiler (`src/compiler/elf_emitter.lp` and `src/compiler/c_codegen.lp`) is a 100% self-hosted, sovereign compilation engine written entirely in pure Lipi. It translates high-level Lipi programs directly into native, standalone 64-bit Linux ELF binaries without intermediary assembly files, external linkers (`ld`), or C runtimes (`libc`).

```
[Lipi Source (.lp)] ➔ [1. Lexer] ➔ [2. AST Parser] ➔ [3. SSA IR Optimizer] ➔ [4. Linear Scan RegAlloc] ➔ [5. ELF64 Synthesis] ➔ [Hardware Execution]
```

---

## Stage 1: Lexical Analysis (টোকেনাইজার)
- Scans UTF-8 byte streams directly from memory or disk.
- Recognizes Bengali and English keywords, identifiers, string literals, and compound operators (`<=`, `>=`, `==`, `!=`).
- Tracks line numbers and byte offsets for error reporting.

## Stage 2: Abstract Syntax Tree Parser (এএসটি_তৈরি)
- Recursive-descent grammar analysis producing hierarchical `এএসটি_নোড` tree structures.
- Parses control flow (`যতক্ষণ` while loops, `যদি`/`নাহলে` conditional branches).
- Validates user-defined composite types (`গঠন` structs) and field offsets.

## Stage 3: Static Single Assignment IR & Optimization (এসএসএ_আইআর)
- Converts variable mutations into single-assignment versions (`v0`, `v1`, `v2`).
- **Constant Folding**: Evaluates constant expressions at compile-time.
- **Granlund-Montgomery Strength Reduction**: Transforms expensive division and modulo instructions (`idiv`) into reciprocal multiplications and bitwise masks for known divisor constants.

## Stage 4: Linear Scan Hardware Register Allocation (রেজিস্টার_বরাদ্দকরণ)
- Computes live intervals for loop induction variables and accumulators.
- Greedily binds high-traffic loop variables directly to CPU hardware registers (`%r12`, `%r13`, `%r14`, `%r15`).
- Eliminates 10-cycle memory bus round-trips (`[rbp - offset]`), enabling 0-cycle register-renamed loop execution.
- Emits callee-saved preservation (`push r12-r15` / `pop r12-r15`) complying with System V AMD64 ABI.

## Stage 5: Standalone Linux ELF64 Binary Synthesis (লিনাক্স_এলফ_সিন্থেসিস)
- Constructs valid 64-byte `Elf64_Ehdr` (Magic: `\x7fELF`, Class: 2, Machine: 62, Entry: `0x401000`).
- Constructs single monolithic 56-byte `Elf64_Phdr` (Type: `PT_LOAD`, Flags: `PF_R | PF_W | PF_X`, VAddr: `0x400000`).
- Generates 3976 zero-bytes page alignment padding to guarantee page alignment (`0x1000`).
- Emits raw x86_64 machine code instructions into `.text` segment starting at file offset 4096 (`0x401000`).
- Emits static string data into `.rodata` immediately following machine instructions.
- Writes binary directly to disk using `SYS_open` (Syscall 2) and applies executable permissions `0755` via `SYS_chmod` (Syscall 90).
