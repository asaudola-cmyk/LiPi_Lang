// ==============================================================================
// 🧪 LIPI TEST 66: Developer Toolchain & Format/Doc Verification Suite
// ⚡ 100% Pure Lipi 2.0 Indentation Syntax | 0% Libc | 0% External Dependencies
// 🏛️ File: tests/66_developer_toolchain.lp
//
// WHY: Validates the official Lipi developer toolchain:
//      1. 'lipifmt' (Code Formatter): 4-space indentation, operator spacing,
//         trailing whitespace stripping, blank line normalization, --check and -w flags.
//      2. 'lipidoc' (Doc Generator): scans .lp files for structs, functions,
//         '// Doc:' comments, and '// WHY:' comments to produce GitHub-Flavored Markdown.
// ==============================================================================

// ── 1. Process Execution & Subprocess Harness ────────────────────────────────

// WHY: Spawns a shell command via Linux kernel SYS_fork (57), SYS_execve (59),
// and SYS_wait4 (61) to validate external tool binaries directly.
fn run_shell_command cmd_str
    sh_path = "/bin/sh"
    sh_flag = "-c"

    argv = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(argv, 0, sh_path)
    mem_word_write(argv, 8, sh_flag)
    mem_word_write(argv, 16, cmd_str)
    mem_word_write(argv, 24, 0)

    env = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(env, 0, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, sh_path, argv, env, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    syscall(11, argv, 32, 0, 0, 0, 0)
    syscall(11, env, 8, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)

    return exit_code

// ── 2. String & File Inspection Helpers ───────────────────────────────────────

// WHY: Asserts equality and exits with error code 1 upon mismatch.
fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        syscall(60, 1, 0, 0, 0, 0, 0)
    say "  ✔ PASS: " + test_name

// WHY: Checks if string contains a given substring.
fn contains_str s sub
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

// WHY: Asserts that haystack contains needle string.
fn assert_contains haystack needle test_name
    if contains_str(haystack, needle) == 0
        say "  ❌ FAILED: " + test_name
        say "     Missing expected substring: [" + needle + "]"
        syscall(60, 1, 0, 0, 0, 0, 0)
    say "  ✔ PASS: " + test_name

// WHY: Writes raw string content to disk via SYS_open (2) and SYS_write (1).
fn write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0) // O_WRONLY | O_CREAT | O_TRUNC
    if fd < 0
        return 0
    clen = len(content)
    syscall(1, fd, content, clen, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 1

// WHY: Reads entire file content as a single string via SYS_read (0).
fn read_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return ""
    buf = syscall(9, 0, 4096, 3, 34, -1, 0)
    out = ""
    while 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0
            break
        i = 0
        while i < n
            b = mem_byte_read(buf, i)
            out = out + chr(b)
            i = i + 1
    syscall(3, fd, 0, 0, 0, 0, 0)
    syscall(11, buf, 4096, 0, 0, 0, 0)
    return out

// ── 3. Test Cases: Formatter (lipifmt) Verification ──────────────────────────

// WHY: Validates the official sovereign code formatter against unformatted code.
fn test_lipifmt_formatting
    say "\n[১] লিপিকর ফরম্যাটার পরীক্ষণ (lipifmt Verification)..."

    // 1. Prepare unformatted code file
    unformatted_code = "fn calculate a b\n  x=a+b\n  if x>10\n    return x*2\n\n\n\n  return x\n"
    target_file = "/tmp/test66_unformatted.lp"
    w_ok = write_file(target_file, unformatted_code)
    assert_eq(w_ok, 1, "Write unformatted test source file")

    // 2. Validate --check on unformatted file (should return 1)
    chk_unformatted = run_shell_command("./bin/lipifmt --check " + target_file + " > /dev/null 2>&1")
    assert_eq(chk_unformatted, 1, "lipifmt --check correctly detects unformatted source (exit code 1)")

    // 3. Format file in-place using -w flag
    write_res = run_shell_command("./bin/lipifmt -w " + target_file + " > /dev/null 2>&1")
    assert_eq(write_res, 0, "lipifmt -w executes successfully (exit code 0)")

    // 4. Validate --check on formatted file (should now return 0)
    chk_formatted = run_shell_command("./bin/lipifmt --check " + target_file + " > /dev/null 2>&1")
    assert_eq(chk_formatted, 0, "lipifmt --check confirms file is properly formatted (exit code 0)")

    // 5. Read back formatted content and verify AST formatting guarantees
    formatted_content = read_file(target_file)
    assert_contains(formatted_content, "    x = a + b", "4-space indentation and operator spacing on assignment ('x = a + b')")
    assert_contains(formatted_content, "    if x > 10", "4-space indentation and relational operator spacing ('x > 10')")
    assert_contains(formatted_content, "        return x * 2", "8-space nested indentation and multiplication spacing ('x * 2')")
    assert_contains(formatted_content, "    return x", "4-space indentation on dedented return")

    // Verify normalization of consecutive blank lines (max 2 blank lines)
    if contains_str(formatted_content, "\n\n\n\n") == 1
        say "  ❌ FAILED: Consecutive blank lines were not normalized to max 2"
        syscall(60, 1, 0, 0, 0, 0, 0)
    say "  ✔ PASS: Consecutive blank lines successfully normalized to max 2"

// ── 4. Test Cases: Doc Generator (lipidoc) Verification ───────────────────────

// WHY: Validates doc extraction and GitHub-Flavored Markdown generation.
fn test_lipidoc_generation
    say "\n[২] লিপিক ডক জেনারেটর পরীক্ষণ (lipidoc Verification)..."

    // 1. Prepare documented Lipi module
    doc_module_code = "// ==============================================================================\n// 📐 3D Vector Math Library\n// ==============================================================================\n\n// Doc: Represents a 3D coordinate vector.\n// WHY: Compact struct memory alignment for direct CPU SIMD vectorization.\nstruct Vector3D\n    x\n    y\n    z\n\n// Doc: Computes the component-wise sum of two vectors.\n// WHY: Addition is commutative and performed without heap overhead.\nfn vec_add a b\n    res = Vector3D()\n    res.x = a.x + b.x\n    res.y = a.y + b.y\n    res.z = a.z + b.z\n    return res\n\n// Doc: Calculates the scalar dot product of two vectors.\n// WHY: Dot product is fundamental for lighting and projection mathematics.\nfn vec_dot a b\n    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)\n"
    module_path = "/tmp/test66_module.lp"
    w_ok = write_file(module_path, doc_module_code)
    assert_eq(w_ok, 1, "Write documented test source module")

    // 2. Generate documentation via lipidoc CLI
    doc_output_path = "/tmp/test66_doc.md"
    doc_res = run_shell_command("./bin/lipidoc " + module_path + " > " + doc_output_path + " 2>&1")
    assert_eq(doc_res, 0, "lipidoc executes successfully (exit code 0)")

    // 3. Inspect generated GitHub-Flavored Markdown content
    doc_content = read_file(doc_output_path)
    assert_contains(doc_content, "# 📖 Module Documentation: `/tmp/test66_module.lp`", "Header title rendering")
    assert_contains(doc_content, "## 📊 Overview", "Overview table section")
    assert_contains(doc_content, "| `struct` | `Vector3D` | `x, y, z` | Represents a 3D coordinate vector. |", "Overview table struct row")
    assert_contains(doc_content, "| `fn` | `vec_add` | `vec_add(a, b)` | Computes the component-wise sum of two vectors. |", "Overview table fn row")
    assert_contains(doc_content, "### `struct Vector3D`", "Struct detailed section")
    assert_contains(doc_content, "- `x`", "Struct field x list item")
    assert_contains(doc_content, "- `y`", "Struct field y list item")
    assert_contains(doc_content, "- `z`", "Struct field z list item")
    assert_contains(doc_content, "> **WHY:** Compact struct memory alignment for direct CPU SIMD vectorization.", "Struct WHY comment blockquote")
    assert_contains(doc_content, "### `fn vec_add(a, b)`", "Function vec_add detailed signature")
    assert_contains(doc_content, "**Description:** Computes the component-wise sum of two vectors.", "Function vec_add doc description")
    assert_contains(doc_content, "> **WHY:** Addition is commutative and performed without heap overhead.", "Function vec_add WHY comment blockquote")
    assert_contains(doc_content, "### `fn vec_dot(a, b)`", "Function vec_dot detailed signature")
    assert_contains(doc_content, "> **WHY:** Dot product is fundamental for lighting and projection mathematics.", "Function vec_dot WHY comment blockquote")

// ── 5. Main Test Runner ───────────────────────────────────────────────────────

fn main
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  🧪 LIPI TEST 66: Developer Toolchain (lipifmt & lipidoc) Suite        ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    test_lipifmt_formatting()
    test_lipidoc_generation()

    say "\n=========================================================================="
    say "PASS: Test 66 Developer Toolchain"
    say "=========================================================================="
    return 0

main()
