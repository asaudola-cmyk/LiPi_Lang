// ==============================================================================
// 🧪 LIPI TEST 67: Package Security & Ed25519 Cryptographic Signing Suite
// ⚡ 100% Pure Lipi 2.0 Indentation Syntax | 0% Libc | 0% External Dependencies
// 🏛️ File: tests/67_package_security_ed25519.lp
//
// WHY: Validates the sovereign package manager cryptographic security toolchain:
//      1. 'lipipkg --help' and 'lipipkg version' CLI interfaces.
//      2. 'lipipkg init <name>' directory scaffolding.
//      3. 'lipipkg sign <target>' computing recursive SHA-256 digests and
//         signing manifest hash using authentic Ed25519 private keys.
//      4. 'lipipkg verify <target>' validating authentic author signatures
//         and detecting tampered, modified, or forged package payloads.
//      5. Single-file and archive (.tar) signing and verification workflows.
// ==============================================================================

// ── 1. Process Execution & Subprocess Harness ────────────────────────────────

// WHY: Spawns a shell command via Linux kernel SYS_fork (57), SYS_execve (59),
// and SYS_wait4 (61) to validate external tool binaries directly with 0% libc.
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

// ── 2. Assertion & File Helpers ───────────────────────────────────────────────

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
    if slen == 0 return 1
    tlen = len(s)
    if slen > tlen return 0
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
        if match == 1 return 1
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
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0 return 0
    clen = len(content)
    syscall(1, fd, content, clen, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 1

// WHY: Reads entire file content as a single string via SYS_read (0).
fn read_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return ""
    buf = syscall(9, 0, 4096, 3, 34, -1, 0)
    out = ""
    while 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0 break
        i = 0
        while i < n
            b = mem_byte_read(buf, i)
            out = out + chr(b)
            i = i + 1
    syscall(3, fd, 0, 0, 0, 0, 0)
    syscall(11, buf, 4096, 0, 0, 0, 0)
    return out

// ── 3. Test Cases ─────────────────────────────────────────────────────────────

// WHY: Validates CLI help and version subcommands.
fn test_cli_help_version
    say "\n[১] সিএলআই সহায়তা ও সংস্করণ মেনু পরীক্ষণ (CLI Help & Version)..."
    help_out = "/tmp/test67_help.txt"
    h_code = run_shell_command("./bin/lipipkg --help > " + help_out + " 2>&1")
    assert_eq(h_code, 0, "lipipkg --help exits with 0")
    h_content = read_file(help_out)
    assert_contains(h_content, "sign", "Help output lists sign command")
    assert_contains(h_content, "verify", "Help output lists verify command")
    assert_contains(h_content, "Ed25519", "Help output mentions Ed25519 cryptography")

    ver_out = "/tmp/test67_ver.txt"
    v_code = run_shell_command("./bin/lipipkg version > " + ver_out + " 2>&1")
    assert_eq(v_code, 0, "lipipkg version exits with 0")
    v_content = read_file(ver_out)
    assert_contains(v_content, "প্রথম ১.০", "Version output shows sovereign release name")

// WHY: Validates package project scaffolding, Ed25519 signing, and authentic verification.
fn test_package_lifecycle_signing
    say "\n[২] প্যাকেজ ইনিট, ক্রিপ্টোগ্রাফিক স্বাক্ষর ও যাচাইকরণ (Init, Sign, Verify)..."
    pkg_dir = "/tmp/test67_package"
    run_shell_command("rm -rf " + pkg_dir)

    // 1. Initialize project
    init_code = run_shell_command("./bin/lipipkg init " + pkg_dir + " > /dev/null 2>&1")
    assert_eq(init_code, 0, "lipipkg init creates package directory structure")

    // 2. Sign package directory
    sign_out = "/tmp/test67_sign.txt"
    s_code = run_shell_command("./bin/lipipkg sign " + pkg_dir + " > " + sign_out + " 2>&1")
    assert_eq(s_code, 0, "lipipkg sign executes successfully on package directory")
    s_content = read_file(sign_out)
    assert_contains(s_content, "SHA-256 ম্যানিফেস্ট হ্যাশ", "Signing computes manifest SHA-256")
    assert_contains(s_content, "Ed25519 পাবলিক কী", "Signing reports author public key")
    assert_contains(s_content, "Ed25519 ডিজিটাল স্বাক্ষর", "Signing produces valid signature")

    // 3. Inspect generated lipi.sig
    sig_file = pkg_dir + "/lipi.sig"
    sig_content = read_file(sig_file)
    assert_contains(sig_content, "algorithm = \"Ed25519-SHA256\"", "lipi.sig declares Ed25519-SHA256 algorithm")
    assert_contains(sig_content, "manifest_hash =", "lipi.sig records manifest hash")
    assert_contains(sig_content, "signature =", "lipi.sig records digital signature")
    assert_contains(sig_content, "src/main.lp =", "lipi.sig includes src/main.lp digest")

    // 4. Verify authentic package
    verify_out = "/tmp/test67_verify.txt"
    v_code = run_shell_command("./bin/lipipkg verify " + pkg_dir + " > " + verify_out + " 2>&1")
    assert_eq(v_code, 0, "lipipkg verify confirms authentic package (exit code 0)")
    v_content = read_file(verify_out)
    assert_contains(v_content, "ক্রিপ্টোগ্রাফিক ডিজিটাল স্বাক্ষর বৈধ", "Author signature verified")
    assert_contains(v_content, "১০০% যাচাইকৃত ও সুরক্ষিত", "Package integrity 100% verified")

// WHY: Validates tamper detection on source payload and forged signature rejection.
fn test_tamper_detection
    say "\n[৩] টেম্পারিং ও জাল স্বাক্ষর শনাক্তকরণ (Tamper Detection)..."
    pkg_dir = "/tmp/test67_package"

    // 1. Modify src/main.lp to simulate unauthorized code tampering
    tamper_code = run_shell_command("echo '// Malicious Injection' >> " + pkg_dir + "/src/main.lp")
    tamper_verify = run_shell_command("./bin/lipipkg verify " + pkg_dir + " > /dev/null 2>&1")
    assert_eq(tamper_verify, 1, "lipipkg verify detects modified file and exits with 1")

    // 2. Re-sign package to restore validity
    re_sign = run_shell_command("./bin/lipipkg sign " + pkg_dir + " > /dev/null 2>&1")
    assert_eq(re_sign, 0, "Package successfully re-signed after authorized update")
    re_verify = run_shell_command("./bin/lipipkg verify " + pkg_dir + " > /dev/null 2>&1")
    assert_eq(re_verify, 0, "Re-signed package passes verification with 0")

    // 3. Corrupt signature in lipi.sig to simulate forged/corrupted signature
    forge_sig = run_shell_command("sed -i 's/signature = \"[0-9a-f]/signature = \"ff/' " + pkg_dir + "/lipi.sig")
    forge_verify = run_shell_command("./bin/lipipkg verify " + pkg_dir + " > /dev/null 2>&1")
    assert_eq(forge_verify, 1, "lipipkg verify detects forged signature and exits with 1")

// WHY: Validates single archive / tarball distribution signing and integrity checking.
fn test_archive_signing
    say "\n[৪] একক ফাইল ও আর্কাইভ ডিজিটাল সাইনিং (Archive Signing)..."
    tar_path = "/tmp/test67_distribution.tar"
    write_file(tar_path, "SOVEREIGN_DISTRIBUTION_PACKAGE_BINARY_STREAM_PAYLOAD_2026")

    tar_sign = run_shell_command("./bin/lipipkg sign " + tar_path + " > /dev/null 2>&1")
    assert_eq(tar_sign, 0, "lipipkg sign succeeds on single archive file")

    tar_verify = run_shell_command("./bin/lipipkg verify " + tar_path + " > /dev/null 2>&1")
    assert_eq(tar_verify, 0, "lipipkg verify succeeds on authentic single archive file")

    // Tamper archive
    write_file(tar_path, "MODIFIED_TAMPERED_ARCHIVE_DATA")
    tar_tamper_v = run_shell_command("./bin/lipipkg verify " + tar_path + " > /dev/null 2>&1")
    assert_eq(tar_tamper_v, 1, "lipipkg verify detects tampered archive file (exit code 1)")

// ── 4. Main Test Runner ───────────────────────────────────────────────────────

fn main
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  🧪 LIPI TEST 67: Package Security & Ed25519 Signing Verification     ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    test_cli_help_version()
    test_package_lifecycle_signing()
    test_tamper_detection()
    test_archive_signing()

    say "\n=========================================================================="
    say "PASS: Test 67 Package Security & Ed25519 Signing"
    say "=========================================================================="
    return 0

main()
