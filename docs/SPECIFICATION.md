# 👑 The Sovereign Lipi Language Specification (v1.0.0)

## 1. Overview & Philosophy
**Lipi (লিপি)** is a high-performance, statically compiled, sovereign programming language engineered for direct silicon execution. 
- **Zero Runtime Dependencies**: Generates standalone 64-bit Linux ELF binaries with 0% Libc, 0% GCC, and 0% VM dependency.
- **Native Bilingual Grammar**: First-class support for both native Bengali syntax and international English keywords.
- **System V AMD64 ABI**: Adheres to standard hardware register calling conventions (`%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8`, `%r9`).
- **Deterministic Memory Model**: Direct kernel page allocation via `SYS_mmap` and `SYS_munmap` without dynamic allocator overhead.

---

## 2. Lexical Elements & Keywords

### 2.1 Keyword Mapping (Bilingual)
| Bengali Keyword | English Keyword | Semantics / Purpose |
|:---|:---|:---|
| `ধরি` | `let` / `var` | Variable declaration and binding |
| `যদি` | `if` | Conditional branch condition |
| `নাহলে` / `অন্যথায়` | `else` | Conditional fallback alternative branch |
| `যতক্ষণ` | `while` / `loop` | Loop while condition remains non-zero |
| `কাজ` / `ফাংশন` | `fn` / `func` | Function definition with System V ABI |
| `ফেরত` | `return` | Function value return in `%rax` register |
| `গঠন` | `struct` | Composite user-defined structured data type |
| `অন্তর্ভুক্ত` | `include` / `import` | Source-level modular inclusion |
| `দেখাও` | `print` / `echo` | Console output via kernel `SYS_write` |
| `সিসকল` | `syscall` | Direct Linux kernel system call |

### 2.2 Numeric Literals
Lipi natively parses both Eastern-Arabic Bengali numerals (`০`-`৯`) and Western-Arabic numerals (`0`-`9`):
```lipi
ধরি x = ১০০      // Evaluates to 100 decimal
ধরি y = 200      // Evaluates to 200 decimal
```

---

## 3. Memory & Pointer Model
- **Heap Allocation**: `মেমরি_বরাদ্দ(size)` maps private anonymous memory pages via `SYS_mmap` (Syscall 9).
- **Heap Deallocation**: `মেমরি_মুক্তি(ptr, size)` unmaps virtual address pages via `SYS_munmap` (Syscall 11).
- **Pointer Arithmetic**:
  - `মেমরি_বাইট_লেখো(ptr, offset, byte)`: Stores 8-bit unsigned byte at address `ptr + offset`.
  - `মেমরি_বাইট_পড়ো(ptr, offset)`: Loads 8-bit unsigned byte from address `ptr + offset`.
  - `মেমরি_শব্দ_লেখো(ptr, index, qword)`: Stores 64-bit integer at address `ptr + (index * 8)`.
  - `মেমরি_শব্দ_পড়ো(ptr, index)`: Loads 64-bit integer from address `ptr + (index * 8)`.

---

## 4. Function Calling Convention & Stack Layout
Lipi follows the System V AMD64 ABI:
- **Parameters 1–6**: Passed in hardware registers `%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8`, `%r9`.
- **Return Value**: Returned in `%rax`.
- **Callee-Saved Registers**: `%rbx`, `%rsp`, `%rbp`, `%r12`, `%r13`, `%r14`, `%r15`.
- **Stack Alignment**: 16-byte aligned before any external function invocation or system call.

---

## 5. Direct Linux Kernel Syscall Interface
Lipi enables direct system calls without standard C library (`libc`) wrappers:
`সিসকল(number, arg1, arg2, arg3, arg4, arg5, arg6)`
- `SYS_read` (0): File/socket descriptor read
- `SYS_write` (1): File/socket descriptor write
- `SYS_open` (2): File descriptor creation and opening
- `SYS_close` (3): File descriptor teardown
- `SYS_mmap` (9): Kernel page virtual address allocation
- `SYS_exit` (60): Process termination with return code
