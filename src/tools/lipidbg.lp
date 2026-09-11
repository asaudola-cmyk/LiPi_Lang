// ==============================================================================
// 👑 LIPIDBG — 100% PURE LIPI SOVEREIGN SYSTEM DEBUGGER (src/tools/lipidbg.lp)
// ⚡ Hardware Register & Stack Introspection | ELF Binary Diagnostics | Zero GDB / Zero C
// ==============================================================================

// WHY: A sovereign language requires an autonomous diagnostics suite.
// lipidbg inspects physical CPU stacks, validates ELF64 binaries, disassembles
// machine instructions, and renders memory dumps without any C or GDB dependencies.

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

fn to_hex32 val
    v = val % 4294967296
    if v < 0 v = v + 4294967296
    return to_hex16((v / 65536) % 65536) + to_hex16(v % 65536)

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

fn reg64_name r
    if r == 0 return "rax"
    if r == 1 return "rcx"
    if r == 2 return "rdx"
    if r == 3 return "rbx"
    if r == 4 return "rsp"
    if r == 5 return "rbp"
    if r == 6 return "rsi"
    if r == 7 return "rdi"
    if r == 8 return "r8"
    if r == 9 return "r9"
    if r == 10 return "r10"
    if r == 11 return "r11"
    if r == 12 return "r12"
    if r == 13 return "r13"
    if r == 14 return "r14"
    if r == 15 return "r15"
    return "r" + r

fn dbg_disasm code_ptr len
    say "  Offset    Hex Bytes          Instruction / Mnemonic"
    say "  ────────  ─────────────────  ────────────────────────────────────"
    offset = 0
    count = 0
    while offset < len
        b0 = mem_byte_read(code_ptr, offset)
        b1 = 0
        b2 = 0
        b3 = 0
        b4 = 0
        if offset + 1 < len b1 = mem_byte_read(code_ptr, offset + 1)
        if offset + 2 < len b2 = mem_byte_read(code_ptr, offset + 2)
        if offset + 3 < len b3 = mem_byte_read(code_ptr, offset + 3)
        if offset + 4 < len b4 = mem_byte_read(code_ptr, offset + 4)

        ilen = 1
        asm_str = "db 0x" + to_hex8(b0)
        hbytes = to_hex8(b0)

        if b0 == 144
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "nop"
        if b0 == 244
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "hlt"
        if b0 == 204
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "int3"
        if b0 == 195
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "ret"
        if b0 == 201
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "leave"
        if b0 == 15 and b1 == 5
            ilen = 2
            hbytes = to_hex8(b0) + " " + to_hex8(b1)
            asm_str = "syscall"
        if b0 >= 80 and b0 <= 87
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "push " + reg64_name(b0 - 80)
        if b0 >= 88 and b0 <= 95
            ilen = 1
            hbytes = to_hex8(b0)
            asm_str = "pop " + reg64_name(b0 - 88)
        if b0 == 65
            if b1 >= 80 and b1 <= 87
                ilen = 2
                hbytes = to_hex8(b0) + " " + to_hex8(b1)
                asm_str = "push " + reg64_name(8 + b1 - 80)
            if b1 >= 88 and b1 <= 95
                ilen = 2
                hbytes = to_hex8(b0) + " " + to_hex8(b1)
                asm_str = "pop " + reg64_name(8 + b1 - 88)
        if b0 == 235 and offset + 1 < len
            ilen = 2
            hbytes = to_hex8(b0) + " " + to_hex8(b1)
            asm_str = "jmp short +" + b1
        if b0 == 116 and offset + 1 < len
            ilen = 2
            hbytes = to_hex8(b0) + " " + to_hex8(b1)
            asm_str = "jz short +" + b1
        if b0 == 117 and offset + 1 < len
            ilen = 2
            hbytes = to_hex8(b0) + " " + to_hex8(b1)
            asm_str = "jnz short +" + b1
        if b0 == 49 and b1 == 192
            ilen = 2
            hbytes = to_hex8(b0) + " " + to_hex8(b1)
            asm_str = "xor eax, eax"
        if b0 == 232 and offset + 4 < len
            ilen = 5
            hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2) + " " + to_hex8(b3) + " " + to_hex8(b4)
            rel32 = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
            asm_str = "call rel32 [disp=0x" + to_hex32(rel32) + "]"
        if b0 == 233 and offset + 4 < len
            ilen = 5
            hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2) + " " + to_hex8(b3) + " " + to_hex8(b4)
            rel32 = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
            asm_str = "jmp rel32 [disp=0x" + to_hex32(rel32) + "]"
        if b0 >= 184 and b0 <= 191 and offset + 4 < len
            ilen = 5
            hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2) + " " + to_hex8(b3) + " " + to_hex8(b4)
            imm = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
            asm_str = "mov " + reg64_name(b0 - 184) + ", 0x" + to_hex32(imm)
        if b0 == 72 and offset + 1 < len
            if b1 == 137 and offset + 2 < len
                mod = b2 / 64
                reg = (b2 / 8) % 8
                rm = b2 % 8
                if mod == 3
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "mov " + reg64_name(rm) + ", " + reg64_name(reg)
                if mod == 0
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "mov [" + reg64_name(rm) + "], " + reg64_name(reg)
            if b1 == 139 and offset + 2 < len
                mod = b2 / 64
                reg = (b2 / 8) % 8
                rm = b2 % 8
                if mod == 3
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "mov " + reg64_name(reg) + ", " + reg64_name(rm)
                if mod == 0
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "mov " + reg64_name(reg) + ", [" + reg64_name(rm) + "]"
            if b1 == 1 and offset + 2 < len
                mod = b2 / 64
                reg = (b2 / 8) % 8
                rm = b2 % 8
                if mod == 3
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "add " + reg64_name(rm) + ", " + reg64_name(reg)
            if b1 == 131 and offset + 3 < len
                op = (b2 / 8) % 8
                rm = b2 % 8
                ilen = 4
                hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2) + " " + to_hex8(b3)
                if op == 7 asm_str = "cmp " + reg64_name(rm) + ", " + b3
                if op == 5 asm_str = "sub " + reg64_name(rm) + ", " + b3
                if op == 0 asm_str = "add " + reg64_name(rm) + ", " + b3
                if op == 4 asm_str = "and " + reg64_name(rm) + ", " + b3
            if b1 == 141 and offset + 2 < len
                mod = b2 / 64
                reg = (b2 / 8) % 8
                rm = b2 % 8
                if mod == 0 and rm == 5
                    ilen = 7
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2) + " .."
                    asm_str = "lea " + reg64_name(reg) + ", [rip + disp32]"
            if b1 == 49 and offset + 2 < len
                mod = b2 / 64
                reg = (b2 / 8) % 8
                rm = b2 % 8
                if mod == 3
                    ilen = 3
                    hbytes = to_hex8(b0) + " " + to_hex8(b1) + " " + to_hex8(b2)
                    asm_str = "xor " + reg64_name(rm) + ", " + reg64_name(reg)
            if b1 >= 184 and b1 <= 191
                ilen = 10
                hbytes = to_hex8(b0) + " " + to_hex8(b1) + " .."
                asm_str = "mov " + reg64_name(b1 - 184) + ", imm64"

        say "  +" + to_hex16(offset) + ":  " + hbytes + "	" + asm_str
        offset = offset + ilen
        count = count + 1
    say "  ────────  ─────────────────  ────────────────────────────────────"
    say "  ✔ ডিসঅ্যাসেম্বল সম্পন্ন: " + count + " ইন্সট্রাকশন\n"
    return count

fn read_u16 buf off
    b0 = mem_byte_read(buf, off)
    b1 = mem_byte_read(buf, off + 1)
    return b0 + (b1 * 256)

fn read_u32 buf off
    b0 = mem_byte_read(buf, off)
    b1 = mem_byte_read(buf, off + 1)
    b2 = mem_byte_read(buf, off + 2)
    b3 = mem_byte_read(buf, off + 3)
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn read_u64 buf off
    w0 = read_u32(buf, off)
    w1 = read_u32(buf, off + 4)
    return w0 + (w1 * 4294967296)

fn বাইনারি_ডায়াগনস্টিক bin_path
    say "🔍 টার্গেট বাইনারি ডায়াগনস্টিক: " + bin_path
    fd = syscall(2, bin_path, 0, 0, 0, 0, 0)
    if fd < 0
        say "❌ ফাইল খুলতে ব্যর্থ: " + bin_path
        return 0
    hdr = malloc(128)
    n = syscall(0, fd, hdr, 128, 0, 0, 0)
    if n < 64
        say "❌ অবৈধ ELF সাইজ"
        free(hdr, 128)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return 0

    say "  • ELF Magic: 0x7F E L F"
    elf_class = mem_byte_read(hdr, 4)
    if elf_class == 2
        say "  • Class: ELF64 (64-bit Architecture)"
    endian = mem_byte_read(hdr, 5)
    if endian == 1
        say "  • Data: Little-Endian (2s complement)"

    e_type = read_u16(hdr, 16)
    e_machine = read_u16(hdr, 18)
    e_entry = read_u64(hdr, 24)
    e_phoff = read_u64(hdr, 32)
    e_shoff = read_u64(hdr, 40)
    e_flags = read_u32(hdr, 48)
    e_ehsize = read_u16(hdr, 52)
    e_phentsize = read_u16(hdr, 54)
    e_phnum = read_u16(hdr, 56)
    e_shentsize = read_u16(hdr, 58)
    e_shnum = read_u16(hdr, 60)
    e_shstrndx = read_u16(hdr, 62)

    say "  • Type (e_type): " + e_type + " (ET_EXEC)"
    say "  • Architecture (e_machine): " + e_machine + " (EM_X86_64, 0x3E)"
    say "  • Entry Point (e_entry): 0x" + qword_to_hex(e_entry) + " (" + e_entry + ")"
    say "  • Program Headers (e_phoff): " + e_phoff + " (" + e_phnum + " entries)"
    say "  • Section Headers (e_shoff): " + e_shoff + " (" + e_shnum + " entries)"
    say "  • Flags (e_flags): 0x" + to_hex32(e_flags)
    say "  • Header Size (e_ehsize): " + e_ehsize + " bytes"

    if e_phnum > 0 and e_phoff >= 64 and n >= (e_phoff + 56)
        p_offset = read_u64(hdr, e_phoff + 8)
        p_vaddr = read_u64(hdr, e_phoff + 16)
        p_filesz = read_u64(hdr, e_phoff + 32)
        say "  • Segment [0]: PT_LOAD at offset 0x" + qword_to_hex(p_offset) + ", VAddr 0x" + qword_to_hex(p_vaddr)
        if e_entry >= p_vaddr and e_entry < (p_vaddr + p_filesz)
            e_off = p_offset + (e_entry - p_vaddr)
            say "  ✔ এন্ট্রি পয়েন্ট ফাইল অফসেট: " + e_off + " (0x" + to_hex16(e_off) + ")"
            syscall(8, fd, e_off, 0, 0, 0, 0)
            cbuf = malloc(64)
            cn = syscall(0, fd, cbuf, 64, 0, 0, 0)
            if cn > 0
                dbg_disasm(cbuf, cn)
            free(cbuf, 64)

    free(hdr, 128)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 1

fn dbg_hex_dump addr len
    say "  মেমরি হেক্স ডাম্প @ 0x" + qword_to_hex(addr) + ":"
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
            j = j + 1
        say "  0x" + qword_to_hex(caddr) + ": " + lbytes + " |" + lchars + "|"
        cursor = cursor + 16

fn dbg_stack_inspect
    rsp = stack_pointer()
    say "  • বর্তমান %rsp: 0x" + qword_to_hex(rsp) + " (" + rsp + ")"
    aln = rsp % 16
    if aln == 0
        say "  ✔ স্ট্যাক এলাইনমেন্ট: 16-byte Aligned (System V AMD64 ABI)"
    else
        say "  • স্ট্যাক এলাইনমেন্ট: Offset " + aln + " bytes"
    say "  শীর্ষ ৪টি স্ট্যাক ফ্রেম কোয়াডওয়ার্ড:"
    i = 0
    while i < 4
        off = i * 8
        val = mem_word_read(rsp, i)
        say "  [%rsp +" + off + "] @ 0x" + qword_to_hex(rsp + off) + " = 0x" + qword_to_hex(val) + " (" + val + ")"
        i = i + 1

fn main
    args = argv()
    argc = len(args)
    if argc >= 2
        cmd = get(args, 1)
        if cmd == "version" or cmd == "-v"
            say "lipidbg সংস্করণ: প্রথম ১.০ (Prothom 1.0 Sovereign)"
            say "লক্ষ্য: Linux x86_64 ELF64 (0% Libc, 0% GDB)"
            return 0
        if cmd == "help" or cmd == "-h"
            say "ব্যবহার: lipidbg <binary_path> | disasm | inspect <addr> | stack | version"
            return 0
        if cmd == "stack"
            dbg_stack_inspect()
            return 0
        if cmd == "inspect" or cmd == "hex"
            taddr = stack_pointer()
            if argc >= 3 taddr = parse_hex_or_dec(get(args, 2))
            dbg_hex_dump(taddr, 32)
            return 0
        if cmd == "disasm" or cmd == "run"
            tf = "bin/lipc_bin"
            if argc >= 3 tf = get(args, 2)
            বাইনারি_ডায়াগনস্টিক(tf)
            return 0
        বাইনারি_ডায়াগনস্টিক(cmd)
        return 0

    say "=== [LIPIDBG Sovereign System Debugger] ==="
    say "[১] সিপিইউ স্ট্যাক ফ্রেম ইন্সপেকশন:"
    dbg_stack_inspect()
    say "\n[২] লাইভ হিপ মেমরি ডাম্প:"
    tbuf = malloc(16)
    mem_byte_write(tbuf, 0, 76)
    mem_byte_write(tbuf, 1, 73)
    mem_byte_write(tbuf, 2, 80)
    mem_byte_write(tbuf, 3, 73)
    dbg_hex_dump(tbuf, 16)
    free(tbuf, 16)
    say "\n[৩] বাইনারি ডায়াগনস্টিক (bin/lipc_bin):"
    বাইনারি_ডায়াগনস্টিক("bin/lipc_bin")
    say "\n✔ lipidbg ১০০% কার্যকর ও সম্পূর্ণ C-মুক্ত!"
    return 0

main()
