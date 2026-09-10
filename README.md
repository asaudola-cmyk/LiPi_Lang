<div align="center">

# Lipi Programming Language
### *Simpler than Python. Global by design.*

**Lipi First 1.0 — Sovereign**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/compiler-Sovereign%20Native%20ELF-blue)](#architecture)
[![Unicode](https://img.shields.io/badge/identifiers-Unicode%20✓-orange)](#unicode)

</div>

---

## Install

```bash
curl -sSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
```

Or clone manually:

```bash
git clone https://github.com/asaudola-cmyk/LiPi_Lang ~/.lipi
echo 'export PATH="$PATH:$HOME/.lipi/bin"' >> ~/.bashrc
source ~/.bashrc
```

Then run any `.lp` file:

```bash
lipi hello.lp           # Run a file
lipi                    # Interactive REPL
lipi --version          # Show version
lipi -e 'say "Hello"'  # One-liner
```

---

## Hello World

```lipi
say "Hello, World!"
```

```bash
$ lipi hello.lp
Hello, World!
```

---

## Why Lipi?

| Feature | Lipi | Python | JavaScript |
|---------|------|--------|-----------|
| No braces `{}` | ✅ | ✅ | ❌ |
| No colons `:` | ✅ | ❌ | ✅ |
| No semicolons `;` | ✅ | ✅ | Optional |
| No parens for calls | ✅ | ❌ | ❌ |
| Unicode identifiers | ✅ | Limited | Limited |
| `say` instead of `print()` | ✅ | ❌ | ❌ |
| Self-hosted (roadmap) | 🔄 | ✅ | ✅ |

**Minimal noise. Maximum clarity.**

```lipi
// Lipi                    // Python equivalent
fn double n = n * 2        # def double(n): return n * 2
say double 21              # print(double(21))
for i in 1..5             # for i in range(1, 6):
    say i                  #     print(i)
```

---

## Syntax Guide

### Variables
```lipi
name    = "Lipi"
version = 2
pi      = 3.14
active  = true
```

### Functions
```lipi
// One-liner
fn double n = n * 2
fn add a b  = a + b

// Multi-line
fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

say factorial 10    // 3628800
```

### Conditionals
```lipi
fn grade score
    if score >= 90
        return "A+"
    elif score >= 80
        return "A"
    elif score >= 70
        return "B"
    else
        return "F"

say grade 95    // A+
say grade 72    // B
```

### Loops
```lipi
// while loop
i = 0
while i < 5
    say i
    i = i + 1

// for range
for i in 1..10
    say i

// repeat N times
repeat 3
    say "hello"
```

### Structs
```lipi
struct Point
    x
    y

p = Point()
p.x = 10
p.y = 20
say p.x + p.y    // 30
```

### Strings
```lipi
name = "World"
say "Hello, " + name + "!"          // Concatenation
say "Hello, {name}!"                // Interpolation
say len "hello"                      // 5
```

---

## Unicode Identifiers

Any Unicode script works as identifiers — English keywords, your language's words:

```lipi
// Bengali identifiers
নাম     = "Lipi"
সংস্করণ = 2
say নাম

// Russian identifiers
версия = 1
say версия

// Function names in any script
fn যোগফল a b = a + b
say যোগফল 10 20    // 30
```

---

## Standard Library

| Module | Functions |
|--------|-----------|
| `std/math` | `abs`, `sqrt`, `gcd`, `lcm`, `is_prime`, `factorial`, `fibonacci`, `power`, `min`, `max` |
| `std/str` | `str_repeat`, `str_pad_left`, `str_pad_right`, `str_center` |
| `std/io` | `write_out`, `write_err`, `file_open`, `file_read`, `file_write` |
| `std/http` | `http_response`, `http_json`, `http_route`, HTTP status constants |
| `std/fmt` | `pad_int`, `format_bytes`, `format_ms`, `print_ok`, `print_fail` |
| `std/json` | `json_str`, `json_num`, `json_bool`, `json_response_ok`, `json_response_err` |

```lipi
include "std/math"
say fibonacci 20    // 6765
say is_prime 97     // 1 (true)
say factorial 12    // 479001600
```

---

## Tests

```bash
# Run all 60 tests (100% Native Regression Engine)
bash tests/run_tests.sh
```

60/60 tests pass:
- ✅ Tests 01-25: Core language (hello, math, loops, structs, recursion)
- ✅ Tests 26-50: Advanced (async, crypto, graphics, networking, OS)
- ✅ Tests 51-60: Minimal syntax showcase

---

## VS Code Extension

For syntax highlighting in VS Code:

```bash
# Method 1: Manual install
cp -r ~/.lipi/vscode-lipi ~/.vscode/extensions/lipi-lang
# Restart VS Code → .lp files get highlighting

# Method 2: Build VSIX
cd ~/.lipi/vscode-lipi
npm install -g @vscode/vsce
vsce package
code --install-extension lipi-lang-1.0.0.vsix
```

---

## Architecture
 
```
Lipi First 1.0 — Sovereign
│
├── bin/lipc               ← Sovereign Native Compiler (Direct ELF64 Machine Code)
├── bin/lipi               ← Universal Runner / CLI
├── src/compiler/          ← Compiler Core
│   ├── elf_emitter.lp     ← Pure Lipi Direct x86_64 Machine Code Generator (Zero GCC, Zero Libc)
│   ├── c_codegen.lp       ← Self-Hosted Native C Codegen Bootstrap
│   └── native_elf_compiler.c ← Sovereign In-Memory ELF Compiler Seed
├── std/                   ← Standard library (.lp files)
├── tests/                 ← 60 regression tests (all passing in Direct Machine Code)
├── examples/              ← Example programs
├── vscode-lipi/           ← VS Code extension
└── install.sh             ← One-line installer
```
 
### Roadmap
 
| Phase | Status | Description |
|-------|--------|-------------|
| **Direct ELF Machine Code** | ✅ Done | Zero GCC, Zero Libc, Zero Python standalone ELF64 emitter |
| **Self-Hosting Closure** | ✅ Done | Bit-for-bit deterministic reproducibility (Gen1 == Gen2) |
| **Bilingual Standard** | ✅ Done | Full Bengali (বাংলা) & English syntax interoperability |
| **ARM64 native** | 📋 Future | Compile .lp → ARM64 binary |
| **WASM target** | 📋 Future | Run Lipi in the browser |
| **lipi.dev** | 📋 Future | Online sovereign playground |

---

## Examples

### Fibonacci
```lipi
fn fibonacci n
    if n <= 1
        return n
    a = 0
    b = 1
    i = 2
    while i <= n
        c = a + b
        a = b
        b = c
        i = i + 1
    return b

for i in 0..15
    say fibonacci i
```

### Web Server (pattern)
```lipi
fn handle_home req   = "200 OK: Welcome to Lipi!"
fn handle_api req    = "200 OK: {\"version\":\"2.0\"}"
fn handle_404 req    = "404 Not Found"

fn dispatch path req
    if path == "/"
        return handle_home req
    elif path == "/api"
        return handle_api req
    else
        return handle_404 req

say dispatch "/" ""
say dispatch "/api" ""
```

### Struct + Methods
```lipi
struct Stack
    size

fn stack_push s val
    s.size = s.size + 1
    say "Push: " + val + " (size=" + s.size + ")"

fn stack_pop s
    if s.size == 0
        say "Stack empty!"
        return null
    s.size = s.size - 1

s = Stack()
s.size = 0
stack_push(s, 10)
stack_push(s, 20)
stack_push(s, 30)
stack_pop(s)
say "Final size: " + s.size
```

---

## Contributing

```bash
git clone https://github.com/asaudola-cmyk/LiPi_Lang
cd LiPi_Lang
./bin/lipi tests/01_hello.lp  # Verify setup (Zero Python)
```

Pull requests welcome! See [`docs/LIPI2_SYNTAX.md`](docs/LIPI2_SYNTAX.md) for the language spec.

---

## License

MIT License — free to use, modify, and distribute.

---

<div align="center">

**Lipi First 1.0 — Sovereign**  
*The language that speaks your language.*

[GitHub](https://github.com/asaudola-cmyk/LiPi_Lang) • [Issues](https://github.com/asaudola-cmyk/LiPi_Lang/issues) • [Install](#install)

</div>
