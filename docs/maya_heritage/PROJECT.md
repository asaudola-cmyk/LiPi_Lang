# Project: Maya Sovereign Production Remediation

## Architecture
The Maya Ecosystem is a sovereign, freestanding programming language and operating environment designed to run directly on bare metal and the Linux kernel without GNU C Library (`libc`), GCC/Clang, Python, or shell dependencies.

```
+-------------------------------------------------------------------------------+
|                             MAYA APPLICATION LAYER                             |
|              apps/ (mpm, gui, ide), examples/, tests/, user scripts           |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                           UNIVERSE SUBSYSTEMS LAYER                           |
|  - universe/db/       : Pure Maya SQL Parser, Query Planner, Storage Engines   |
|  - universe/security/ : RFC 7519 JWT, BPF Seccomp Sandbox, Cryptography       |
|  - universe/ai/       : Pure Maya Tensors, Transformer Forward Pass & Argmax  |
|  - universe/net/      : Raw TCP/UDP Sockets, Valid Checksums, Gossip Protocol |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                          RUNTIME & MEMORY MANAGEMENT                          |
|  - runtime/maya_gc.maya : Pure Maya Slab Allocator + Tri-color Mark & Sweep  |
|  - runtime/syscall.s    : Freestanding Assembly Gateway & Linux Syscalls      |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                        COMPILER & MACHINE CODE EMITTER                        |
|  - cmd/maya/maya        : Native CLI compiler binary (Zero-GCC, Zero C-gen)   |
|  - compiler/backend/    : Direct ELF64 Binary & x86_64 Machine Code Emitter   |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                         LINUX KERNEL DIRECT SYSCALLS                          |
|             Raw Syscalls (x86_64: sys_read, sys_write, sys_mmap, etc.)        |
+-------------------------------------------------------------------------------+
```

## Feature Inventory
Every feature enumerated from the Survey phase (`ORIGINAL_REQUEST.md` and `maya_full_audit_bn.md`):

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Zero-C Compilation | Delete C transpilation and `gcc` execution; emit machine code directly | M1 | Survey / Audit §1.7 |
| 2 | Freestanding ELF64 Emission | Generate valid 64-bit ELF headers, PT_LOAD program headers, standalone `_start` | M1 | Survey / Audit §1.7 |
| 3 | Pure Maya Compiler Backend | Fix virtual register syntax bugs in `codegen.maya` (lines 977, 1035, 1081) | M1 | Survey / Audit §1.7 |
| 4 | Native Syscall Execution | Replace mock file syscalls in `universe/os/syscalls.maya` with real syscalls | M1 | Survey / Audit §1.7 |
| 5 | Clean Binary Verification | Verify `strings bin/maya \| grep gcc` returns 0 matches and no intermediate `.c` files | M1 | Survey / Audit §1.7 |
| 6 | Active Memory Deallocation | Replace no-op `ret` in `maya_free` with freelist deallocation | M2 | Survey / Audit §1.6 |
| 7 | Pure Maya Slab Allocator | 64KB aligned arenas with 8 size classes (16B-2048B) and O(1) freelist | M2 | Survey / Audit §1.6 |
| 8 | Tri-Color Mark & Sweep GC | Active garbage collection with root set scanning and heap compaction | M2 | Survey / Audit §1.6 |
| 9 | Memory Safety & Buffer Fixes | Dynamically size buffers in `maya_str_replace` to prevent 4KB overflow | M2 | Survey / Audit §2.2 |
| 10 | Concurrency & ABI Fixes | Atomic `lock xadd` in `maya_atomic_add`, thread-safe `maya_alloc`, map `rcx` to `r10` | M2 | Survey / Audit §2.3, 2.4 |
| 11 | Shell & Libc Eradication | Remove `/bin/sh -c` invocation and `environ` symbol from `runtime/syscall.s` | M2 | Survey / Audit §2.4, 2.5 |
| 12 | SQL Parser Remediation | Eradicate 400 dummy functions (`parse_extension_0..399`) & fix missing `@end` syntax | M3 | Survey / Audit §1.1 |
| 13 | Genuine SQL Statements | Implement real recursive-descent parsing for Select, Insert, Update, Delete | M3 | Survey / Audit §1.1 |
| 14 | SQL Planner & Storage Realism | Replace hardcoded costs and dummy integer returns in planner, executor, stores | M3 | Survey / Audit §1.1 |
| 15 | BPF Seccomp Sandbox | Implement genuine `prctl(PR_SET_NO_NEW_PRIVS)` and `sys_seccomp` BPF filter loading | M3 | Survey / Audit §1.2 |
| 16 | RFC 7519 / 2104 Compliant JWT | Implement real cryptographic HMAC-SHA256 preventing length extension attacks | M3 | Survey / Audit §1.2 |
| 17 | Sound Cryptography & ZKP | Fix ZKP algebraic polynomial identity tautology and connect BigInt to RSA | M3 | Survey / Audit §1.2 |
| 18 | Dynamic AI Token Generation | Implement greedy argmax/softmax on Transformer logits (eliminate hardcoded token 1) | M3 | Survey / Audit §1.4 |
| 19 | Authentic BPE Tokenizer | Replace static mock token array in `dataset.maya` with genuine BPE tokenization | M3 | Survey / Audit §1.4 |
| 20 | Sound Networking & Sockets | Implement real UDP gossip sending, remove gRPC mock fallback, compute raw checksums | M3 | Survey / Audit §1.3 |
| 21 | Eradicate Dummy Assertions | Delete all 1,199 tautological `assert_eq(1, 1)` and `assert_true(1)` statements | M4 | Survey / Audit §1.8 |
| 22 | Maya Syntax Compliance | Rewrite 10 Rust-syntax test files into authentic pure Maya syntax | M4 | Survey / Audit §1.8 |
| 23 | Unmocked Test Runner | Overhaul `universe/tools/maya_test.maya` to run real test processes and capture exit codes | M4 | Survey / Audit §1.8 |
| 24 | Application Entry Points | Fix missing top-level `main()` invocations and syntax in `apps/` and `examples/` | M4 | Survey / Audit §1.8 |
| 25 | Comprehensive E2E Test Suite | 4-Tier requirement-driven test suite (Features, Boundaries, Pairs, Real Applications) | E2E | Project Pattern |
| 26 | 100% E2E Pass & Adversarial Hardening | Pass 100% of E2E test suite followed by Tier 5 adversarial verification | M5 | Project Pattern |

## Milestones
| # | Name | Scope | Dependencies | Status | Sub-Orchestrator Conv ID |
|---|------|-------|-------------|--------|--------------------------|
| M1 | Native Machine Code Emitter & Zero-C Compiler | Features 1-5: Direct ELF64 emission, delete C-gen & gcc, fix codegen.maya | none | IN_PROGRESS | d51a7a98-d1b2-4b39-ae80-47dfc4ffd31d |
| M2 | Pure Maya GC & Active Memory Reclamation | Features 6-11: Slab allocator, Tri-color GC, fix buffer overflows & ABI | none | IN_PROGRESS | 749dacbe-08e0-4211-9994-e2e84805a84e |
| M3 | Universe Subsystems Remediation | Features 12-20: Clean SQL parser, Seccomp BPF, RFC JWT, AI argmax, Net | none | IN_PROGRESS | cd6c5e9c-a2ce-4e15-b52c-2517dbe2ac3f |
| M4 | Test Suite & Runner Remediation | Features 21-24: Remove 1,199 dummy assertions, fix Rust tests, real runner | none | IN_PROGRESS | b45d2718-2d7e-4402-9e60-a10676c65ad5 |
| M5 | 100% E2E Pass & Adversarial Coverage Hardening | Feature 26: Pass 100% of E2E suite, Tier 5 adversarial stress testing | M1, M2, M3, M4, E2E | PLANNED | Pending completion of M1-M4 & E2E |
| E2E | E2E Testing Track (Parallel) | Feature 25: Build 4-Tier test suite & publish TEST_READY.md | none | IN_PROGRESS | 2718481e-7c43-4a4c-960c-e049c031a7e1 |

## Interface Contracts

### Compiler CLI ↔ Runtime
- **Input**: Maya source files (`.maya` or `.my`).
- **Output**: Standalone x86_64 ELF64 binary (VAddr `0x400000`, `PT_LOAD` RWX, standalone `_start` stub).
- **Invariants**:
  - No intermediate `.c` or `.o` files generated anywhere.
  - Zero external toolchain invocations (`gcc`, `clang`, `ld`).
  - Statically linked, freestanding binary requiring zero shared libraries.

### Runtime Memory Engine ↔ Universe / Application Code
- **Signatures**:
  - `maya_alloc(size: u64) -> *u8`: Allocates `size` bytes from slab arena or mmap. Returns 8-byte aligned pointer.
  - `maya_free(ptr: *u8)`: Returns memory to freelist immediately (O(1)).
  - `gc_collect()`: Conservative mark-and-sweep across CPU registers and call stack. Reclaims unmarked slabs.
- **Invariants**:
  - A loop allocating and freeing memory must maintain stable RSS memory usage (zero leaks).

### Security Module ↔ External Consumers
- **Signatures**:
  - `jwt_sign(header: string, payload: string, secret: string) -> string`: Returns `header.payload.signature` where signature is standard Base64URL-encoded HMAC-SHA256 computed per RFC 2104 / RFC 7519.
  - `jwt_verify(token: string, secret: string) -> i64`: Returns 1 if valid, 0 if invalid or tampered.
- **Invariants**:
  - No length extension vulnerability (must not use naive string concatenation `input + ":" + secret`).

### AI Module ↔ Consumers
- **Signatures**:
  - `gpt_generate_token(gpt, prompt_tokens, temperature) -> i64`: Computes forward pass logits across vocabulary and selects token index using greedy argmax or temperature sampling.
- **Invariants**:
  - Token output must vary deterministically based on network weights and input tokens (never hardcoded `1`).

## Code Layout
- `compiler/` - Pure Maya AST, IR, and backend machine code emitters.
- `cmd/maya/` - Native compiler driver executable.
- `runtime/` - Native assembly syscall layer (`runtime/syscall.s`) and Pure Maya GC (`runtime/maya_gc.maya`).
- `universe/` - Standard library modules (db, security, ai, net, os, etc.).
- `tests/` - Unit tests, integration tests, adversarial stress tests.
- `tests/e2e/` - 4-Tier end-to-end verification test suite.
- `.agents/` - Orchestration metadata, plans, progress logs, handoff reports.
