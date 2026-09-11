// ==============================================================================
// 📖 LIPI SOVEREIGN DOCUMENTATION GENERATOR (src/tools/lipidoc.lp)
// ⚡ 100% Pure Lipi 2.0 Indentation Syntax | 0% Libc | 0% External Dependencies
// ==============================================================================

// WHY: A sovereign language ecosystem requires self-documenting codebases. lipidoc
// inspects Lipi source files (.lp), extracts 'struct' definitions, 'fn' signatures,
// and doc comments ('// Doc:', '// WHY:', '// বিবরণ:', '// কেন:'), and automatically
// renders clean, standardized GitHub-Flavored Markdown documentation.

include "universe/core/io.lp"
include "universe/core/memory.lp"

// ── 1. Data Structures ───────────────────────────────────────────────────────

// WHY: Encapsulates documented symbols extracted from source code.
struct DocItem
    kind       // "struct" or "fn"
    name       // Identifier name
    sig        // Function signature or field summary
    doc        // Descriptive summary
    why        // Architectural rationale (WHY comment)
    fields     // List of struct field names

// ── 2. Memory & String Primitives ────────────────────────────────────────────

// WHY: Allocates memory pages directly via Linux kernel SYS_mmap (syscall 9).
fn alloc_buf size
    return syscall(9, 0, size, 3, 34, -1, 0)

// WHY: Releases allocated memory pages via Linux kernel SYS_munmap (syscall 11).
fn free_buf ptr size
    return syscall(11, ptr, size, 0, 0, 0, 0)

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

// WHY: Strips whitespace from both ends of string.
fn trim s
    return trim_right(trim_left(s))

// WHY: Determines leading whitespace width in spaces (tabs count as 4 spaces).
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

// WHY: Checks if string ends with suffix.
fn ends_with s suffix
    slen = len(s)
    flen = len(suffix)
    if flen > slen
        return 0
    offset = slen - flen
    i = 0
    while i < flen
        if char_at(s, offset + i) != char_at(suffix, i)
            return 0
        i = i + 1
    return 1

// WHY: Extracts substring [start, end) without external string dependencies.
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

// WHY: Finds index of substring within string, or returns -1.
fn str_index_of s sub
    slen = len(s)
    sublen = len(sub)
    if sublen == 0
        return 0
    if sublen > slen
        return -1
    limit = slen - sublen
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < sublen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                j = sublen
            else
                j = j + 1
        if match == 1
            return i
        i = i + 1
    return -1

// ── 3. Source Code Parsing & Signature Extraction ─────────────────────────────

// WHY: Formats function declarations into standard signatures 'fn_name(param1, param2)'.
fn parse_fn_sig line
    rest = trim_left(str_sub(line, 3, len(line)))
    eq_idx = str_index_of(rest, "=")
    if eq_idx >= 0
        rest = trim_right(str_sub(rest, 0, eq_idx))

    open_idx = str_index_of(rest, "(")
    if open_idx >= 0
        return rest

    fname = ""
    rlen = len(rest)
    i = 0
    while i < rlen and char_at(rest, i) != " " and char_at(rest, i) != "\t"
        fname = fname + char_at(rest, i)
        i = i + 1

    params = ""
    first = 1
    while i < rlen
        while i < rlen and (char_at(rest, i) == " " or char_at(rest, i) == "\t")
            i = i + 1
        param = ""
        while i < rlen and char_at(rest, i) != " " and char_at(rest, i) != "\t"
            param = param + char_at(rest, i)
            i = i + 1
        if len(param) > 0
            if first == 1
                params = param
                first = 0
            else
                params = params + ", " + param
    return fname + "(" + params + ")"

// WHY: Extracts the documentation string following the doc or why prefix.
fn extract_doc_comment line prefix
    idx = str_index_of(line, prefix)
    if idx < 0
        return ""
    rest = str_sub(line, idx + len(prefix), len(line))
    return trim(rest)

// WHY: Reads raw lines from disk via Linux kernel SYS_read (syscall 0).
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

// WHY: Scans an array of source lines to discover structs, functions, and attached docs.
fn extract_module_docs lines
    items = list()
    total = len(lines)
    pending_doc = ""
    pending_why = ""

    li = 0
    while li < total
        raw_l = get(lines, li)
        tline = trim(raw_l)

        if starts_with(tline, "// Doc:")
            d = extract_doc_comment(tline, "// Doc:")
            if len(pending_doc) == 0
                pending_doc = d
            else
                pending_doc = pending_doc + " " + d
        else
            if starts_with(tline, "// বিবরণ:")
                d = extract_doc_comment(tline, "// বিবরণ:")
                if len(pending_doc) == 0
                    pending_doc = d
                else
                    pending_doc = pending_doc + " " + d
            else
                if starts_with(tline, "// WHY:")
                    w = extract_doc_comment(tline, "// WHY:")
                    if len(pending_why) == 0
                        pending_why = w
                    else
                        pending_why = pending_why + " " + w
                else
                    if starts_with(tline, "// কেন:")
                        w = extract_doc_comment(tline, "// কেন:")
                        if len(pending_why) == 0
                            pending_why = w
                        else
                            pending_why = pending_why + " " + w
                    else
                        if starts_with(tline, "struct ")
                            sname = trim(str_sub(tline, 7, len(tline)))
                            fields = list()
                            
                            // Scan indented field lines
                            while (li + 1) < total
                                next_line = get(lines, li + 1)
                                if count_leading_spaces(next_line) > 0
                                    f_trim = trim(next_line)
                                    if len(f_trim) > 0 and starts_with(f_trim, "//") == 0
                                        fields = push(fields, f_trim)
                                    li = li + 1
                                else
                                    break
                            
                            item = DocItem()
                            item.kind = "struct"
                            item.name = sname
                            
                            sig = ""
                            fcount = len(fields)
                            fi = 0
                            while fi < fcount
                                if fi == 0
                                    sig = get(fields, fi)
                                else
                                    sig = sig + ", " + get(fields, fi)
                                fi = fi + 1
                            item.sig = sig
                            item.doc = pending_doc
                            item.why = pending_why
                            item.fields = fields
                            
                            items = push(items, item)
                            pending_doc = ""
                            pending_why = ""
                        else
                            if starts_with(tline, "fn ")
                                sig = parse_fn_sig(tline)
                                fname = ""
                                oidx = str_index_of(sig, "(")
                                if oidx >= 0
                                    fname = str_sub(sig, 0, oidx)
                                else
                                    fname = sig

                                item = DocItem()
                                item.kind = "fn"
                                item.name = fname
                                item.sig = sig
                                item.doc = pending_doc
                                item.why = pending_why
                                item.fields = list()
                                
                                items = push(items, item)
                                pending_doc = ""
                                pending_why = ""
                            else
                                // Reset pending doc comments if ordinary statements intervene
                                if len(tline) > 0 and starts_with(tline, "//") == 0
                                    pending_doc = ""
                                    pending_why = ""

        li = li + 1
    return items

// ── 4. GitHub-Flavored Markdown Generation ───────────────────────────────────

// WHY: Generates structured, readable GitHub-Flavored Markdown documentation.
fn generate_markdown file_title items
    out = ""
    say "# 📖 Module Documentation: `" + file_title + "`\n"
    say "> Auto-generated by **lipidoc** — Official Sovereign Documentation Engine"
    say "> Target: Lipi 2.0 Sovereign Architecture (100% Native, 0% Libc)\n"
    say "---\n"

    say "## 📊 Overview\n"
    say "| Item Type | Identifier | Signature / Fields | Description |"
    say "|:---|:---|:---|:---|"

    total = len(items)
    i = 0
    while i < total
        item = get(items, i)
        d = item.doc
        if len(d) == 0
            d = "—"
        s = item.sig
        if len(s) == 0
            s = "—"
        say "| `" + item.kind + "` | `" + item.name + "` | `" + s + "` | " + d + " |"
        i = i + 1
    say "\n---\n"

    // Structures Section
    has_structs = 0
    i = 0
    while i < total
        item = get(items, i)
        if item.kind == "struct"
            has_structs = 1
        i = i + 1

    if has_structs == 1
        say "## 🏛️ Structures\n"
        i = 0
        while i < total
            item = get(items, i)
            if item.kind == "struct"
                say "### `struct " + item.name + "`\n"
                fcount = len(item.fields)
                if fcount > 0
                    say "**Fields:**"
                    fi = 0
                    while fi < fcount
                        say "- `" + get(item.fields, fi) + "`"
                        fi = fi + 1
                    say ""
                if len(item.doc) > 0
                    say "**Description:** " + item.doc + "\n"
                if len(item.why) > 0
                    say "> **WHY:** " + item.why + "\n"
            i = i + 1
        say "---\n"

    // Functions Section
    has_funcs = 0
    i = 0
    while i < total
        item = get(items, i)
        if item.kind == "fn"
            has_funcs = 1
        i = i + 1

    if has_funcs == 1
        say "## ⚡ Functions\n"
        i = 0
        while i < total
            item = get(items, i)
            if item.kind == "fn"
                say "### `fn " + item.sig + "`\n"
                if len(item.doc) > 0
                    say "**Description:** " + item.doc + "\n"
                else
                    say "**Description:** *No description provided.*\n"
                if len(item.why) > 0
                    say "> **WHY:** " + item.why + "\n"
            i = i + 1

    return 1

// ── 5. File & Directory Documenter ────────────────────────────────────────────

// WHY: Generates documentation for a single Lipi source file.
fn document_file path
    lines = read_file_lines(path)
    if len(lines) == 0
        say "❌ ত্রুটি: ফাইল পড়তে ব্যর্থ বা ফাইলটি শূন্য: " + path
        return 0
    items = extract_module_docs(lines)
    generate_markdown(path, items)
    return 1

// WHY: Traverses a directory using Linux kernel SYS_getdents64 (syscall 217)
// and generates documentation for all discovered .lp source files.
fn document_directory dir_path
    dfd = syscall(2, dir_path, 0, 0, 0, 0, 0)
    if dfd < 0
        say "❌ ত্রুটি: ডিরেক্টরি খুলতে ব্যর্থ: " + dir_path
        return 0

    buf = alloc_buf(4096)
    n = syscall(217, dfd, buf, 4096, 0, 0, 0)
    bpos = 0
    count = 0

    while bpos < n
        rec_lo = mem_byte_read(buf, bpos + 16)
        rec_hi = mem_byte_read(buf, bpos + 17)
        reclen = rec_lo + (rec_hi * 256)
        dtype = mem_byte_read(buf, bpos + 18)

        name = ""
        npos = bpos + 19
        while 1
            b = mem_byte_read(buf, npos)
            if b == 0
                break
            name = name + chr(b)
            npos = npos + 1

        if reclen == 0
            break

        if ends_with(name, ".lp") and starts_with(name, ".") == 0
            fpath = dir_path + "/" + name
            document_file(fpath)
            count = count + 1

        bpos = bpos + reclen

    syscall(3, dfd, 0, 0, 0, 0, 0)
    free_buf(buf, 4096)

    if count == 0
        say "কোনো .lp ফাইল পাওয়া যায়নি এই ডিরেক্টরিতে: " + dir_path
    return count

// ── 6. CLI Driver & Entry Point ──────────────────────────────────────────────

fn print_banner
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m📖 LIPIDOC — OFFICIAL SOVEREIGN DOCUMENTATION ENGINE (v2.0.0)\033[0m        \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Automatic GitHub-Flavored Markdown Generation | 0% Libc\033[0m             \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n"

fn print_usage
    print_banner()
    say "\033[1;33mব্যবহার (Usage):\033[0m"
    say "  lipidoc <file.lp>"
    say "  lipidoc <directory>"
    say ""
    say "\033[1;33mউদাহরণ (Examples):\033[0m"
    say "  lipidoc src/tools/lipidbg.lp"
    say "  lipidoc src/tools/"
    say ""
    say "\033[1;33mবিকল্পসমূহ (Flags):\033[0m"
    say "  \033[1;32m-h, --help\033[0m    এই সহায়তা বার্তা প্রদর্শন\n"

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        print_usage()
        return 0

    target = get(args, 1)

    if target == "-h" or target == "--help" or target == "help"
        print_usage()
        return 0

    if ends_with(target, ".lp")
        document_file(target)
    else
        document_directory(target)

    return 0

main()
