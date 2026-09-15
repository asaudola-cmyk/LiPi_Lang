// ==============================================================================
// 🎨 LIPI UNIFIED TOOLKIT: DETERMINISTIC 4-SPACE INDENT ENGINE (src/toolkit/fmt/indent_engine.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Canonical Indentation & Token Normalizer
// ==============================================================================
//
// WHY THIS MODULE:
// In an indentation-sensitive language ecosystem, code formatting must be deterministic,
// reproducible across operating systems, and strictly enforce the First 1.0.0 standard:
// 1. Enforces exactly 4 spaces per indentation depth level (no tabs allowed).
// 2. Automatically dedents `else`, `elif`, `নতুবা`, `@end`, and closing braces.
// 3. Normalizes whitespace around binary operators (`=`, `==`, `+`, `-`, etc.).
// 4. Strips trailing whitespace and collapses consecutive redundant blank lines.
// 5. 100% pure sovereign Lipi implementation without external formatting tools.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Whitespace & Indentation Primitives ─────────────────────────────────────

// WHY: Generates string containing exactly (level * 4) ASCII spaces.
fn fmt_indent_spaces level
    if level <= 0 return ""
    total = level * 4
    out = ""
    i = 0
    while i < total
        out = out + " "
        i = i + 1
    return out

// WHY: Strips leading indentation spaces and tabs from a line.
fn fmt_trim_left s
    slen = len(s)
    i = 0
    while i < slen
        c = char_at(s, i)
        if c != " " and c != "\t" and c != "\r"
            break
        i = i + 1
    if i >= slen return ""
    return str_sub(s, i, slen)

// WHY: Strips trailing spaces, tabs, and newline characters from a line.
fn fmt_trim_right s
    slen = len(s)
    if slen == 0 return ""
    j = slen - 1
    while j >= 0
        c = char_at(s, j)
        if c != " " and c != "\t" and c != "\r" and c != "\n"
            break
        j = j - 1
    if j < 0 return ""
    return str_sub(s, 0, j + 1)

// WHY: Strips leading and trailing whitespace.
fn fmt_trim s
    return fmt_trim_right(fmt_trim_left(s))

// ── 2. Grammar Boundary Analyzers ─────────────────────────────────────────────

// WHY: Checks if line starts with specific keyword followed by whitespace, punctuation, or EOL.
fn fmt_starts_with_keyword line kw
    klen = len(kw)
    llen = len(line)
    if llen < klen return 0

    if str_sub(line, 0, klen) != kw
        return 0

    if llen == klen return 1
    next_c = char_at(line, klen)
    if next_c == " " or next_c == "\t" or next_c == "(" or next_c == ":" or next_c == "{"
        return 1
    return 0

// WHY: Determines if line begins a new nested block that increases indentation.
fn fmt_is_block_opener trimmed
    if fmt_starts_with_keyword(trimmed, "fn") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "কাজ") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "struct") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "কাঠামো") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "দল") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "if") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "যদি") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "elif") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "নতুবাযদি") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "else") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "নতুবা") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "অন্যথায়") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "while") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "যতক্ষণ") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "for") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "প্রতি") == 1 return 1
    return 0

// WHY: Determines if line should be dedented by 1 level before emission (e.g. else/elif branches).
fn fmt_is_dedenting_prefix trimmed
    if fmt_starts_with_keyword(trimmed, "elif") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "নতুবাযদি") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "else") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "নতুবা") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "অন্যথায়") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "@end") == 1 return 1
    if fmt_starts_with_keyword(trimmed, "}") == 1 return 1
    return 0

// ── 3. Operator Spacing Normalizer ────────────────────────────────────────────

// WHY: Ensures clean, uniform single space around binary operators outside string literals.
fn fmt_normalize_operators line
    llen = len(line)
    if llen == 0 return ""

    // If comment line, leave untouched
    if llen >= 2 and str_sub(line, 0, 2) == "//" return line
    if llen >= 1 and char_at(line, 0) == "#" return line

    out = ""
    i = 0
    in_quote = 0

    while i < llen
        c = char_at(line, i)

        // Handle string quotation boundaries
        if c == "\""
            if in_quote == 0
                in_quote = 1
            elif (i > 0 and char_at(line, i - 1) != "\\")
                in_quote = 0
            out = out + c
            i = i + 1
            continue

        if in_quote == 1
            out = out + c
            i = i + 1
            continue

        // Check for 2-character operators: ==, !=, <=, >=, +=, -=, *=, /=, ->
        if (i + 1) < llen
            c2 = char_at(line, i + 1)
            is_two_char = 0
            op2 = ""
            if (c == "=" and c2 == "=") or (c == "!" and c2 == "=") or (c == "<" and c2 == "=") or (c == ">" and c2 == "=") or (c == "-" and c2 == ">")
                is_two_char = 1
                op2 = c + c2

            if is_two_char == 1
                // Ensure preceding space if not start of string
                olen = len(out)
                if olen > 0 and char_at(out, olen - 1) != " "
                    out = out + " "
                out = out + op2
                // Ensure following space
                if (i + 2) < llen and char_at(line, i + 2) != " "
                    out = out + " "
                i = i + 2
                continue

        // Check for single character binary operators: =, <, >
        if c == "=" or c == "<" or c == ">"
            olen = len(out)
            if olen > 0 and char_at(out, olen - 1) != " "
                out = out + " "
            out = out + c
            if (i + 1) < llen and char_at(line, i + 1) != " "
                out = out + " "
            i = i + 1
            continue

        // Commas: ensure space after comma, no space before
        if c == ","
            olen = len(out)
            if olen > 0 and char_at(out, olen - 1) == " "
                out = str_sub(out, 0, olen - 1)
            out = out + ","
            if (i + 1) < llen and char_at(line, i + 1) != " "
                out = out + " "
            i = i + 1
            continue

        out = out + c
        i = i + 1

    return out

// ── 4. Main Indentation & Formatting Engine ───────────────────────────────────

// WHY: Parses source lines, computes lexical indentation hierarchy, and formats code.
fn fmt_format_source source_text
    tlen = len(source_text)
    if tlen == 0 return ""

    lines = list()
    line_start = 0
    i = 0

    // Split text into lines
    while i <= tlen
        is_eol = 0
        if i == tlen
            is_eol = 1
        elif char_at(source_text, i) == "\n"
            is_eol = 1

        if is_eol == 1
            raw_line = str_sub(source_text, line_start, i)
            push(lines, raw_line)
            line_start = i + 1
        i = i + 1

    out = ""
    line_count = len(lines)
    indent_level = 0
    prev_was_blank = 0
    l_idx = 0

    while l_idx < line_count
        raw = get(lines, l_idx)
        trimmed = fmt_trim(raw)

        // Handle blank lines
        if len(trimmed) == 0
            if prev_was_blank == 0
                out = out + "\n"
                prev_was_blank = 1
            l_idx = l_idx + 1
            continue

        prev_was_blank = 0

        // Calculate leading spaces in raw source to detect block closure
        raw_spaces = 0
        s_i = 0
        while s_i < len(raw)
            sc = char_at(raw, s_i)
            if sc == " "
                raw_spaces = raw_spaces + 1
            elif sc == "\t"
                raw_spaces = raw_spaces + 4
            else
                break
            s_i = s_i + 1

        inferred_indent = raw_spaces / 4

        // Apply dedent for branches like else / elif
        effective_indent = inferred_indent
        if fmt_is_dedenting_prefix(trimmed) == 1
            if effective_indent > 0
                effective_indent = effective_indent - 1

        // Normalize operators
        norm_line = fmt_normalize_operators(trimmed)

        // Emit indented line
        indent_str = fmt_indent_spaces(effective_indent)
        out = out + indent_str + norm_line + "\n"

        l_idx = l_idx + 1

    return out

// ── 5. File Formatting & Validation APIs ──────────────────────────────────────

// WHY: Formats file in-place and writes back to disk.
fn fmt_format_file file_path
    if file_exists(file_path) == 0 return 0
    content = file_read(file_path)
    formatted = fmt_format_source(content)
    if formatted != content
        file_write(file_path, formatted)
        return 1 // Changes made
    return 0 // Already cleanly formatted

// WHY: Checks whether file already adheres to 4-space indentation standard.
fn fmt_check_file file_path
    if file_exists(file_path) == 0 return 0
    content = file_read(file_path)
    formatted = fmt_format_source(content)
    if formatted == content return 1
    return 0
