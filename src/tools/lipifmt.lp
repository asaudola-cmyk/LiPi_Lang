// ==============================================================================
// 🎨 LIPI SOVEREIGN CODE FORMATTER (src/tools/lipifmt.lp)
// ⚡ 100% Pure Lipi 2.0 Indentation Syntax | 0% Libc | 0% External Dependencies
// ==============================================================================

// WHY: Code formatting in a sovereign ecosystem must be deterministic, zero-dependency,
// and natively compiled. lipifmt enforces idiomatic Lipi 2.0 styling: 4-space indentation,
// uniform operator spacing (e.g. 'a + b', 'x = 10', 'i == 0'), trailing whitespace removal,
// and normalization of consecutive blank lines.

include "universe/core/io.lp"
include "universe/core/memory.lp"

// ── 1. Helper Utilities ──────────────────────────────────────────────────────

// WHY: Allocates memory pages directly via kernel SYS_mmap for file buffer operations.
fn alloc_buf size
    return syscall(9, 0, size, 3, 34, -1, 0)

// WHY: Releases allocated memory pages via Linux SYS_munmap.
fn free_buf ptr size
    return syscall(11, ptr, size, 0, 0, 0, 0)

// WHY: Checks if character is ASCII whitespace (space or tab).
fn is_space c
    if c == " " or c == "\t"
        return 1
    return 0

// WHY: Identifies operator characters for tokenizer boundary segmentation.
fn is_op_char c
    if c == "=" or c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "<" or c == ">" or c == "!"
        return 1
    return 0

// WHY: Identifies punctuation characters that require specific spacing rules.
fn is_punct c
    if c == "(" or c == ")" or c == "[" or c == "]" or c == "," or c == ":" or c == ";"
        return 1
    return 0

// WHY: Control flow keywords must have a space before parentheses (e.g. 'if (cond)').
fn is_keyword_before_paren w
    if w == "if" or w == "while" or w == "return" or w == "elif" or w == "say"
        return 1
    return 0

// WHY: Binary operators require a single space on both left and right sides.
fn is_bin_op op
    if op == "=" or op == "==" or op == "!=" or op == "<=" or op == ">=" or op == "<" or op == ">"
        return 1
    if op == "+" or op == "-" or op == "*" or op == "/" or op == "%" or op == "+=" or op == "-=" or op == "*=" or op == "/=" or op == "->"
        return 1
    return 0

// WHY: Extracts substring [start, end) without external string library dependencies.
fn str_sub s start end
    slen = len(s)
    if start < 0
        start = 0
    if end > slen
        end = slen
    if start >= end
        return ""
    res = ""
    i = start
    while i < end
        res = res + char_at(s, i)
        i = i + 1
    return res

// WHY: Removes trailing whitespace and carriage returns from the end of a line.
fn trim_right s
    slen = len(s)
    if slen == 0
        return ""
    end = slen - 1
    while end >= 0
        c = char_at(s, end)
        if c == " " or c == "\t" or c == "\r" or c == "\n"
            end = end - 1
        else
            break
    if end < 0
        return ""
    res = ""
    i = 0
    while i <= end
        res = res + char_at(s, i)
        i = i + 1
    return res

// WHY: Strips leading indentation whitespace to isolate code content.
fn trim_left s
    slen = len(s)
    if slen == 0
        return ""
    start = 0
    while start < slen
        c = char_at(s, start)
        if c == " " or c == "\t"
            start = start + 1
        else
            break
    res = ""
    i = start
    while i < slen
        res = res + char_at(s, i)
        i = i + 1
    return res

// WHY: Computes effective indentation width (converting tab characters to 4 spaces).
fn count_leading_spaces s
    slen = len(s)
    i = 0
    count = 0
    while i < slen
        c = char_at(s, i)
        if c == " "
            count = count + 1
        else
            if c == "\t"
                count = count + 4
            else
                break
        i = i + 1
    return count

// WHY: Constructs exact 4-space indentation prefix according to the nesting level.
fn make_indent level
    res = ""
    i = 0
    while i < level
        res = res + "    "
        i = i + 1
    return res

// WHY: Checks if string begins with prefix.
fn starts_with s prefix
    slen = len(s)
    plen = len(prefix)
    if plen > slen
        return 0
    i = 0
    while i < plen
        if char_at(s, i) != char_at(prefix, i)
            return 0
        i = i + 1
    return 1

// WHY: Checks if string contains substring.
fn contains s sub
    slen = len(sub)
    if slen == 0
        return 1
    tlen = len(s)
    if slen > tlen
        return 0
    limit = tlen - slen
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < slen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                j = slen
            else
                j = j + 1
        if match == 1
            return 1
        i = i + 1
    return 0

// ── 2. Tokenizer & Code Formatter ─────────────────────────────────────────────

// WHY: Finds start index of a line comment ('//'), skipping '//' inside string literals.
fn find_comment_start s
    slen = len(s)
    in_quote = 0
    i = 0
    while i < slen
        c = char_at(s, i)
        if c == "\""
            in_quote = 1 - in_quote
        else
            if in_quote == 0 and c == "/" and i + 1 < slen
                if char_at(s, i + 1) == "/"
                    return i
        i = i + 1
    return -1

// WHY: Tokenizes code into semantic units (literals, operators, words, punctuation)
// while strictly preserving string contents and multi-character operators intact.
fn tokenize_code code
    tokens = list()
    clen = len(code)
    i = 0
    while i < clen
        c = char_at(code, i)
        if c == " " or c == "\t" or c == "\r" or c == "\n"
            i = i + 1
        else
            if c == "\""
                // String literal: preserve character sequence including escapes
                tok = "\""
                i = i + 1
                while i < clen
                    sc = char_at(code, i)
                    tok = tok + sc
                    if sc == "\""
                        i = i + 1
                        break
                    if sc == "\\" and i + 1 < clen
                        i = i + 1
                        tok = tok + char_at(code, i)
                    i = i + 1
                tokens = push(tokens, tok)
            else
                if c == "."
                    tokens = push(tokens, ".")
                    i = i + 1
                else
                    if is_op_char(c)
                        // Compound 2-character operators
                        if i + 1 < clen
                            c2 = char_at(code, i + 1)
                            op2 = c + c2
                            if op2 == "==" or op2 == "!=" or op2 == "<=" or op2 == ">=" or op2 == "+=" or op2 == "-=" or op2 == "*=" or op2 == "/=" or op2 == "->"
                                tokens = push(tokens, op2)
                                i = i + 2
                            else
                                tokens = push(tokens, c)
                                i = i + 1
                        else
                            tokens = push(tokens, c)
                            i = i + 1
                    else
                        if is_punct(c)
                            tokens = push(tokens, c)
                            i = i + 1
                        else
                            // Word / identifier / number
                            tok = ""
                            while i < clen
                                ch = char_at(code, i)
                                if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" or is_op_char(ch) or is_punct(ch) or ch == "\"" or ch == "."
                                    break
                                tok = tok + ch
                                i = i + 1
                            tokens = push(tokens, tok)
    return tokens

// WHY: Assembles token sequence into idiomatic Lipi code with standardized spacing:
// - 1 space around binary operators ('a + b', 'x = 10', 'i == 0')
// - 1 space after commas (', ')
// - Tight bindings on function calls ('foo(x)') and property accesses ('pt.x')
// - Tight binding on unary negative numbers ('-1')
fn format_tokens tokens
    tlen = len(tokens)
    if tlen == 0
        return ""
    out = ""
    prev = ""
    i = 0
    while i < tlen
        tok = get(tokens, i)
        need_space = 1
        if i == 0
            need_space = 0
        else
            if tok == "," or tok == ";" or tok == ")" or tok == "]"
                need_space = 0
            else
                if tok == "(" or tok == "["
                    if is_keyword_before_paren(prev) == 0 and prev != "" and is_bin_op(prev) == 0 and prev != "," and prev != "(" and prev != "[" and prev != "="
                        need_space = 0
                else
                    if prev == "(" or prev == "["
                        need_space = 0
                    else
                        if prev == "." or tok == "."
                            need_space = 0
                        else
                            if prev == "-" and i >= 2
                                pprev = get(tokens, i - 2)
                                if pprev == "=" or pprev == "(" or pprev == "[" or pprev == "," or is_bin_op(pprev)
                                    need_space = 0
                            else
                                if prev == "-" and i == 1
                                    need_space = 0

        if need_space == 1
            out = out + " " + tok
        else
            out = out + tok
        prev = tok
        i = i + 1
    return out

// WHY: Processes a single line: extracts comments, formats code expressions,
// and reattaches comments with clean single-space separation.
fn format_line_content line
    tline = trim_left(line)
    if len(tline) == 0
        return ""
    cidx = find_comment_start(tline)
    if cidx == 0
        return trim_right(tline)
    if cidx > 0
        code_part = trim_right(str_sub(tline, 0, cidx))
        comm_part = str_sub(tline, cidx, len(tline))
        toks = tokenize_code(code_part)
        fmt_code = format_tokens(toks)
        return fmt_code + " " + comm_part
    toks = tokenize_code(tline)
    return format_tokens(toks)

// ── 3. File & Source Formatter Pipeline ────────────────────────────────────────

// WHY: Formats an entire list of source lines:
// 1. Enforces 4-space indentation per nesting level.
// 2. Normalizes consecutive blank lines to maximum 2 blank lines.
// 3. Removes trailing whitespace on all lines.
fn format_source_lines lines
    out_lines = list()
    total = len(lines)
    if total == 0
        return out_lines

    // Determine if the file possesses existing indentation
    max_indent = 0
    li = 0
    while li < total
        l = get(lines, li)
        tl = trim_left(l)
        if len(tl) > 0
            sp = count_leading_spaces(l)
            if sp > max_indent
                max_indent = sp
        li = li + 1

    indent_stack = list()
    indent_stack = push(indent_stack, 0)
    consecutive_blank = 0
    block_depth = 0

    li = 0
    while li < total
        raw_l = get(lines, li)
        trimmed = trim_right(trim_left(raw_l))
        
        if len(trimmed) == 0
            consecutive_blank = consecutive_blank + 1
            if consecutive_blank <= 2
                out_lines = push(out_lines, "")
        else
            consecutive_blank = 0
            fmt_content = format_line_content(trimmed)
            
            level = 0
            if max_indent > 0
                // Indented file: map indentation hierarchy to 4-space standard
                sp = count_leading_spaces(raw_l)
                top_sp = get(indent_stack, len(indent_stack) - 1)
                if sp > top_sp
                    indent_stack = push(indent_stack, sp)
                else
                    if sp < top_sp
                        while len(indent_stack) > 1 and sp < get(indent_stack, len(indent_stack) - 1)
                            nstack = list()
                            ni = 0
                            nlen = len(indent_stack) - 1
                            while ni < nlen
                                nstack = push(nstack, get(indent_stack, ni))
                                ni = ni + 1
                            indent_stack = nstack
                level = len(indent_stack) - 1
            else
                // Flat file: deduce block depth from syntax keywords
                if starts_with(trimmed, "else") or starts_with(trimmed, "elif ")
                    if block_depth > 0
                        level = block_depth - 1
                    else
                        level = 0
                else
                    level = block_depth

                if (starts_with(trimmed, "fn ") and contains(trimmed, "=") == 0) or starts_with(trimmed, "struct ") or starts_with(trimmed, "if ") or starts_with(trimmed, "while ") or starts_with(trimmed, "for ") or starts_with(trimmed, "else") or starts_with(trimmed, "elif ")
                    block_depth = level + 1
                else
                    if starts_with(trimmed, "return")
                        if block_depth > 1
                            block_depth = block_depth - 1

            line_out = make_indent(level) + fmt_content
            out_lines = push(out_lines, line_out)

        li = li + 1

    return out_lines

// WHY: Reads raw lines from disk via direct Linux kernel syscall 0 (SYS_read).
fn read_file_lines path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return list()
    lines = list()
    buf = alloc_buf(4096)
    cur_line = ""
    while 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0
            break
        i = 0
        while i < n
            b = mem_byte_read(buf, i)
            if b == 10
                lines = push(lines, cur_line)
                cur_line = ""
            else
                if b != 13
                    cur_line = cur_line + chr(b)
            i = i + 1
    if len(cur_line) > 0
        lines = push(lines, cur_line)
    syscall(3, fd, 0, 0, 0, 0, 0)
    free_buf(buf, 4096)
    return lines

// WHY: Rewrites formatted lines to disk via Linux kernel syscall 1 (SYS_write).
fn write_file_lines path lines
    fd = syscall(2, path, 577, 420, 0, 0, 0) // O_WRONLY | O_CREAT | O_TRUNC
    if fd < 0
        return 0
    total = len(lines)
    i = 0
    while i < total
        l = get(lines, i)
        syscall(1, fd, l, len(l), 0, 0, 0)
        syscall(1, fd, "\n", 1, 0, 0, 0)
        i = i + 1
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 1

// ── 4. CLI Driver & Entry Point ──────────────────────────────────────────────

fn print_banner
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m🎨 LIPIFMT — OFFICIAL SOVEREIGN CODE FORMATTER (v2.0.0)\033[0m               \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ 100% Pure Lipi | 4-Space Indent | Operator Spacing | 0% Libc\033[0m       \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n"

fn print_usage
    print_banner()
    say "\033[1;33mব্যবহার (Usage):\033[0m"
    say "  lipifmt [flags] <file.lp>"
    say ""
    say "\033[1;33mবিকল্পসমূহ (Flags):\033[0m"
    say "  \033[1;32m--check <file.lp>\033[0m       ফরম্যাটিং পরীক্ষা করুন (০ = সঠিক, ১ = পরিবর্তন প্রয়োজন)"
    say "  \033[1;32m-w, --write <file.lp>\033[0m   ফাইলটিতে সরাসরি ফরম্যাটকৃত কোড প্রতিস্থাপন করুন"
    say "  \033[1;32m<file.lp>\033[0m               ফরম্যাটকৃত কোড সরাসরি STDOUT-এ প্রিন্ট করুন"
    say "  \033[1;32m-h, --help\033[0m              এই সহায়তা বার্তা প্রদর্শন\n"

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        print_usage()
        return 0

    arg1 = get(args, 1)

    if arg1 == "-h" or arg1 == "--help" or arg1 == "help"
        print_usage()
        return 0

    // Mode 1: --check <file.lp>
    if arg1 == "--check"
        if argc < 3
            say "❌ ত্রুটি: ফাইলের পাথ প্রদান করুন: lipifmt --check <file.lp>"
            syscall(60, 1, 0, 0, 0, 0, 0)
        target_path = get(args, 2)
        raw_lines = read_file_lines(target_path)
        if len(raw_lines) == 0
            say "❌ ত্রুটি: ফাইল পড়তে ব্যর্থ বা ফাইলটি শূন্য: " + target_path
            syscall(60, 1, 0, 0, 0, 0, 0)

        formatted_lines = format_source_lines(raw_lines)
        rlen = len(raw_lines)
        flen = len(formatted_lines)
        
        is_identical = 1
        if rlen != flen
            is_identical = 0
        else
            ci = 0
            while ci < rlen
                if get(raw_lines, ci) != get(formatted_lines, ci)
                    is_identical = 0
                    ci = rlen
                else
                    ci = ci + 1

        if is_identical == 1
            say "✓ " + target_path + " ইতিমধ্যে যথাযথভাবে ফরম্যাট করা আছে।"
            syscall(60, 0, 0, 0, 0, 0, 0)
        else
            say "✗ " + target_path + " ফরম্যাটিং প্রয়োজন।"
            syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    // Mode 2: -w or --write <file.lp>
    if arg1 == "-w" or arg1 == "--write"
        if argc < 3
            say "❌ ত্রুটি: ফাইলের পাথ প্রদান করুন: lipifmt -w <file.lp>"
            syscall(60, 1, 0, 0, 0, 0, 0)
        target_path = get(args, 2)
        raw_lines = read_file_lines(target_path)
        if len(raw_lines) == 0
            say "❌ ত্রুটি: ফাইল পাওয়া যায়নি: " + target_path
            syscall(60, 1, 0, 0, 0, 0, 0)

        formatted_lines = format_source_lines(raw_lines)
        write_ok = write_file_lines(target_path, formatted_lines)
        if write_ok == 1
            say "✓ " + target_path + " সফলভাবে ফরম্যাট ও সংরক্ষণ করা হয়েছে।"
            return 0
        else
            say "❌ ত্রুটি: ফাইলে লিখতে ব্যর্থ: " + target_path
            syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    // Mode 3: Default stdout format
    target_path = arg1
    raw_lines = read_file_lines(target_path)
    if len(raw_lines) == 0
        say "❌ ত্রুটি: ফাইল পাওয়া যায়নি বা পড়তে ব্যর্থ: " + target_path
        syscall(60, 1, 0, 0, 0, 0, 0)

    formatted_lines = format_source_lines(raw_lines)
    flen = len(formatted_lines)
    fi = 0
    while fi < flen
        say get(formatted_lines, fi)
        fi = fi + 1
    return 0

main()
