// ==============================================================================
// 👑 LIPI EXAMPLE: MARKDOWN PARSER (examples/markdown_parser.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

import "universe/core/string"

fn parse_inline line
    out = ""
    i = 0
    tlen = len(line)
    in_bold = 0
    in_code = 0
    
    while i < tlen
        matched = 0
        if i + 1 < tlen
            c2 = str_sub(line, i, i + 2)
            if c2 == "**"
                if in_bold == 0
                    out = out + "\x1b[1m"
                    in_bold = 1
                else
                    out = out + "\x1b[0m"
                    in_bold = 0
                i = i + 2
                matched = 1
        
        if matched == 0
            c1 = str_sub(line, i, i + 1)
            if c1 == "`"
                if in_code == 0
                    out = out + "\x1b[33m"
                    in_code = 1
                else
                    out = out + "\x1b[0m"
                    in_code = 0
                i = i + 1
                matched = 1
        
        if matched == 0
            out = out + str_sub(line, i, i + 1)
            i = i + 1
            
    if in_bold == 1
        out = out + "\x1b[0m"
    if in_code == 1
        out = out + "\x1b[0m"
    return out

fn parse_markdown doc
    tlen = len(doc)
    i = 0
    start_idx = 0
    
    while i <= tlen
        is_eol = 0
        if i == tlen
            is_eol = 1
        elif str_sub(doc, i, i + 1) == "\n"
            is_eol = 1
            
        if is_eol == 1
            line = str_sub(doc, start_idx, i)
            
            if str_starts_with(line, "# ") == 1
                inner = str_sub(line, 2, len(line))
                say "\x1b[1;34m" + parse_inline(inner) + "\x1b[0m"
            elif str_starts_with(line, "## ") == 1
                inner = str_sub(line, 3, len(line))
                say "\x1b[1;36m" + parse_inline(inner) + "\x1b[0m"
            elif str_starts_with(line, "- ") == 1
                inner = str_sub(line, 2, len(line))
                say "\x1b[32m•\x1b[0m " + parse_inline(inner)
            else
                say parse_inline(line)
                
            start_idx = i + 1
        i = i + 1

fn main
    say "=== Lipi Markdown Parser ==="
    say ""
    
    doc = "# Lipi Language\n"
    doc = doc + "\n"
    doc = doc + "Lipi is a **Pure Silicon** sovereign language.\n"
    doc = doc + "It has several powerful features:\n"
    doc = doc + "\n"
    doc = doc + "## Features\n"
    doc = doc + "- **Zero Libc** freestanding runtime\n"
    doc = doc + "- Built-in `Direct Silicon` machine code emitter\n"
    doc = doc + "- Native Bengali & English Tri-Syntax\n"
    doc = doc + "\n"
    doc = doc + "## Architecture\n"
    doc = doc + "Pure self-hosting with deterministic ELF64 generation.\n"
    
    parse_markdown(doc)
    return 0

main()
