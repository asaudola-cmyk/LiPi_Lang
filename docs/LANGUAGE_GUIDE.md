# Lipi Language Guide (লিপি ভাষার গাইড)

Lipi supports Bengali syntax, English syntax, and `@`-directive syntax interchangeably. All three forms compile to the same AST and produce identical native machine code.

## 1. Hello World

English:

```lipi
fn main
    say "Hello, World!"
    return 0

main()
```

Bengali:

```lipi
ফাংশন প্রধান
    বলো "হ্যালো, দুনিয়া!"
    ফেরত ০

প্রধান()
```

Compile and run:

```bash
./bin/lipc hello.lp -o hello
./hello

# Or via the unified CLI:
./bin/lipi run hello.lp
```

## 2. Variables, Literals & Types

- **64-bit signed integers (`i64`)**: `42`, `-10`, `০`, `৪২`, `0xFF` (Bengali digits `০`–`৯` are parsed identically to `0`–`9`).
- **Floating-point numbers (`f64`)**: `3.14`, `0.5`.
- **Strings**: UTF-8 strings (`"hello"`, `"বাংলা"`).
- **Booleans**: `true` / `সত্য` (`1`), `false` / `মিথ্যা` (`0`).
- **Lists**: Dynamic lists created with `list()`, manipulated via `push`, `pop`, `len`, indexing `xs[i]`.

```lipi
x = 10
y = 20
total = x + y
say "Total: " + to_str(total)

নাম = "লিপি"
সংখ্যা = ৪২
বলো নাম + " " + to_str(সংখ্যা)
```

## 3. Control Flow

### Conditionals (`if` / `else`, `যদি` / `নাহলে` / `নতুবা`)

```lipi
if x > 10
    say "greater"
else
    say "smaller or equal"
```

```lipi
যদি সংখ্যা > ১০
    বলো "বড়"
নাহলে
    বলো "ছোট বা সমান"
```

### Loops (`while` / `যতক্ষণ`, `for`)

```lipi
i = 0
while i < 5
    say to_str(i)
    i = i + 1
```

```lipi
i = ০
যতক্ষণ i < ৫
    বলো to_str(i)
    i = i + ১
```

## 4. Functions & Recursion

```lipi
fn fib n
    if n <= 1
        return n
    return fib(n - 1) + fib(n - 2)

fn main
    say to_str(fib(10))
    return 0

main()
```

Directive syntax (commonly used in standard library modules):

```lipi
@fn add(a: i64, b: i64)
    return a + b
@end
```

## 5. Structs & Methods

```lipi
struct Point
    x
    y

fn point_sum p
    return p.x + p.y

fn main
    p = Point()
    p.x = 3
    p.y = 4
    say to_str(point_sum(p))
    return 0

main()
```

## 6. Modules & Imports

Import core standard library modules from `utso/` or workspace packages from `aati/`:

```lipi
include "utso/io.lp"
include "utso/memory.lp"
include "utso/crypto/sha256.lp"
include "aati/lipi_sql/src/sql.lp"
```

Both `include "utso/io.lp"` and `import "utso/io"` forms are supported.

## 7. Memory Management & `--kavach` Safety

### Segregated Slab Allocator

```lipi
buf = alloc(64)
mem_write(buf, 0, 12345)
val = mem_read(buf, 0)
free(buf)
```

### Direct Syscalls & Hardware Boundary (`--kavach`)

When compiling with `./bin/lipc app.lp -o app --kavach`, raw hardware operations (`syscall`, `mem_write`, `mem_read`) must live inside functions prefixed with `silicon_` or `সিলিকন_`:

```lipi
fn silicon_write_byte ptr offset val
    mem_byte_write(ptr, offset, val)
    return 0
```

## 8. Cross-Compilation Targets

```bash
# Linux x86_64 Static-PIE ELF64 (default)
./bin/lipc app.lp -o app

# Windows x86_64 PE32+
./bin/lipc app.lp -o app.exe --target windows

# macOS Mach-O
./bin/lipc app.lp -o app_macos --target macos

# ARM64 / RISC-V 64 / WebAssembly
./bin/lipc app.lp -o app_arm64 --target arm64
./bin/lipc app.lp -o app_rv64 --target riscv64
./bin/lipc app.lp -o app.wasm --target wasm
```

## 9. Bilingual Keyword Quick Reference

| Concept | English | Bengali | Directive |
|---|---|---|---|
| Function | `fn` | `ফাংশন` / `কাজ` | `@fn` ... `@end` |
| Struct | `struct` | `গঠন` / `কাঠামো` | `@struct` ... `@end` |
| Return | `return` | `ফেরত` | `return` |
| If / Else | `if` / `else` | `যদি` / `নাহলে` / `নতুবা` | `@if` / `@else` / `@end` |
| While | `while` | `যতক্ষণ` | `@while` ... `@end` |
| Break / Continue | `break` / `continue` | `থামো` / `চলো` | `break` / `continue` |
| Print | `say` / `println` | `বলো` / `দেখাও` | `say` / `println` |
| Import | `import` / `include` | `আমদানি` / `অন্তর্ভুক্ত` | `import` / `include` |
| True / False | `true` / `false` | `সত্য` / `মিথ্যা` | `1` / `0` |
