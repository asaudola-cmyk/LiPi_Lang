// ==============================================================================
// 🎨 LIPI SOVEREIGN CODE FORMATTER (src/tools/lipifmt.lp)
// ⚡ 100% Pure Lipi First 1.0.0 Indentation Syntax | 0% Libc | 0% External Dependencies
// ==============================================================================

// WHY: Code formatting in a sovereign ecosystem must be deterministic, zero-dependency,
// and natively compiled. lipifmt enforces idiomatic Lipi First 1.0.0 styling: 4-space indentation,
// uniform operator spacing (e.g. 'a + b', 'x = 10', 'i == 0'), trailing whitespace removal,
// and normalization of consecutive blank lines.

include "utso/io"
include "utso/memory"

// ── 1. Helper Utilities ──────────────────────────────────────────────────────

// WHY: Sovereign silicon hardware boundary for direct kernel memory/file/process syscalls under --kavach.
fn silicon_mmap_buf size
    return syscall(9, 0, size, 3, 34, -1, 0)

fn silicon_munmap_buf ptr size
    return syscall(11, ptr, size, 0, 0, 0, 0)

fn silicon_open_ro path
    return syscall(2, path, 0, 0, 0, 0, 0)

fn silicon_open_trunc path
    return syscall(2, path, 577, 420, 0, 0, 0)

fn silicon_read_fd fd buf cap
    return syscall(0, fd, buf, cap, 0, 0, 0)

fn silicon_write_str fd s
    return syscall(1, fd, s, len(s), 0, 0, 0)

fn silicon_close_fd fd
    return syscall(3, fd, 0, 0, 0, 0, 0)

fn silicon_exit code
    return syscall(60, code, 0, 0, 0, 0, 0)

fn silicon_mem_byte_read ptr off
    return mem_byte_read(ptr, off)

// WHY: Allocates memory pages directly via kernel SYS_mmap for file buffer operations.
fn alloc_buf size
    return silicon_mmap_buf(size)

// WHY: Releases allocated memory pages via Linux SYS_munmap.
fn free_buf ptr size
    return silicon_munmap_buf(ptr, size)

// WHY: Checks if character is ASCII whitespace (space or tab).
fn is_space c
    if c == " " or c == "\t"
        return 1
    return 0

// WHY: Identifies operator characters for tokenizer boundary segmentation.
fn is_op_char c
    if c == "=" or c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "<" or c == ">" or c == "!" or c == "&" or c == "|" or c == "^" or c == "~"
        return 1
    return 0

// WHY: Identifies punctuation characters that require specific spacing rules.
fn is_punct c
    if c == "(" or c == ")" or c == "[" or c == "]" or c == "{" or c == "}" or c == "," or c == ":" or c == ";"
        return 1
    return 0

// WHY: Control flow keywords must have a space before parentheses (e.g. 'if (cond)').
fn is_keyword_before_paren w
    if w == "if" or w == "while" or w == "for" or w == "return" or w == "elif" or w == "say" or w == "@if" or w == "@while" or w == "@elif" or w == "যদি" or w == "যতক্ষণ" or w == "ফেরত" or w == "বলো"
        return 1
    return 0

// WHY: Binary operators require a single space on both left and right sides.
fn is_bin_op op
    if op == "=" or op == "==" or op == "!=" or op == "<=" or op == ">=" or op == "<" or op == ">" or op == "&&" or op == "||" or op == "&" or op == "|" or op == "^" or op == "<<" or op == ">>"
        return 1
    if op == "+" or op == "-" or op == "*" or op == "**" or op == "/" or op == "%" or op == "+=" or op == "-=" or op == "*=" or op == "/=" or op == "%=" or op == "->" or op == "=>" or op == "|>" or op == "and" or op == "or"
        return 1
    return 0

// WHY: Extracts substring [start, stop) without external string library dependencies.
fn str_sub s start stop
    slen = len(s)
    if start < 0
        start = 0
    end
    if stop > slen
        stop = slen
    end
    if start >= stop
        return ""
    end
    res = ""
    i = start
    while i < stop
        res = res + char_at(s, i)
        i = i + 1
    end
    return res

// WHY: Removes trailing whitespace and carriage returns from the end of a line.
fn trim_right s
    slen = len(s)
    if slen == 0
        return ""
    end
    last_idx = slen - 1
    while last_idx >= 0
        c = char_at(s, last_idx)
        if c == " " or c == "\t" or c == "\r" or c == "\n"
            last_idx = last_idx - 1
        else
            break
        end
    end
    if last_idx < 0
        return ""
    end
    res = ""
    i = 0
    while i <= last_idx
        res = res + char_at(s, i)
        i = i + 1
    end
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

// WHY: Finds start index of a line comment ('//'), skipping '//' inside escaped string literals.
fn find_comment_start s
    slen = len(s)
    in_quote = 0
    i = 0
    while i < slen
        c = char_at(s, i)
        if in_quote == 1 and c == "\\" and i + 1 < slen
            i = i + 2
            continue
        if c == "\""
            in_quote = 1 - in_quote
        elif in_quote == 0 and c == "/" and i + 1 < slen
            if char_at(s, i + 1) == "/"
                return i
        i = i + 1
    return -1

fn _fmt_is_digit ch
    o = ord(ch)
    if o >= 48 and o <= 57
        return 1
    return 0

fn _fmt_is_unary_prefix_ctx prev
    if prev == "" or prev == "=" or prev == "(" or prev == "[" or prev == "{" or prev == "," or prev == ":" or prev == "return" or prev == "ফেরত" or prev == "if" or prev == "@if" or prev == "while" or prev == "@while" or prev == "elif" or prev == "@elif" or is_bin_op(prev) == 1
        return 1
    return 0

// WHY: Tokenizes code into semantic units (strings with escapes, numbers incl. 1e-5/0x/0b/0o,
// compound multi-char operators, directives, and UTF-8 identifiers).
fn tokenize_code code
    tokens = list()
    clen = len(code)
    i = 0
    while i < clen
        c = char_at(code, i)
        if c == " " or c == "\t" or c == "\r" or c == "\n"
            i = i + 1
        elif c == "\""
            tok = "\""
            i = i + 1
            while i < clen
                sc = char_at(code, i)
                tok = tok + sc
                if sc == "\\" and i + 1 < clen
                    i = i + 1
                    tok = tok + char_at(code, i)
                elif sc == "\""
                    i = i + 1
                    break
                i = i + 1
            tokens = push(tokens, tok)
        elif c == "."
            if i + 1 < clen and char_at(code, i + 1) == "."
                tokens = push(tokens, "..")
                i = i + 2
            else
                tokens = push(tokens, ".")
                i = i + 1
        elif is_op_char(c)
            if i + 1 < clen
                c2 = char_at(code, i + 1)
                op2 = c + c2
                if op2 == "==" or op2 == "!=" or op2 == "<=" or op2 == ">=" or op2 == "&&" or op2 == "||" or op2 == "<<" or op2 == ">>" or op2 == "+=" or op2 == "-=" or op2 == "*=" or op2 == "/=" or op2 == "%=" or op2 == "->" or op2 == "=>" or op2 == "|>" or op2 == "**"
                    tokens = push(tokens, op2)
                    i = i + 2
                else
                    tokens = push(tokens, c)
                    i = i + 1
            else
                tokens = push(tokens, c)
                i = i + 1
        elif is_punct(c)
            tokens = push(tokens, c)
            i = i + 1
        elif _fmt_is_digit(c) == 1
            tok = ""
            saw_dot = 0
            saw_exp = 0
            while i < clen
                ch = char_at(code, i)
                if _fmt_is_digit(ch) == 1 or ch == "x" or ch == "X" or ch == "b" or ch == "B" or ch == "o" or ch == "O" or ch == "a" or ch == "A" or ch == "c" or ch == "C" or ch == "d" or ch == "D" or ch == "f" or ch == "F" or ch == "_"
                    tok = tok + ch
                    i = i + 1
                elif ch == "." and saw_dot == 0 and (i + 1 >= clen or char_at(code, i + 1) != ".")
                    saw_dot = 1
                    tok = tok + ch
                    i = i + 1
                elif (ch == "e" or ch == "E") and saw_exp == 0
                    saw_exp = 1
                    tok = tok + ch
                    i = i + 1
                    if i < clen and (char_at(code, i) == "+" or char_at(code, i) == "-")
                        tok = tok + char_at(code, i)
                        i = i + 1
                else
                    break
            tokens = push(tokens, tok)
        else
            tok = ""
            while i < clen
                ch = char_at(code, i)
                if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" or is_op_char(ch) or is_punct(ch) or ch == "\"" or ch == "."
                    break
                tok = tok + ch
                i = i + 1
            tokens = push(tokens, tok)
    return tokens

fn format_tokens tokens
    tlen = len(tokens)
    if tlen == 0
        return ""
    out = ""
    prev = ""
    pprev = ""
    i = 0
    while i < tlen
        tok = get(tokens, i)
        need_space = 1
        if i == 0
            need_space = 0
        elif tok == "," or tok == ";" or tok == ")" or tok == "]" or tok == ":"
            need_space = 0
        elif tok == "{"
            need_space = 1
            if prev == "(" or prev == "["
                need_space = 0
        elif tok == "(" or tok == "["
            if is_keyword_before_paren(prev) == 0 and prev != "" and is_bin_op(prev) == 0 and prev != "," and prev != "(" and prev != "[" and prev != "{" and prev != "=" and prev != "!" and prev != "~"
                need_space = 0
        elif prev == "(" or prev == "[" or prev == ".." or tok == ".."
            need_space = 0
        elif prev == "." or tok == "."
            need_space = 0
        elif prev == "!" or prev == "~"
            need_space = 0
        elif prev == "-" and _fmt_is_unary_prefix_ctx(pprev) == 1
            need_space = 0

        if need_space == 1
            out = out + " " + tok
        else
            out = out + tok
        pprev = prev
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
fn _fmt_is_block_opener trimmed
    if (starts_with(trimmed, "fn ") or starts_with(trimmed, "@fn ") or starts_with(trimmed, "কাজ ")) and contains(trimmed, "=") == 0
        return 1
    if starts_with(trimmed, "struct ") or starts_with(trimmed, "@struct ") or starts_with(trimmed, "গঠন ") or starts_with(trimmed, "কাঠামো ")
        return 1
    if starts_with(trimmed, "if ") or starts_with(trimmed, "@if ") or starts_with(trimmed, "যদি ") or starts_with(trimmed, "while ") or starts_with(trimmed, "@while ") or starts_with(trimmed, "যতক্ষণ ") or starts_with(trimmed, "for ") or starts_with(trimmed, "@for ") or starts_with(trimmed, "প্রতিটি ")
        return 1
    if trimmed == "else" or trimmed == "@else" or trimmed == "নাহলে" or starts_with(trimmed, "else ") or starts_with(trimmed, "@else ") or starts_with(trimmed, "elif ") or starts_with(trimmed, "@elif ") or starts_with(trimmed, "নাহলে_যদি ")
        return 1
    if len(trimmed) > 0 and char_at(trimmed, len(trimmed) - 1) == "{"
        return 1
    return 0

fn _fmt_is_block_closer trimmed
    if trimmed == "end" or trimmed == "@end" or trimmed == "শেষ" or trimmed == "}"
        return 1
    if starts_with(trimmed, "}")
        return 1
    return 0

fn _fmt_has_inline_closer trimmed
    if contains(trimmed, " @end") or contains(trimmed, " end") or contains(trimmed, " শেষ")
        return 1
    return 0

fn format_source_lines lines
    out_lines = list()
    total = len(lines)
    if total == 0
        return out_lines

    max_indent = 0
    has_explicit_end = 0
    li = 0
    while li < total
        l = get(lines, li)
        tl = trim_right(trim_left(l))
        if len(tl) > 0
            sp = count_leading_spaces(l)
            if sp > max_indent
                max_indent = sp
            if _fmt_is_block_closer(tl) == 1
                has_explicit_end = 1
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
            if max_indent > 0 and has_explicit_end == 0
                sp = count_leading_spaces(raw_l)
                top_sp = get(indent_stack, len(indent_stack) - 1)
                if sp > top_sp
                    indent_stack = push(indent_stack, sp)
                elif sp < top_sp
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
                if _fmt_is_block_closer(trimmed) == 1
                    if block_depth > 0
                        block_depth = block_depth - 1
                    level = block_depth
                elif trimmed == "else" or trimmed == "@else" or trimmed == "নাহলে" or starts_with(trimmed, "else ") or starts_with(trimmed, "@else ") or starts_with(trimmed, "elif ") or starts_with(trimmed, "@elif ") or starts_with(trimmed, "নাহলে_যদি ")
                    if block_depth > 0
                        level = block_depth - 1
                    else
                        level = 0
                    block_depth = level + 1
                else
                    level = block_depth
                    if _fmt_is_block_opener(trimmed) == 1 and _fmt_has_inline_closer(trimmed) == 0
                        block_depth = level + 1

            line_out = make_indent(level) + fmt_content
            out_lines = push(out_lines, line_out)

        li = li + 1

    return out_lines

// WHY: Reads raw lines from disk via crowned silicon_open_ro / silicon_read_fd primitives.
fn read_file_lines path
    fd = silicon_open_ro(path)
    if fd < 0
        return list()
    lines = list()
    buf = alloc_buf(4096)
    cur_line = ""
    while 1
        n = silicon_read_fd(fd, buf, 4096)
        if n <= 0
            break
        i = 0
        while i < n
            b = silicon_mem_byte_read(buf, i)
            if b == 10
                lines = push(lines, cur_line)
                cur_line = ""
            else
                if b != 13
                    cur_line = cur_line + chr(b)
            i = i + 1
    if len(cur_line) > 0
        lines = push(lines, cur_line)
    silicon_close_fd(fd)
    free_buf(buf, 4096)
    return lines

// WHY: Rewrites formatted lines to disk via crowned silicon_open_trunc / silicon_write_str primitives.
fn write_file_lines path lines
    fd = silicon_open_trunc(path)
    if fd < 0
        return 0
    total = len(lines)
    i = 0
    while i < total
        l = get(lines, i)
        silicon_write_str(fd, l)
        silicon_write_str(fd, "\n")
        i = i + 1
    silicon_close_fd(fd)
    return 1

// ── 4. CLI Driver & Entry Point ──────────────────────────────────────────────

fn print_banner
    // WHY: 72 visual columns (70 chars interior + 2 border chars).
    // Leaves safe 8-column margin on standard 80-column Linux terminal windows.
    say "\033[38;2;0;255;204m╔══════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m🎨 LIPIFMT — OFFICIAL SOVEREIGN CODE FORMATTER (First 1.0.0)\033[0m        \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ 100% Pure Lipi | 4-Space Indent | Operator Spacing | 0% Libc\033[0m     \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚══════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

fn print_usage
    print_banner()
    say "\033[1;33mUsage:\033[0m"
    say "  lipifmt [flags] <file.lp>"
    say ""
    say "\033[1;33mFlags:\033[0m"
    say "  \033[1;32m--check <file.lp>\033[0m       Check code formatting (0 = clean, 1 = reformatting needed)"
    say "  \033[1;32m-w, --write <file.lp>\033[0m   Format and overwrite source file in-place"
    say "  \033[1;32m<file.lp>\033[0m               Print formatted code directly to STDOUT"
    say "  \033[1;32m-h, --help\033[0m              Display this help information\n"

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        print_usage()
        return 0

    mode = 0 // 0=stdout, 1=check, 2=write
    target_path = ""
    ai = 1
    while ai < argc
        a = get(args, ai)
        if a == "-h" or a == "--help" or a == "help"
            print_usage()
            return 0
        elif a == "--check"
            mode = 1
        elif a == "-w" or a == "--write"
            mode = 2
        elif len(target_path) == 0
            target_path = a
        ai = ai + 1

    if len(target_path) == 0
        say "❌ Error: File path required."
        silicon_exit(1)

    raw_lines = read_file_lines(target_path)
    if len(raw_lines) == 0
        say "❌ Error: File not found or empty: " + target_path
        silicon_exit(1)

    formatted_lines = format_source_lines(raw_lines)

    if mode == 1
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
                    break
                ci = ci + 1
        if is_identical == 1
            say "✔ " + target_path + " is formatted properly."
            silicon_exit(0)
        else
            say "✗ " + target_path + " requires reformatting."
            silicon_exit(1)
        return 0

    if mode == 2
        write_ok = write_file_lines(target_path, formatted_lines)
        if write_ok == 1
            say "✔ " + target_path + " formatted and written successfully."
            return 0
        else
            say "❌ Error: Failed to write formatted file: " + target_path
            silicon_exit(1)
        return 0

    flen = len(formatted_lines)
    fi = 0
    while fi < flen
        say get(formatted_lines, fi)
        fi = fi + 1
    return 0

main()
