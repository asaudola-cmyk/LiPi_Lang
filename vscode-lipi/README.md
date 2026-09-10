# Lipi Language — VS Code Extension

Syntax highlighting for the **Lipi Programming Language** (`.lp` files).

## Features

- ✅ Syntax highlighting (keywords, functions, strings, numbers, operators)
- ✅ Unicode/Bengali identifier highlighting
- ✅ String interpolation highlighting (`{variable}`)
- ✅ Comment highlighting (`// comment`)
- ✅ Code snippets (fn, if, while, for, struct, ...)
- ✅ Auto-indentation
- ✅ Bracket matching

## Install

### From VSIX (Recommended)
```bash
# Build the extension
cd vscode-lipi
npm install -g @vscode/vsce
vsce package
code --install-extension lipi-lang-1.0.0.vsix
```

### Manual Install
1. Copy `vscode-lipi/` to `~/.vscode/extensions/lipi-lang/`
2. Restart VS Code
3. Open any `.lp` file

## Usage

Open any `.lp` file and syntax highlighting activates automatically.

### Snippets
- `fn` → function definition
- `fnl` → one-liner function
- `if` / `ife` / `ifee` → if / if-else / if-elif-else
- `while` → while loop
- `for` → for range loop
- `rep` → repeat N times
- `struct` → struct definition
- `factorial` → recursive factorial template
- `fibonacci` → iterative fibonacci template

## Lipi Quick Start

```lipi
// Hello World
say "Hello, World!"

// Function
fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

say factorial 10    // 3628800

// Unicode identifiers
নাম = "Lipi"
say নাম
```

## Links

- [Lipi GitHub](https://github.com/asaudola-cmyk/LiPi_Lang)
- [Install Lipi](https://github.com/asaudola-cmyk/LiPi_Lang#install)
