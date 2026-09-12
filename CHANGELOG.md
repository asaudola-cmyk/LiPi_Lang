# Lipi Language — Changelog

All notable changes to the Lipi Programming Language are documented here.

---

## [First 1.0.0] (প্রথম ১.০.০ — Official Sovereign Silicon Release) — 2026-09-13

### 👑 Sovereign Architecture & Milestone Achievements
- **100% Autonomous Silicon Code Generation**: Native ELF64 machine code generation with 0% C, 0% GCC, 0% LLVM, 0% Python runtime dependencies.
- **Triple-Gen Self-Hosting Closure**: Verified bit-for-bit deterministic self-hosting closure where Gen 2 and Gen 3 binaries match identically (0 bytes diff).
- **Unified Toolchain Suite**: All official tools standard-aligned and built natively:
  - `lipc` / `lipc_bin`: Core sovereign ELF64 compiler
  - `lipi`: Universal driver CLI
  - `lipipkg`: Sovereign package manager with Ed25519 cryptographic signing and verification
  - `lipidbg`: Native hardware debugger using Linux ptrace and hardware INT3 breakpoints
  - `lipirepl`: Interactive silicon REPL
  - `lipifmt`: Indentation and style code formatter
  - `lipilsp`: Standard JSON-RPC 2.0 Language Server Protocol implementation
  - `lipiconvert`: Bilingual syntax converter (Bengali <-> English)
- **Standard Library Ecosystem (`universe/`)**: 40+ production modules covering Core, Network/HTTP/TLS 1.3, Crypto (AES-GCM, SHA-256, Ed25519), Storage & ACID Key-Value DB, AI Tensor, 2D Rasterizer, and OS Unikernel bootloader.
- **Official VS Code IDE Extension**: Bilingual syntax highlighting, auto-indentation, snippets, and integrated LSP support packaged as `lipi-language-1.0.0.vsix`.
- **100% Test Suite Verification**: 130/130 sovereign regression and integration tests passing cleanly.

---

## [First 1.0.0-rc] — 2026-09-10

### 🎉 Initial Release

The first public release of the Lipi Programming Language.

### Runtime

#### Added
- **lipic2** — Python-based tree-walking interpreter
  - `src/runtime/lexer.py` — Unicode-aware tokenizer (Bengali + ASCII numerals)
  - `src/runtime/parser.py` — Recursive descent parser
  - `src/runtime/interpreter.py` — Tree-walking interpreter with proper scoping
  - `src/runtime/ast_nodes.py` — All AST node definitions
  - `src/runtime/stdlib.py` — Optional stdlib module loader
- **`bin/lipi`** — Global command: `lipi file.lp`, `lipi` (REPL), `lipi --version`
- **Interactive REPL** — `lipi` with no args starts REPL, preserves state between lines

#### Fixed (vs old lipic C binary)
- ✅ Recursive functions now work (factorial, fibonacci, tree traversal)
- ✅ `say variable` prints value, not memory address
- ✅ `struct` fields work correctly at runtime
- ✅ `for i in 1..N` range loops work
- ✅ `repeat N` loops work
- ✅ String interpolation `"Hello, {name}!"` works

### Language Features

#### Added
- **Minimal Global Standard syntax**
  ```lipi
  fn double n = n * 2
  if x > 10 say "big"
  for i in 1..10 say i
  repeat 5 say "hello"
  each item in myList say item
  ```
- **`for item in list`** — ForEach over any list/string (NEW in v1.0)
- **`each item in list`** — Alias for ForEach
- **Unicode identifiers** — Any Unicode script works as variable/function names
- **Bengali numeral support** — `৪২` is parsed as `42`
- **Both English and Bengali keywords** work simultaneously

### Stdlib Builtins (Runtime)

#### Added
- **Output:** `say`, `print`, `println`, `show`
- **Math:** `abs`, `min`, `max`, `pow`, `sqrt`, `floor`, `ceil`, `round`, `sin`, `cos`, `tan`, `log`, `pi`, `e`
- **String:** `len`, `upper`, `lower`, `trim`, `split`, `contains`, `starts_with`, `ends_with`, `replace`, `char_at`, `index_of`
- **List:** `list()`, `push`, `pop`, `get`, `set` / `list_get`, `list_set`, `sort`, `sum`, `join`
- **Type:** `str`, `int`, `float`, `bool`, `chr`, `ord`, `type`
- **File I/O:** `file_read`, `file_write`, `file_append`, `file_exists`
- **System:** `exit`, `time_ms`, `env`, `input`

### Standard Library (.lp files)

#### Added
- `std/math.lp` — Mathematical functions (abs, sqrt, gcd, lcm, is_prime, factorial, fibonacci)
- `std/str.lp` — String utilities (str_repeat, pad_left, pad_right, center)
- `std/io.lp` — I/O operations
- `std/http.lp` — HTTP patterns (status codes, response builders)
- `std/fmt.lp` — Formatting (pad_int, format_bytes, format_ms, print_ok/fail)
- `std/json.lp` — JSON helpers (json_str, json_num, json_response_ok/err)
- `std/version.lp` — Version constants (VERSION_NAME, CODENAME, RUNTIME)

### Bootstrap Compiler

#### Added
- **`src/compiler/lipic3.lp`** — Phase 0 of the self-hosting compiler, written in Lipi
  - Token struct definition
  - 21-keyword recognition table
  - Number, operator, and string tokenizer demo
  - Self-analysis: tokenizes Lipi syntax using Lipi
  - **Proves:** Lipi can process its own syntax (bootstrap prerequisite)

### Tests

#### Added
- 60 tests, all passing ✅
  - Tests 01-25: Core language (hello, math, structs, recursion)
  - Tests 26-50: Advanced (async, crypto, graphics, networking, OS)
  - Tests 51-60: Minimal syntax showcase
- All tests written in Global Standard (English identifiers, English comments)

### Tooling

#### Added
- **`install.sh`** — One-line GitHub installer
  ```bash
  curl -sSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
  ```
  - Python 3.8+ detection
  - Clones to `~/.lipi/`
  - Creates `~/.local/bin/lipi` command
  - Auto-adds to PATH in `.bashrc`/`.zshrc`
  - `--uninstall` flag

- **`vscode-lipi/`** — VS Code extension
  - TextMate syntax grammar for `.lp` files
  - 11 code snippets (`fn`, `if`, `while`, `for`, `struct`, ...)
  - Unicode/Bengali identifier highlighting
  - String interpolation highlighting

- **`docs/index.html`** — Landing page website (GitHub Pages compatible)
  - Dark theme, mobile responsive
  - Syntax showcase
  - Unicode demo (Bengali, Arabic, Chinese, Russian, Japanese, Korean)
  - Step-by-step install guide

- **`src/tools/bn2min.py`** — Bengali Lipi 1.0 → Minimal syntax converter
- **`src/tools/global_rename.py`** — Bengali identifier → English batch renamer

### CI/CD

#### Added
- **`.github/workflows/lipi-ci.yml`** — GitHub Actions
  - Tests on Python 3.9, 3.11, 3.12 (matrix)
  - Runs all 60 tests on every push/PR
  - Verifies install script
  - Badge: [![Tests](https://github.com/asaudola-cmyk/LiPi_Lang/actions/workflows/lipi-ci.yml/badge.svg)](https://github.com/asaudola-cmyk/LiPi_Lang/actions)

### Documentation

#### Added
- `README.md` — Professional English (356 lines)
  - 30-second install guide
  - Complete syntax reference
  - Unicode identifier documentation
  - Standard library table
  - Architecture diagram
  - Roadmap
- `docs/LIPI2_SYNTAX.md` — Language specification

---

## Roadmap

### [1.1] — lipic3 Phase 1 (Parser in Lipi)
- Write the Lipi parser as a Lipi program
- AST node generation in Lipi
- Milestone: Lipi parses Lipi

### [1.2] — lipic3 Phase 2 (Lipi → Python codegen)
- Code generator: Lipi AST → Python source
- Milestone: Lipi compiles Lipi to Python

### [2.0] — lipic3 Phase 3 (Lipi → C)
- Lipi to C transpiler written in Lipi
- Compile C to native binary
- Milestone: Zero Python dependency

### [3.0] — Full Bootstrap
- lipic3 compiles itself
- True self-hosting: Lipi builds Lipi
- WASM target for browser execution
