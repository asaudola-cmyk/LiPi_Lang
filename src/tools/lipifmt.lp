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

fn silicon_getpid
    return syscall(39, 0, 0, 0, 0, 0, 0)

fn silicon_rename old_path new_path
    return syscall(82, old_path, new_path, 0, 0, 0, 0)

fn silicon_unlink path
    return syscall(87, path, 0, 0, 0, 0, 0)

fn silicon_exit code
    return syscall(231, code, 0, 0, 0, 0, 0)

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

// WHY: Control flow, logic, and qualifier keywords must keep a space before '(' or '[' (e.g. 'if (cond)', 'for x in [1, 2]', 'not (x)', '&mut [1]').
fn is_keyword_before_paren w
    if w == "if" or w == "while" or w == "for" or w == "return" or w == "elif" or w == "say" or w == "@if" or w == "@while" or w == "@elif" or w == "যদি" or w == "যতক্ষণ" or w == "ফেরত" or w == "বলো"
        return 1
    if w == "in" or w == "not" or w == "mut" or w == "const" or w == "match" or w == "case" or w == "catch" or w == "defer" or w == "region" or w == "as" or w == "মধ্যে" or w == "নয়" or w == "মিল" or w == "ধরো"
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

// WHY: Finds start index of a line comment ('//', '#', or '@!'), skipping inside quotes and inline /* ... */ comments.
fn find_comment_start s
    slen = len(s)
    in_dquote = 0
    in_squote = 0
    in_block = 0
    i = 0
    while i < slen
        c = char_at(s, i)
        if in_block == 1
            if c == "*" and i + 1 < slen and char_at(s, i + 1) == "/"
                in_block = 0
                i = i + 2
                continue
            i = i + 1
            continue
        if in_dquote == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "\""
                in_dquote = 0
            i = i + 1
            continue
        if in_squote == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "'"
                in_squote = 0
            i = i + 1
            continue
        if c == "\""
            in_dquote = 1
        elif c == "'"
            in_squote = 1
        elif c == "/" and i + 1 < slen
            nc = char_at(s, i + 1)
            if nc == "/"
                return i
            elif nc == "*"
                in_block = 1
                i = i + 2
                continue
        elif c == "#"
            return i
        elif c == "@" and i + 1 < slen and char_at(s, i + 1) == "!"
            return i
        i = i + 1
    return -1

fn _fmt_is_digit ch
    o = ord(ch)
    if o >= 48 and o <= 57
        return 1
    return 0

fn _fmt_is_unary_prefix_ctx prev
    if prev == "" or prev == "=" or prev == "(" or prev == "[" or prev == "{" or prev == "," or prev == ":" or prev == "->" or prev == "=>" or prev == "return" or prev == "ফেরত" or prev == "if" or prev == "@if" or prev == "while" or prev == "@while" or prev == "elif" or prev == "@elif" or prev == "say" or prev == "বলো" or prev == "let" or prev == "@let" or is_bin_op(prev) == 1
        return 1
    return 0

fn _fmt_is_ident_like tok
    tlen = len(tok)
    if tlen == 0
        return 0
    c0 = char_at(tok, 0)
    if c0 == "\"" or c0 == "'" or _fmt_is_digit(c0) == 1 or is_op_char(c0) == 1 or is_punct(c0) == 1 or c0 == "." or c0 == "#"
        return 0
    if tok == "if" or tok == "@if" or tok == "elif" or tok == "@elif" or tok == "while" or tok == "@while" or tok == "for" or tok == "@for" or tok == "return" or tok == "ফেরত" or tok == "and" or tok == "or" or tok == "say" or tok == "বলো" or tok == "let" or tok == "@let" or tok == "in" or tok == "match" or tok == "case"
        return 0
    return 1

// WHY: Disambiguates generic type parameter brackets (`list<i64>`, `dict<string, i64>`, `fn f<T>(x: T)`)
// from relational `<` / `>` comparisons (`a < b`, `foo(a < b, c > d)`) by verifying balanced angle nesting,
// type-only interior tokens, and a valid post-generic follower token.
fn _fmt_find_generic_close tokens open_idx
    tlen = len(tokens)
    if open_idx <= 0 or open_idx + 2 > tlen
        return -1
    prev = get(tokens, open_idx - 1)
    if _fmt_is_ident_like(prev) == 0
        return -1
    is_decl_hdr = 0
    if open_idx >= 2
        pp = get(tokens, open_idx - 2)
        if pp == "fn" or pp == "@fn" or pp == "কাজ" or pp == "struct" or pp == "@struct" or pp == "enum" or pp == "trait" or pp == "impl" or pp == "union" or pp == "type"
            is_decl_hdr = 1
    depth = 1
    j = open_idx + 1
    while j < tlen
        tk = get(tokens, j)
        if tk == "<"
            depth = depth + 1
        elif tk == ">"
            depth = depth - 1
            if depth == 0
                if j + 1 >= tlen
                    return j
                nxt = get(tokens, j + 1)
                if nxt == "(" or nxt == ")" or nxt == "," or nxt == "]" or nxt == "}" or nxt == "{" or nxt == ":" or nxt == "::" or nxt == "." or nxt == "=" or nxt == "->" or nxt == "=>" or nxt == ">" or nxt == ">>" or nxt == ";"
                    return j
                if is_decl_hdr == 1
                    return j
                return -1
        elif tk == ">>"
            if depth == 1
                // WHY: Inner generic closed by first '>' of '>>' (e.g. list<dict<string, i64>>).
                return j
            if depth == 2
                if j + 1 >= tlen
                    return j
                nxt = get(tokens, j + 1)
                if nxt == "(" or nxt == ")" or nxt == "," or nxt == "]" or nxt == "}" or nxt == "{" or nxt == ":" or nxt == "::" or nxt == "." or nxt == "=" or nxt == "->" or nxt == "=>" or nxt == ">" or nxt == ">>" or nxt == ";"
                    return j
                if is_decl_hdr == 1
                    return j
                return -1
            depth = depth - 2
        elif tk == "=" or tk == "==" or tk == "!=" or tk == "<=" or tk == ">=" or tk == "+" or tk == "-" or tk == "/" or tk == "%" or tk == "and" or tk == "or" or tk == "&&" or tk == "||" or tk == "return" or tk == "if" or tk == "while" or tk == "for" or tk == "say" or tk == "let"
            return -1
        j = j + 1
    return -1

// WHY: Tokenizes code into semantic units (double/single-quoted strings with escapes,
// inline /* ... */ block comments, numbers incl. 1e-5/0x/0b/0o, `..=`, `::`,
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
        elif c == "'"
            // WHY: Preserves single-quoted character/string literals verbatim including escaped quotes.
            tok = "'"
            i = i + 1
            while i < clen
                sc = char_at(code, i)
                tok = tok + sc
                if sc == "\\" and i + 1 < clen
                    i = i + 1
                    tok = tok + char_at(code, i)
                elif sc == "'"
                    i = i + 1
                    break
                i = i + 1
            tokens = push(tokens, tok)
        elif c == "/" and i + 1 < clen and char_at(code, i + 1) == "*"
            // WHY: Keeps inline /* ... */ block comments intact as a single opaque token.
            tok = "/*"
            i = i + 2
            while i < clen
                sc = char_at(code, i)
                if sc == "*" and i + 1 < clen and char_at(code, i + 1) == "/"
                    tok = tok + "*/"
                    i = i + 2
                    break
                tok = tok + sc
                i = i + 1
            tokens = push(tokens, tok)
        elif c == ":" and i + 1 < clen and char_at(code, i + 1) == ":"
            tokens = push(tokens, "::")
            i = i + 2
        elif c == "."
            if i + 2 < clen and char_at(code, i + 1) == "." and char_at(code, i + 2) == "="
                tokens = push(tokens, "..=")
                i = i + 3
            elif i + 1 < clen and char_at(code, i + 1) == "."
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
            is_hex = 0
            while i < clen
                ch = char_at(code, i)
                if ch == "x" or ch == "X"
                    is_hex = 1
                    tok = tok + ch
                    i = i + 1
                elif _fmt_is_digit(ch) == 1 or ch == "b" or ch == "B" or ch == "o" or ch == "O" or ch == "a" or ch == "A" or ch == "c" or ch == "C" or ch == "d" or ch == "D" or ch == "f" or ch == "F" or ch == "_"
                    tok = tok + ch
                    i = i + 1
                elif is_hex == 1 and (ch == "e" or ch == "E")
                    // WHY: Inside 0x... hex literals, 'e'/'E' is a hex digit, never scientific exponent (so 0x1e-1 stays 0x1e - 1).
                    tok = tok + ch
                    i = i + 1
                elif ch == "." and is_hex == 0 and saw_dot == 0 and (i + 1 >= clen or char_at(code, i + 1) != ".")
                    saw_dot = 1
                    tok = tok + ch
                    i = i + 1
                elif is_hex == 0 and (ch == "e" or ch == "E") and saw_exp == 0
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
                if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" or is_op_char(ch) or is_punct(ch) or ch == "\"" or ch == "'" or ch == "."
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
    generic_depth = 0
    prev_was_generic_open = 0
    prev_was_generic_close = 0
    i = 0
    while i < tlen
        tok = get(tokens, i)
        need_space = 1
        cur_generic_open = 0
        cur_generic_close = 0

        if tok == "<" and _fmt_find_generic_close(tokens, i) >= 0
            cur_generic_open = 1
            generic_depth = generic_depth + 1
        elif tok == ">" and generic_depth > 0
            cur_generic_close = 1
            generic_depth = generic_depth - 1
        elif tok == ">>" and generic_depth >= 2
            cur_generic_close = 1
            generic_depth = generic_depth - 2

        if i == 0
            need_space = 0
        elif cur_generic_open == 1 or cur_generic_close == 1 or prev_was_generic_open == 1
            need_space = 0
        elif tok == "," or tok == ";" or tok == ")" or tok == "]" or tok == ":"
            need_space = 0
        elif tok == "::" or prev == "::"
            need_space = 0
        elif tok == "{"
            need_space = 1
            if prev == "(" or prev == "["
                need_space = 0
        elif tok == "(" or tok == "["
            if prev_was_generic_close == 1
                need_space = 0
            elif is_keyword_before_paren(prev) == 0 and prev != "" and is_bin_op(prev) == 0 and prev != "," and prev != "(" and prev != "[" and prev != "{" and prev != "=" and prev != "!" and prev != "~"
                need_space = 0
        elif prev == "(" or prev == "[" or prev == ".." or tok == ".." or prev == "..=" or tok == "..="
            need_space = 0
        elif prev == "." or tok == "."
            need_space = 0
        elif prev == "!" or prev == "~"
            need_space = 0
        elif (prev == "-" or prev == "*" or prev == "&") and (_fmt_is_unary_prefix_ctx(pprev) == 1 or prev_was_generic_open == 1)
            // WHY: Preserves unary negation (-x), pointer types (*mut u8 / *const u8), deref (*p),
            // and borrow prefixes (&x / &mut x) without injecting spurious spaces.
            need_space = 0

        if need_space == 1
            out = out + " " + tok
        else
            out = out + tok
        pprev = prev
        prev = tok
        prev_was_generic_open = cur_generic_open
        prev_was_generic_close = cur_generic_close
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
// WHY: Returns 1 only when '=' appears at top-level (paren/bracket/brace depth 0, outside quotes & comments)
// so single-line expression functions (`fn ver = "1.0"`) are distinguished from default params (`fn foo(x = 1) // a = b`).
fn _fmt_has_top_level_eq s
    cidx = find_comment_start(s)
    code_s = s
    if cidx >= 0
        code_s = str_sub(s, 0, cidx)
    slen = len(code_s)
    pdepth = 0
    in_dq = 0
    in_sq = 0
    in_blk = 0
    i = 0
    while i < slen
        c = char_at(code_s, i)
        if in_blk == 1
            if c == "*" and i + 1 < slen and char_at(code_s, i + 1) == "/"
                in_blk = 0
                i = i + 2
                continue
            i = i + 1
            continue
        if in_dq == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "\""
                in_dq = 0
            i = i + 1
            continue
        if in_sq == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "'"
                in_sq = 0
            i = i + 1
            continue
        if c == "\""
            in_dq = 1
        elif c == "'"
            in_sq = 1
        elif c == "/" and i + 1 < slen and char_at(code_s, i + 1) == "*"
            in_blk = 1
            i = i + 2
            continue
        elif c == "(" or c == "[" or c == "{"
            pdepth = pdepth + 1
        elif c == ")" or c == "]" or c == "}"
            if pdepth > 0
                pdepth = pdepth - 1
        elif c == "=" and pdepth == 0
            prev_c = ""
            next_c = ""
            if i > 0 prev_c = char_at(code_s, i - 1)
            if i + 1 < slen next_c = char_at(code_s, i + 1)
            if prev_c != "=" and prev_c != "!" and prev_c != "<" and prev_c != ">" and next_c != "=" and next_c != ">"
                return 1
        i = i + 1
    return 0

// WHY: Counts net unclosed block comments ('/*' opened vs '*/' closed) on a single line.
fn _fmt_update_block_comment_state line in_blk
    slen = len(line)
    in_dq = 0
    in_sq = 0
    st = in_blk
    i = 0
    while i < slen
        c = char_at(line, i)
        if st == 1
            if c == "*" and i + 1 < slen and char_at(line, i + 1) == "/"
                st = 0
                i = i + 2
                continue
            i = i + 1
            continue
        if in_dq == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "\""
                in_dq = 0
            i = i + 1
            continue
        if in_sq == 1
            if c == "\\" and i + 1 < slen
                i = i + 2
                continue
            if c == "'"
                in_sq = 0
            i = i + 1
            continue
        if c == "\""
            in_dq = 1
        elif c == "'"
            in_sq = 1
        elif c == "/" and i + 1 < slen
            nc = char_at(line, i + 1)
            if nc == "/"
                break
            elif nc == "*"
                st = 1
                i = i + 2
                continue
        elif c == "#"
            break
        elif c == "@" and i + 1 < slen and char_at(line, i + 1) == "!"
            break
        i = i + 1
    return st

fn _fmt_is_block_opener trimmed
    // WHY: Strips trailing line comments and optional `pub ` / `async ` modifiers so comments
    // ending with '{' never open bogus blocks, while recognizing all Lipi block openers.
    cidx = find_comment_start(trimmed)
    code_part = trimmed
    if cidx >= 0
        code_part = trim_right(str_sub(trimmed, 0, cidx))
    if len(code_part) == 0 or starts_with(code_part, "/*")
        return 0
    head = code_part
    if starts_with(head, "pub ")
        head = trim_left(str_sub(head, 4, len(head)))
    if starts_with(head, "async ")
        head = trim_left(str_sub(head, 6, len(head)))
    if (starts_with(head, "fn ") or starts_with(head, "@fn ") or starts_with(head, "কাজ ")) and _fmt_has_top_level_eq(head) == 0
        return 1
    if starts_with(head, "struct ") or starts_with(head, "@struct ") or starts_with(head, "গঠন ") or starts_with(head, "কাঠামো ")
        return 1
    if starts_with(head, "enum ") or starts_with(head, "@enum ") or starts_with(head, "union ") or starts_with(head, "@union ") or starts_with(head, "trait ") or starts_with(head, "@trait ") or starts_with(head, "impl ") or starts_with(head, "@impl ")
        return 1
    if starts_with(head, "match ") or starts_with(head, "@match ") or starts_with(head, "মিল ") or starts_with(head, "region ") or starts_with(head, "@region ") or starts_with(head, "defer ") or head == "defer"
        return 1
    if head == "try" or starts_with(head, "try ") or head == "catch" or starts_with(head, "catch ") or head == "চেষ্টা" or starts_with(head, "ধরো ")
        return 1
    if starts_with(head, "if ") or starts_with(head, "@if ") or starts_with(head, "যদি ") or starts_with(head, "while ") or starts_with(head, "@while ") or starts_with(head, "যতক্ষণ ") or starts_with(head, "for ") or starts_with(head, "@for ") or starts_with(head, "প্রতিটি ")
        return 1
    if head == "else" or head == "@else" or head == "নাহলে" or starts_with(head, "else ") or starts_with(head, "@else ") or starts_with(head, "elif ") or starts_with(head, "@elif ") or starts_with(head, "নাহলে_যদি ")
        return 1
    if len(code_part) > 0 and char_at(code_part, len(code_part) - 1) == "{"
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
    // WHY: Inline brace expression/block like `d = { "k": 1 }` or `fn f() { return 1 }` closes itself on the same line.
    if contains(trimmed, "{") == 1 and contains(trimmed, "}") == 1 and char_at(trimmed, len(trimmed) - 1) != "{"
        return 1
    return 0

fn format_source_lines lines
    out_lines = list()
    total = len(lines)
    if total == 0
        return out_lines

    // WHY: Detect whether the source already uses structural indentation (max_indent > 0).
    // Preserving the source indent stack whenever max_indent > 0 ensures mixed brace expressions
    // (`{ ... }`) or partial `end` markers never corrupt indentation of surrounding indented blocks!
    // Only flat unindented files (max_indent == 0) synthesize indentation purely from block_depth.
    max_indent = 0
    li = 0
    while li < total
        l = get(lines, li)
        tl = trim_right(trim_left(l))
        if len(tl) > 0
            sp = count_leading_spaces(l)
            if sp > max_indent
                max_indent = sp
        li = li + 1

    indent_stack = list()
    indent_stack = push(indent_stack, 0)
    consecutive_blank = 0
    block_depth = 0
    in_block_comment = 0

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
            was_in_block_comment = in_block_comment
            fmt_content = ""
            if in_block_comment == 1
                fmt_content = trimmed
                in_block_comment = _fmt_update_block_comment_state(trimmed, 1)
            else
                if starts_with(trimmed, "/*") and contains(trimmed, "*/") == 0
                    fmt_content = trimmed
                    in_block_comment = 1
                else
                    fmt_content = format_line_content(trimmed)
                    in_block_comment = _fmt_update_block_comment_state(trimmed, 0)

            level = 0
            if max_indent > 0
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
                    // WHY: Preserve intermediate non-zero dedent levels (e.g. 0->4->2) instead of collapsing to col 0.
                    if sp > get(indent_stack, len(indent_stack) - 1)
                        indent_stack = push(indent_stack, sp)
                level = len(indent_stack) - 1
            else
                if was_in_block_comment == 1
                    level = block_depth
                elif _fmt_is_block_closer(trimmed) == 1
                    if block_depth > 0
                        block_depth = block_depth - 1
                    level = block_depth
                    if len(trimmed) > 1 and char_at(trimmed, len(trimmed) - 1) == "{"
                        block_depth = level + 1
                elif trimmed == "else" or trimmed == "@else" or trimmed == "নাহলে" or starts_with(trimmed, "else ") or starts_with(trimmed, "@else ") or starts_with(trimmed, "elif ") or starts_with(trimmed, "@elif ") or starts_with(trimmed, "নাহলে_যদি ") or trimmed == "catch" or starts_with(trimmed, "catch ") or starts_with(trimmed, "ধরো ")
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

// WHY: Reads raw lines from disk in O(N) time using a single reused ERMS ByteBuffer
// (eliminating quadratic per-character string reallocation) and crowned silicon_* syscalls.
fn read_file_lines path
    fd = silicon_open_ro(path)
    if fd < 0
        return list()
    lines = list()
    buf = alloc_buf(4096)
    line_bb = buf_new(256)
    while 1
        n = silicon_read_fd(fd, buf, 4096)
        if n <= 0
            break
        i = 0
        while i < n
            b = silicon_mem_byte_read(buf, i)
            if b == 10
                lines = push(lines, buf_to_str(line_bb))
                buf_clear(line_bb)
            else
                if b != 13
                    buf_write_byte(line_bb, b)
            i = i + 1
    if buf_len(line_bb) > 0
        lines = push(lines, buf_to_str(line_bb))
    buf_free(line_bb)
    silicon_close_fd(fd)
    free_buf(buf, 4096)
    return lines

// WHY: Writes formatted lines atomically via a PID-scoped sibling temp file + SYS_rename (82)
// so crashes or interrupted writes can never leave the target source file truncated or corrupted.
fn write_file_lines path lines
    tmp_path = path + ".lipifmt.tmp." + str(silicon_getpid())
    fd = silicon_open_trunc(tmp_path)
    if fd < 0
        return 0
    out_bb = buf_new(4096)
    total = len(lines)
    i = 0
    while i < total
        buf_write_str(out_bb, get(lines, i))
        buf_write_byte(out_bb, 10)
        i = i + 1
    payload = buf_to_str(out_bb)
    buf_free(out_bb)
    plen = len(payload)
    written = 0
    write_err = 0
    while written < plen
        rem_s = payload
        if written > 0
            rem_s = str_sub(payload, written, plen)
        nw = silicon_write_str(fd, rem_s)
        if nw <= 0
            write_err = 1
            break
        written = written + nw
    silicon_close_fd(fd)
    if write_err == 1
        silicon_unlink(tmp_path)
        return 0
    r_rc = silicon_rename(tmp_path, path)
    if r_rc < 0
        silicon_unlink(tmp_path)
        return 0
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
