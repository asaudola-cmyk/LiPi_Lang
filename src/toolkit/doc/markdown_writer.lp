// ==============================================================================
// 📖 LIPI UNIFIED TOOLKIT: AUTOMATIC MARKDOWN WRITER (src/toolkit/doc/markdown_writer.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Doc Comments & WHY Architectural Extractor
// ==============================================================================
//
// WHY THIS MODULE:
// Self-documenting codebases are a hallmark of mature software engineering.
// Standard doc tools (rustdoc, godoc) require foreign dependencies and fail to recognize
// Lipi's First 1.0.0 tri-syntax or bilingual Bengali/English constructs.
// This module provides:
// 1. Parsing of struct and fn signatures alongside doc comments (`// Doc:`, `// WHY:`, `// কেন:`).
// 2. Automated synthesis of GitHub-Flavored Markdown (GFM) API documentation.
// 3. GitHub alert callouts (`> [!NOTE]`, `> [!TIP]`) highlighting architectural WHY rationale.
// 4. Clean Table of Contents with jump links and standardized parameter breakdown tables.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates documented symbol metadata extracted from source code.
struct DocSymbol
    kind            // "struct" or "fn"
    name            // Symbol identifier
    signature       // Normalized declaration syntax
    summary         // General descriptive documentation
    why             // Architectural rationale (WHY comment)
    elements        // List of parameter names (fn) or field names (struct)

// WHY: Encapsulates parsed documentation state for an entire module file.
struct DocFile
    module_name     // Inferred or specified module identifier
    source_path     // Relative path to parsed .lp source file
    overview        // Top-level module banner description
    symbols         // List of DocSymbol structs

// ── 2. String & Line Parsing Helpers ──────────────────────────────────────────

// WHY: Strips leading spaces and tabs.
fn doc_trim_left s
    slen = len(s)
    i = 0
    while i < slen
        c = char_at(s, i)
        if c != " " and c != "\t" and c != "\r" break
        i = i + 1
    if i >= slen return ""
    return str_sub(s, i, slen)

// WHY: Strips trailing spaces, tabs, and newlines.
fn doc_trim_right s
    slen = len(s)
    if slen == 0 return ""
    j = slen - 1
    while j >= 0
        c = char_at(s, j)
        if c != " " and c != "\t" and c != "\r" and c != "\n" break
        j = j - 1
    if j < 0 return ""
    return str_sub(s, 0, j + 1)

// WHY: Strips whitespace from both ends.
fn doc_trim s
    return doc_trim_right(doc_trim_left(s))

// WHY: Splits space-separated words into a list.
fn doc_split_words s
    words = list()
    slen = len(s)
    i = 0
    while i < slen
        while i < slen and (char_at(s, i) == " " or char_at(s, i) == "\t")
            i = i + 1
        if i >= slen break

        w_start = i
        while i < slen and char_at(s, i) != " " and char_at(s, i) != "\t"
            i = i + 1
        push(words, str_sub(s, w_start, i))
    return words

// ── 3. Source Extraction Engine ───────────────────────────────────────────────

// WHY: Parses source code line-by-line, associating doc/why comments with definitions.
fn doc_extract_from_text source_text source_path
    doc_file = DocFile()
    doc_file.source_path = source_path
    doc_file.overview = ""
    doc_file.symbols = list()

    // Derive module name from source file path
    slen = len(source_path)
    last_slash = -1
    i = 0
    while i < slen
        if char_at(source_path, i) == "/" last_slash = i
        i = i + 1
    base = source_path
    if last_slash >= 0 base = str_sub(source_path, last_slash + 1, slen)
    if len(base) > 3 and str_sub(base, len(base) - 3, len(base)) == ".lp"
        base = str_sub(base, 0, len(base) - 3)
    doc_file.module_name = base

    // Split source into lines
    lines = list()
    line_start = 0
    tlen = len(source_text)
    i = 0
    while i <= tlen
        is_eol = 0
        if i == tlen is_eol = 1
        elif char_at(source_text, i) == "\n" is_eol = 1
        if is_eol == 1
            push(lines, str_sub(source_text, line_start, i))
            line_start = i + 1
        i = i + 1

    line_count = len(lines)
    pending_summary = ""
    pending_why = ""
    l_idx = 0

    while l_idx < line_count
        raw_line = get(lines, l_idx)
        trimmed = doc_trim(raw_line)
        tlen = len(trimmed)

        // Case 1: Doc comments and WHY rationale
        if tlen >= 2 and str_sub(trimmed, 0, 2) == "//"
            comment_body = doc_trim(str_sub(trimmed, 2, tlen))
            c_body_len = len(comment_body)

            // Check for "// WHY:" or "// কেন:"
            if c_body_len >= 4 and (str_sub(comment_body, 0, 4) == "WHY:" or str_sub(comment_body, 0, 4) == "why:")
                why_text = doc_trim(str_sub(comment_body, 4, c_body_len))
                if len(pending_why) > 0 pending_why = pending_why + " " + why_text
                else pending_why = why_text
            elif c_body_len >= 6 and str_sub(comment_body, 0, 6) == "কেন:"
                why_text = doc_trim(str_sub(comment_body, 6, c_body_len))
                if len(pending_why) > 0 pending_why = pending_why + " " + why_text
                else pending_why = why_text
            // Check for "// Doc:" or "// বিবরণ:"
            elif c_body_len >= 4 and str_sub(comment_body, 0, 4) == "Doc:"
                doc_text = doc_trim(str_sub(comment_body, 4, c_body_len))
                if len(pending_summary) > 0 pending_summary = pending_summary + " " + doc_text
                else pending_summary = doc_text
            elif c_body_len >= 8 and str_sub(comment_body, 0, 8) == "বিবরণ:"
                doc_text = doc_trim(str_sub(comment_body, 8, c_body_len))
                if len(pending_summary) > 0 pending_summary = pending_summary + " " + doc_text
                else pending_summary = doc_text
            else
                // Top-level module banner capture
                if len(doc_file.overview) == 0 and c_body_len > 0 and char_at(comment_body, 0) != "=" and char_at(comment_body, 0) != "-"
                    doc_file.overview = comment_body

            l_idx = l_idx + 1
            continue

        // Case 2: Function definition (`fn name arg1 arg2` or `কাজ ...`)
        words = doc_split_words(trimmed)
        w_count = len(words)

        if w_count >= 2 and (get(words, 0) == "fn" or get(words, 0) == "কাজ")
            fn_name = get(words, 1)
            sym = DocSymbol()
            sym.kind = "fn"
            sym.name = fn_name
            sym.signature = trimmed
            sym.summary = pending_summary
            sym.why = pending_why
            sym.elements = list()

            p_i = 2
            while p_i < w_count
                push(sym.elements, get(words, p_i))
                p_i = p_i + 1

            push(doc_file.symbols, sym)
            pending_summary = ""
            pending_why = ""
            l_idx = l_idx + 1
            continue

        // Case 3: Struct definition (`struct Name` or `কাঠামো ...`)
        if w_count >= 2 and (get(words, 0) == "struct" or get(words, 0) == "কাঠামো" or get(words, 0) == "দল")
            struct_name = get(words, 1)
            sym = DocSymbol()
            sym.kind = "struct"
            sym.name = struct_name
            sym.signature = "struct " + struct_name
            sym.summary = pending_summary
            sym.why = pending_why
            sym.elements = list()

            // Collect fields until indentation ceases or empty line
            f_idx = l_idx + 1
            while f_idx < line_count
                f_line = get(lines, f_idx)
                f_trimmed = doc_trim(f_line)
                if len(f_trimmed) == 0 break
                if len(f_trimmed) >= 2 and str_sub(f_trimmed, 0, 2) == "//"
                    f_idx = f_idx + 1
                    continue
                f_words = doc_split_words(f_trimmed)
                if len(f_words) > 0
                    first_w = get(f_words, 0)
                    if first_w == "fn" or first_w == "struct" or first_w == "কাজ" or first_w == "কাঠামো"
                        break
                    push(sym.elements, first_w)
                f_idx = f_idx + 1

            push(doc_file.symbols, sym)
            pending_summary = ""
            pending_why = ""
            l_idx = f_idx
            continue

        // If line is non-empty code and not fn/struct, reset pending comments
        if tlen > 0
            pending_summary = ""
            pending_why = ""

        l_idx = l_idx + 1

    return doc_file

// ── 4. Markdown Generator ─────────────────────────────────────────────────────

// WHY: Converts parsed DocFile metadata into standardized GitHub-Flavored Markdown.
fn doc_generate_markdown doc_file
    out = "# 📖 Module `" + doc_file.module_name + "`\n\n"
    out = out + "> **Source:** [`" + doc_file.source_path + "`](" + doc_file.source_path + ")  \n"
    out = out + "> **Language:** LiPi Sovereign First 1.0.0 (Zero Libc / 100% Pure Native)\n\n"

    if len(doc_file.overview) > 0
        out = out + "## Overview\n\n"
        out = out + doc_file.overview + "\n\n"

    // ── Table of Contents ──
    symbols = doc_file.symbols
    s_count = len(symbols)
    if s_count > 0
        out = out + "## Table of Contents\n\n"
        i = 0
        while i < s_count
            sym = get(symbols, i)
            tag = "Function"
            if sym.kind == "struct" tag = "Struct"
            out = out + "- [" + tag + " `" + sym.name + "`](#" + sym.name + ")\n"
            i = i + 1
        out = out + "\n---\n\n"

    // ── Symbol Declarations ──
    out = out + "## API Reference\n\n"
    i = 0
    while i < s_count
        sym = get(symbols, i)
        out = out + "### `" + sym.name + "`\n\n"

        out = out + "```lipi\n" + sym.signature + "\n```\n\n"

        if len(sym.summary) > 0
            out = out + "**Description:** " + sym.summary + "\n\n"

        if len(sym.why) > 0
            out = out + "> [!NOTE]\n"
            out = out + "> **Architectural Rationale (WHY):**  \n"
            out = out + "> " + sym.why + "\n\n"

        // Elements breakdown (parameters or struct fields)
        elems = sym.elements
        e_count = len(elems)
        if e_count > 0
            if sym.kind == "struct"
                out = out + "**Struct Fields:**\n\n"
                out = out + "| Field Index | Field Name | Type / Semantics |\n"
                out = out + "| :--- | :--- | :--- |\n"
                e_i = 0
                while e_i < e_count
                    out = out + "| " + str(e_i) + " | `" + get(elems, e_i) + "` | Native 64-bit Word / Value |\n"
                    e_i = e_i + 1
                out = out + "\n"
            elif sym.kind == "fn"
                out = out + "**Parameters:**\n\n"
                out = out + "| Parameter Index | Argument Name |\n"
                out = out + "| :--- | :--- |\n"
                e_i = 0
                while e_i < e_count
                    out = out + "| " + str(e_i) + " | `" + get(elems, e_i) + "` |\n"
                    e_i = e_i + 1
                out = out + "\n"

        out = out + "---\n\n"
        i = i + 1

    return out

// ── 5. End-to-End File Processor ──────────────────────────────────────────────

// WHY: Reads .lp file, generates GFM documentation, and saves to output path.
fn doc_process_file source_path output_md_path
    if file_exists(source_path) == 0 return 0
    content = file_read(source_path)
    doc_file = doc_extract_from_text(content, source_path)
    md_content = doc_generate_markdown(doc_file)
    file_write(output_md_path, md_content)
    return 1
