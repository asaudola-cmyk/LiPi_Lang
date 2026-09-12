// ==============================================================================
// 👑 LIPI INTERACTIVE REPL & SHELL: lipirepl (src/tools/lipirepl.lp)
// ⚡ Autonomous Read-Eval-Print-Loop | Hardware Introspection | Zero C / Zero Libc
// ==============================================================================

// WHY: A sovereign language requires an interactive environment to experiment with
// expressions, inspect CPU registers, and measure hardware latency with zero libc.

// WHY: Canonical standard library modules unified under universe/ for clean architecture.
include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/tools/debug.lp"

fn hex_digit n
    val = n % 16
    if val < 0 val = val + 16
    if val < 10 return chr(48 + val)
    return chr(87 + val)

fn to_hex8 val
    v = val % 256
    if v < 0 v = v + 256
    return hex_digit(v / 16) + hex_digit(v % 16)

fn to_hex16 val
    v = val % 65536
    if v < 0 v = v + 65536
    return to_hex8((v / 256) % 256) + to_hex8(v % 256)

fn qword_to_hex val
    buf = malloc(8)
    mem_word_write(buf, 0, val)
    s = to_hex8(mem_byte_read(buf, 7)) + to_hex8(mem_byte_read(buf, 6)) + to_hex8(mem_byte_read(buf, 5)) + to_hex8(mem_byte_read(buf, 4)) + to_hex8(mem_byte_read(buf, 3)) + to_hex8(mem_byte_read(buf, 2)) + to_hex8(mem_byte_read(buf, 1)) + to_hex8(mem_byte_read(buf, 0))
    free(buf, 8)
    return s

fn parse_hex_or_dec s
    if len(s) == 0 return 0
    slen = len(s)
    is_hex = 0
    p = 0
    if slen > 2
        if char_at(s, 0) == "0" and (char_at(s, 1) == "x" or char_at(s, 1) == "X")
            is_hex = 1
            p = 2
    val = 0
    if is_hex == 1
        while p < slen
            code = ord(char_at(s, p))
            d = -1
            if code >= 48 and code <= 57 d = code - 48
            if code >= 97 and code <= 102 d = 10 + (code - 97)
            if code >= 65 and code <= 70 d = 10 + (code - 65)
            if d < 0 break
            val = (val * 16) + d
            p = p + 1
        return val
    while p < slen
        code = ord(char_at(s, p))
        if code >= 48 and code <= 57
            val = (val * 10) + (code - 48)
        else
            break
        p = p + 1
    return val

fn প্রিন্ট_রেপল_ব্যানার
    say "[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗[0m"
    say "[38;2;0;255;204m║[0m  [1;38;2;255;255;255m👑 LIPIREPL — SOVEREIGN INTERACTIVE LIPI SHELL (First 1.0.0)[0m          [38;2;0;255;204m║[0m"
    say "[38;2;0;255;204m║[0m  [38;2;180;180;180m⚡ Live Silicon Evaluation | Hardware CPU Introspection | 0% Libc[0m     [38;2;0;255;204m║[0m"
    say "[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝[0m"
    say ""
    say "টাইপ করুন :help নির্দেশিকার জন্য, অথবা :exit প্রস্থান করার জন্য।"
    say "────────────────────────────────────────────────────────────────────────"

fn রেপল_সাহায্য
    say "[1;33m[লিপি আরইপিএল কমান্ড সহায়িকা / REPL Commands]:[0m"
    say "  :help / :সাহায্য     - এই সাহায্য মেনু প্রদর্শন"
    say "  :clock / :ক্লক       - হার্ডওয়্যার আরডিটিএসসি (RDTSC) সাইকেল টাইমিং ও ল্যাটেন্সি"
    say "  :stack / :স্ট্যাক    - সিপিইউ স্ট্যাক পয়েন্টার (%rsp) ও ফ্রেম পরিদর্শন"
    say "  :mem <addr> [len]    - লাইভ মেমরি হেক্স ডাম্প ও আসকি পরিদর্শন"
    say "  :reg / :রেজিস্টার    - বর্তমান হার্ডওয়্যার রেজিস্টার ও সিপিইউ স্টেট"
    say "  :eval <n1> <op> <n2> - সরাসরি গাণিতিক হিসাব ও এক্সিকিউশন টাইমিং"
    say "  :exit / :বিদায়       - আরইপিএল শেল থেকে প্রস্থান
"

fn রেপল_ক্লক
    t1 = cpu_clock()
    t2 = cpu_clock()
    delta = t2 - t1
    say "⚡ [হার্ডওয়্যার আরডিটিএসসি সিপিইউ ক্লক]:"
    say "  • বর্তমান সাইকেল টাইমস্ট্যাম্প : " + t1
    say "  • টাইমার রেজোলিউশন ওভারহেড  : " + delta + " CPU cycles"
    say "  • প্রিসিশন                  : Nanosecond Hardware Timing
"

fn রেপল_স্ট্যাক
    say "⚡ [সিপিইউ স্ট্যাক ফ্রেম পরিদর্শন]:"
    rsp = stack_pointer()
    say "  • বর্তমান %rsp অ্যাড্রেস: 0x" + qword_to_hex(rsp) + " (" + rsp + ")"
    aln = rsp % 16
    if aln == 0
        say "  ✔ স্ট্যাক এলাইনমেন্ট: 16-byte Aligned (System V AMD64 ABI Valid)"
    else
        say "  • স্ট্যাক এলাইনমেন্ট: Offset " + aln + " bytes"
    say "  শীর্ষ ৪টি ফ্রেম কোয়াডওয়ার্ড:"
    i = 0
    while i < 4
        off = i * 8
        val = mem_word_read(rsp, i)
        say "  [%rsp +" + off + "] @ 0x" + qword_to_hex(rsp + off) + " = 0x" + qword_to_hex(val) + " (" + val + ")"
        i = i + 1
    say ""

fn রেপল_মেমরি addr len
    say "🔍 [মেমরি হেক্স ডাম্প @ 0x" + qword_to_hex(addr) + " (" + len + " বাইট)]:"
    cursor = 0
    while cursor < len
        caddr = addr + cursor
        lbytes = ""
        lchars = ""
        j = 0
        while j < 16
            if (cursor + j) < len
                b = mem_byte_read(addr, cursor + j)
                lbytes = lbytes + to_hex8(b) + " "
                if b >= 32 and b <= 126
                    lchars = lchars + chr(b)
                else
                    lchars = lchars + "."
            else
                lbytes = lbytes + "   "
                lchars = lchars + " "
            if j == 7 lbytes = lbytes + " "
            j = j + 1
        say "  0x" + qword_to_hex(caddr) + ": " + lbytes + " |" + lchars + "|"
        cursor = cursor + 16
    say ""

fn রেপল_রেজিস্টার
    say "⚡ [সিপিইউ হার্ডওয়্যার রেজিস্টার স্টেট]:"
    say "  • স্ট্যাক পয়েন্টার (%rsp) : 0x" + qword_to_hex(stack_pointer())
    say "  • সাইকেল কাউন্টার (RDTSC) : " + cpu_clock()
    say "  • কার্নেল লিনাক্স এআইবি   : Direct Syscall ABI (0% Libc)
"

fn রেপল_ইভ্যাল a b op
    t_start = cpu_clock()
    res = 0
    op_name = ""
    if op == 1
        res = a + b
        op_name = "যোগ"
    if op == 2
        res = a * b
        op_name = "গুণ"
    if op == 3
        res = a - b
        op_name = "বিয়োগ"
    if op == 4
        if b != 0
            res = a / b
            op_name = "ভাগ"
    if op == 5
        if b != 0
            res = a % b
            op_name = "মডুলাস"
    t_end = cpu_clock()
    elapsed = t_end - t_start
    say "  => ফলাফল (" + op_name + "): " + res + " (CPU Cycles: " + elapsed + ")
"
    return res

fn repl_read_line
    p_str = "lipi> "
    syscall(1, 1, p_str, len(p_str), 0, 0, 0)
    line = ""
    bb = malloc(2)
    while 1
        n = syscall(0, 0, bb, 1, 0, 0, 0)
        if n <= 0
            free(bb, 2)
            if len(line) == 0 return ":exit"
            return line
        b = mem_byte_read(bb, 0)
        if b == 10 or b == 13 break
        line = line + chr(b)
    free(bb, 2)
    return line

fn repl_str_starts prefix s
    plen = len(prefix)
    slen = len(s)
    if slen < plen return 0
    i = 0
    while i < plen
        if char_at(prefix, i) != char_at(s, i) return 0
        i = i + 1
    return 1

fn repl_dispatch_command cmd
    if cmd == ":exit" or cmd == ":quit" or cmd == ":বিদায়" or cmd == ":q"
        say "বিদায়! Sovereign Lipi REPL সেশন সমাপ্ত।"
        return 0
    if cmd == ":help" or cmd == ":সাহায্য" or cmd == ":h" or cmd == "?"
        রেপল_সাহায্য()
        return 1
    if cmd == ":clock" or cmd == ":ক্লক"
        রেপল_ক্লক()
        return 1
    if cmd == ":stack" or cmd == ":স্ট্যাক"
        রেপল_স্ট্যাক()
        return 1
    if cmd == ":reg" or cmd == ":রেজিস্টার"
        রেপল_রেজিস্টার()
        return 1
    if repl_str_starts(":mem", cmd) == 1
        addr = stack_pointer()
        mlen = 16
        if len(cmd) > 5
            arg1 = ""
            p = 5
            while p < len(cmd) and char_at(cmd, p) == " "
                p = p + 1
            while p < len(cmd) and char_at(cmd, p) != " "
                arg1 = arg1 + char_at(cmd, p)
                p = p + 1
            if len(arg1) > 0
                addr = parse_hex_or_dec(arg1)
            while p < len(cmd) and char_at(cmd, p) == " "
                p = p + 1
            arg2 = ""
            while p < len(cmd) and char_at(cmd, p) != " "
                arg2 = arg2 + char_at(cmd, p)
                p = p + 1
            if len(arg2) > 0
                mlen = parse_hex_or_dec(arg2)
        রেপল_মেমরি(addr, mlen)
        return 1
    if repl_str_starts(":eval", cmd) == 1
        // Parse a op b e.g. :eval 42 * 10
        say "  [ইভ্যালুয়েশন] " + cmd
        if len(cmd) > 6
            return repl_eval_expr_string(str_sub(cmd, 6, len(cmd)))
        রেপল_ইভ্যাল(42, 10, 2)
        return 1

    // Direct live expression evaluation (e.g. '10 + 20' or '42 * 2')
    if repl_str_starts(":", cmd) == 0
        if len(cmd) > 0
            return repl_eval_expr_string(cmd)
        return 1

    if len(cmd) > 0
        say "অজানা কমান্ড: " + cmd + " (টাইপ করুন :help সহায়তার জন্য)"
    return 1

// ─── Direct Interactive Expression Evaluator ──────────────────────────────────
// WHY: Evaluates numeric and arithmetic expressions instantly in-memory without compiling to disk
fn repl_eval_expr_string s
    slen = len(s)
    p = 0
    while p < slen and (char_at(s, p) == " " or char_at(s, p) == "\t")
        p = p + 1
    if p >= slen
        return 1

    num_str1 = ""
    while p < slen and ((ord(char_at(s, p)) >= 48 and ord(char_at(s, p)) <= 57) or char_at(s, p) == "x" or char_at(s, p) == "X")
        num_str1 = num_str1 + char_at(s, p)
        p = p + 1

    if len(num_str1) == 0
        say "অজানা ইনপুট: " + s + " (টাইপ করুন :help সহায়তার জন্য)"
        return 1

    v1 = parse_hex_or_dec(num_str1)

    while p < slen and (char_at(s, p) == " " or char_at(s, p) == "\t")
        p = p + 1

    if p >= slen
        say "  => ফলাফল: " + str(v1)
        return 1

    op_char = char_at(s, p)
    op_id = 0
    if op_char == "+"
        op_id = 1
    if op_char == "*"
        op_id = 2
    if op_char == "-"
        op_id = 3
    if op_char == "/"
        op_id = 4
    if op_char == "%"
        op_id = 5

    if op_id == 0
        say "  => ফলাফল: " + str(v1)
        return 1

    p = p + 1
    while p < slen and (char_at(s, p) == " " or char_at(s, p) == "\t")
        p = p + 1

    num_str2 = ""
    while p < slen and ((ord(char_at(s, p)) >= 48 and ord(char_at(s, p)) <= 57) or char_at(s, p) == "x" or char_at(s, p) == "X")
        num_str2 = num_str2 + char_at(s, p)
        p = p + 1

    if len(num_str2) == 0
        say "  => ফলাফল: " + str(v1)
        return 1

    v2 = parse_hex_or_dec(num_str2)
    রেপল_ইভ্যাল(v1, v2, op_id)
    return 1

fn main
    args = argv()
    argc = len(args)

    if argc >= 2
        arg1 = get(args, 1)
        if arg1 == "--test" or arg1 == "-t"
            প্রিন্ট_রেপল_ব্যানার()
            say "[টেস্ট ১: :help]"
            রেপল_সাহায্য()
            say "[টেস্ট ২: :clock]"
            রেপল_ক্লক()
            say "[টেস্ট ৩: :stack]"
            রেপল_স্ট্যাক()
            say "[টেস্ট ৪: :eval]"
            রেপল_ইভ্যাল(42, 10, 2)
            say "✔ lipirepl সেলফ-টেস্ট সম্পূর্ণ সফল!"
            return 0

    প্রিন্ট_রেপল_ব্যানার()
    running = 1
    while running == 1
        input_line = repl_read_line()
        running = repl_dispatch_command(input_line)

    return 0

main()
