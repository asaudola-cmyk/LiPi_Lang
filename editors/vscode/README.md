# Lipi VS Code Extension

Syntax highlighting, code snippets, file icons, and Language Server (`lipilsp`) integration for `.lp`, `.lipi`, and `.লিপি` files.

## Features

- Bilingual syntax highlighting for English, Bengali, and `@`-directive Lipi syntax
- Bengali Unicode numeral highlighting (`০`–`৯`)
- Bracket matching, auto-closing pairs, and language snippets
- Integration with `bin/lipilsp` (LSP) and `bin/lipifmt` (formatter)

## Installation

### From Packaged VSIX

```bash
make
code --install-extension dist/lipi-language-1.0.0.vsix
```

### Manual Local Install

```bash
mkdir -p ~/.vscode/extensions/lipi-language-1.0.0
cp -r editors/vscode/* ~/.vscode/extensions/lipi-language-1.0.0/
```

Reload VS Code (`Ctrl+Shift+P` → `Developer: Reload Window`).
