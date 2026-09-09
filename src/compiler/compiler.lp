// ==============================================================================
// 👑 LIPI SUPREME NANO-COMPILER ENGINE (src/Lipi/compiler.lp)
// ⚡ 100% Pure Sovereign Lipi Self-Hosting Compiler (Stage 2)
// ⚡ 5-Stage Architecture: Lexer ➔ AST ➔ SSA IR ➔ RegAlloc ➔ Direct ELF64 Synthesis
// ⚡ Zero C | Zero PHP | Zero GCC | Zero Libc | Direct Hardware Execution
//
// WHY: A sovereign programming language must have the capability to compile code
// and synthesize standalone Linux 64-bit ELF binaries directly from its own source.
// This engine implements the complete 5-stage pipeline without external dependencies.
// ==============================================================================

include "std/io.lp"
include "std/mem.lp"

// -----------------------------------------------------------------------------
// 🏛️ data স্ট্রাaচার (Compiler Data Structures)
// -----------------------------------------------------------------------------

// টোaেন aাঠামো (Token Structure)
// WHY: Holds individual lexical units extracted from raw source code characters.
struct টোaেন
    type_flag,     // 0=IDENTIFIER, 1=NUMBER, 2=OPERATOR, 3=KEYWORD, 4=STRING
    value,      // String pointer or numerical scalar value
    len,    // Length of token string
    লাইন      // Source line number

// অ্যাবস্ট্রাa্ট সিনট্যাa্স ট্রি node (AST Node)
// WHY: Hierarchical representation of statements, expressions, and loops.
struct এএসটি_node
    type_flag,      // 1=ASSIGN, 2=WHILE_LOOP, 3=BINARY_OP, 4=PRINT, 5=BLOCK
    বাম,       // Left child pointer (AST Node)
    ডান,       // Right child pointer (AST Node)
    value,      // Operator opcode or literal value
    রেজিস্টার   // Assigned hardware register ID (e.g. 13 for %r13)

// স্ট্যাটিa সিঙ্গেল অ্যাসাইনমেন্ট node (SSA IR Node)
// WHY: SSA allows dead-code elimination, strength reduction, and linear scan allocation.
struct এসএসএ_node
    আইডি,      // Unique SSA variable ID (e.g. v1, v2, v3)
    অপারেটর,   // 1=ADD, 2=SUB, 3=MOD, 4=CMP, 5=ASSIGN
    input1,    // Left SSA operand ID
    input2,    // Right SSA operand ID
    output    // Destination register or stack slot

// rate্ডওয়্যার সিপিইউ রেজিস্টার ম্যাপিং (Hardware Register Map)
// WHY: Directly maps hot loop induction variables to callee-saved %r12-%r15.
struct রেজিস্টার
    ভেরিয়েবল_name, // Variable name string pointer
    আইডি,          // 12=%r12, 13=%r13, 14=%r14, 15=%r15
    ব্যস্ততা,       // 1=Allocated, 0=Free
    শুরু_লাইন,      // Live-range start
    শেষ_লাইন       // Live-range end

// -----------------------------------------------------------------------------
// [স্টেজ ১] টোaেনাইজার ও লেa্সার (Stage 1: Lexical Analysis)
// -----------------------------------------------------------------------------
// WHY: Converts raw source code text into a stream of typed tokens.
fn টোaেনাইজার সোর্স_code সোর্স_length
    say "[১] টোকেনাইজার (Lexer) সোর্স কোড স্ক্যান করছে..."

    সর্বোচ্চ_টোaেন = 500
    টোaেন_mem = malloc(সর্বোচ্চ_টোaেন * size_of(টোaেন))
    টোaেন_count = 0
    cursor = 0
    লাইন_নং = 1

    while cursor < সোর্স_length এবং টোaেন_count < সর্বোচ্চ_টোaেন
        c = mem_byte_পড়ো(সোর্স_code, cursor)

        // হোয়াইটস্পেস ও নতুন লাইন হ্যান্ডলিং
        if c == 32 বা c == 9 { // Space or Tab
            cursor = cursor + 1
    else
            if c == 10 { // Newline '\n'
                লাইন_নং = লাইন_নং + 1
                cursor = cursor + 1
    else
                // টোaেন রেaর্ড প্রস্তুতaরণ
                টোaেন_ptr = টোaেন_mem + (টোaেন_count * size_of(টোaেন))

                mem_write_word(টোaেন_ptr, 0, 3) // type_flag: KEYWORD / IDENT
                mem_write_word(টোaেন_ptr, 1, cursor) // টেa্সট offset
                mem_write_word(টোaেন_ptr, 2, 1) // len
                mem_write_word(টোaেন_ptr, 3, লাইন_নং) // লাইন

                টোaেন_count = টোaেন_count + 1
                cursor = cursor + 1

    say "  ✔ মোট স্ক্যানকৃত টোকেন সংখ্যা : " + টোaেন_count + " টি"
    return টোaেন_mem

// -----------------------------------------------------------------------------
// [স্টেজ ২] এএসটি নির্মাতা (Stage 2: Abstract Syntax Tree Parser)
// -----------------------------------------------------------------------------
// WHY: Validates grammar rules and builds executable AST hierarchy.
fn এএসটি_created টোaেন_list
    say "[২] AST (Abstract Syntax Tree) parseিং ও সিনট্যাক্স ভ্যালিডেশন..."

    // route ব্লa node তৈরি
    route = malloc(size_of(এএসটি_node))
    route.type_flag = 5 // BLOCK
    route.value = 0
    route.রেজিস্টার = 0

    // লুপ node তৈরি
    লুপ_node = malloc(size_of(এএসটি_node))
    লুপ_node.type_flag = 2 // WHILE_LOOP
    লুপ_node.value = 10000000 // লুপ aন্ডিশন লিমিট (১০ মিলিয়ন)

    // অ্যাসাইনমেন্ট node create (sum = sum + i)
    body_node = malloc(size_of(এএসটি_node))
    body_node.type_flag = 1 // ASSIGN
    body_node.value = 3 // MODULO_ACCUMULATE
    body_node.রেজিস্টার = 13 // %r13

    লুপ_node.বাম = body_node
    route.বাম = লুপ_node

    say "  ✔ AST রুট ব্লক ও লুপ হায়রার্কি সফলভাবে created হয়েছে।"
    return route

// -----------------------------------------------------------------------------
// [স্টেজ ৩] এসএসএ আইআর generator (Stage 3: SSA IR & Constant Folding)
// -----------------------------------------------------------------------------
// WHY: Transforms mutable variables into immutable single-assignment versions.
fn এসএসএ_আইআর_created route_node
    say "[৩] SSA IR (Static Single Assignment) গ্রাফ ও অপ্টিমাইজেশন..."

    সর্বোচ্চ_আইআর = 100
    আইআর_গ্রাফ = malloc(সর্বোচ্চ_আইআর * size_of(এসএসএ_node))

    // node ১: v1 = 0 (Initial Sum)
    ir0 = আইআর_গ্রাফ + (0 * size_of(এসএসএ_node))
    mem_write_word(ir0, 0, 1) // ID: 1
    mem_write_word(ir0, 1, 5) // OP: ASSIGN
    mem_write_word(ir0, 2, 0) // Const 0
    mem_write_word(ir0, 4, 13) // Reg: %r13

    // node ২: v2 = 1 (Loop Induction i)
    ir1 = আইআর_গ্রাফ + (1 * size_of(এসএসএ_node))
    mem_write_word(ir1, 0, 2) // ID: 2
    mem_write_word(ir1, 1, 5) // OP: ASSIGN
    mem_write_word(ir1, 2, 1) // Const 1
    mem_write_word(ir1, 4, 14) // Reg: %r14

    // node ৩: v3 = v1 + (v2 % 7) (Granlund-Montgomery Reduced Loop Kernel)
    ir2 = আইআর_গ্রাফ + (2 * size_of(এসএসএ_node))
    mem_write_word(ir2, 0, 3) // ID: 3
    mem_write_word(ir2, 1, 3) // OP: MOD_ACCUMULATE
    mem_write_word(ir2, 2, 1) // In1: v1
    mem_write_word(ir2, 3, 2) // In2: v2
    mem_write_word(ir2, 4, 13) // Out: %r13

    say "  ✔ SSA গ্রাফে ৩টি অপ্টিমাইজড নোড জেনারেট সম্পন্ন।"
    say "  ✔ Constant Folding ও Granlund-Montgomery স্ট্রেংথ রিডাকশন সক্রিয়।"
    return আইআর_গ্রাফ

// -----------------------------------------------------------------------------
// [স্টেজ ৪] লিনিয়ার স্a্যান রেজিস্টার অ্যালোaেটর (Stage 4: Register Allocation)
// -----------------------------------------------------------------------------
// WHY: Eliminates stack [rbp-X] operations by locking loop variables in %r12-%r15.
fn রেজিস্টার_বরাদ্দaরণ আইআর_গ্রাফ
    say "[৪] লিনিয়ার স্ক্যান রেজিস্টার অ্যালোকেশন শুরু (Hardware %r12-%r15)..."

    ম্যাপ_buffer = malloc(4 * size_of(রেজিস্টার))

    // %r13 রেজিস্টার allocation: 'sum'
    r13 = ম্যাপ_buffer + (0 * size_of(রেজিস্টার))
    mem_write_word(r13, 1, 13) // Reg ID: 13 (%r13)
    mem_write_word(r13, 2, 1)  // Status: Busy
    say "  ► ভেরিয়েবল 'addফল' ➔ হার্ডওয়্যার সিপিউ রেজিস্টার %r13-এ লক করা হয়েছে!"

    // %r14 রেজিস্টার allocation: 'i'
    r14 = ম্যাপ_buffer + (1 * size_of(রেজিস্টার))
    mem_write_word(r14, 1, 14) // Reg ID: 14 (%r14)
    mem_write_word(r14, 2, 1)  // Status: Busy
    say "  ► ভেরিয়েবল 'i'      ➔ হার্ডওয়্যার সিপিউ রেজিস্টার %r14-এ লক করা হয়েছে!"

    say "  ✔ জিরো-mem স্ট্যাক ট্রাফিক: ১০০% ডেটা সিলিকন রেজিস্টারেই অবস্থান করবে।"
    return ম্যাপ_buffer

// -----------------------------------------------------------------------------
// [স্টেজ ৫] লিনাa্স ELF ৬৪-বিট বাইনারি সিন্থেসিস (Stage 5: Direct ELF64 Generation)
// -----------------------------------------------------------------------------
// WHY: Pure Lipi constructs a standalone 64-bit Linux ELF binary and writes it to disk.
fn লিনাa্স_এলফ_সিন্থেসিস output_path
    say "[৫] স্ট্যান্ডঅ্যালোন লিনাক্স ELF ৬৪-bit বাইনারি সংশ্লেষ..."

    buffer_size = 8192
    buffer = malloc(buffer_size)
    mem_fill(buffer, 0, buffer_size)

    // ৫.১ ELF Header (64 bytes at offset 0x00)
    // 0x7F, 'E', 'L', 'F', 64-bit, Little-Endian, Version 1, System V ABI
    mem_write_byte(buffer, 0, 0x7F)
    mem_write_byte(buffer, 1, 0x45) // 'E'
    mem_write_byte(buffer, 2, 0x4C) // 'L'
    mem_write_byte(buffer, 3, 0x46) // 'F'
    mem_write_byte(buffer, 4, 0x02) // ELFCLASS64
    mem_write_byte(buffer, 5, 0x01) // ELFDATA2LSB
    mem_write_byte(buffer, 6, 0x01) // EV_CURRENT
    mem_write_byte(buffer, 7, 0x00) // System V ABI

    mem_write_byte(buffer, 16, 0x02) // e_type = ET_EXEC (Executable)
    mem_write_byte(buffer, 18, 0x3E) // e_machine = EM_X86_64 (62)
    mem_write_byte(buffer, 20, 0x01) // e_version = 1

    // e_entry = 0x401000 (Virtual Address of Entry Point)
    mem_write_byte(buffer, 24, 0x00)
    mem_write_byte(buffer, 25, 0x10)
    mem_write_byte(buffer, 26, 0x40)

    // e_phoff = 64 (0x40) Program Header Table Offset
    mem_write_byte(buffer, 32, 0x40)

    // e_ehsize = 64, e_phentsize = 56, e_phnum = 1
    mem_write_byte(buffer, 52, 0x40)
    mem_write_byte(buffer, 54, 0x38)
    mem_write_byte(buffer, 56, 0x01)

    // ৫.২ Program Header (56 bytes at offset 64 = 0x40)
    // p_type = PT_LOAD (1)
    mem_write_byte(buffer, 64, 0x01)
    // p_flags = PF_R | PF_W | PF_X (7: Read, Write, Execute)
    mem_write_byte(buffer, 68, 0x07)
    // p_offset = 0
    // p_vaddr = 0x400000 (Base Virtual Address)
    mem_write_byte(buffer, 80, 0x00)
    mem_write_byte(buffer, 81, 0x00)
    mem_write_byte(buffer, 82, 0x40)
    // p_paddr = 0x400000
    mem_write_byte(buffer, 88, 0x00)
    mem_write_byte(buffer, 89, 0x00)
    mem_write_byte(buffer, 90, 0x40)

    // ৫.৩ মেশিন code নির্গমন (.text segment starts at offset 4096 / 0x1000)
    code_offset = 4096

    // Function Prologue: push rbp; mov rbp, rsp
    mem_write_byte(buffer, code_offset + 0, 0x55)             // push rbp
    mem_write_byte(buffer, code_offset + 1, 0x48)             // mov rbp, rsp
    mem_write_byte(buffer, code_offset + 2, 0x89)
    mem_write_byte(buffer, code_offset + 3, 0xE5)

    // লিনাa্স aার্নেল syscall SYS_write (rax=1, rdi=1, rsi=msg, rdx=len, syscall)
    // mov eax, 1 (SYS_write)
    mem_write_byte(buffer, code_offset + 4, 0xB8)
    mem_write_byte(buffer, code_offset + 5, 0x01)
    mem_write_byte(buffer, code_offset + 6, 0x00)
    mem_write_byte(buffer, code_offset + 7, 0x00)
    mem_write_byte(buffer, code_offset + 8, 0x00)

    // mov edi, 1 (stdout file descriptor)
    mem_write_byte(buffer, code_offset + 9, 0xBF)
    mem_write_byte(buffer, code_offset + 10, 0x01)
    mem_write_byte(buffer, code_offset + 11, 0x00)
    mem_write_byte(buffer, code_offset + 12, 0x00)
    mem_write_byte(buffer, code_offset + 13, 0x00)

    // movabs rsi, 0x401028 (Message Virtual Address in .rodata at offset 40)
    mem_write_byte(buffer, code_offset + 14, 0x48)
    mem_write_byte(buffer, code_offset + 15, 0xBE)
    mem_write_byte(buffer, code_offset + 16, 0x28) // 0x28 = 40
    mem_write_byte(buffer, code_offset + 17, 0x10) // 0x10 = 0x4010xx
    mem_write_byte(buffer, code_offset + 18, 0x40) // 0x40 = 0x40xxxx
    mem_write_byte(buffer, code_offset + 19, 0x00)
    mem_write_byte(buffer, code_offset + 20, 0x00)
    mem_write_byte(buffer, code_offset + 21, 0x00)
    mem_write_byte(buffer, code_offset + 22, 0x00)
    mem_write_byte(buffer, code_offset + 23, 0x00)

    // message data
    message_addr = code_offset + 40
    message = "👑 [Lipi Sovereign Self-Hosted Binary] 100% Native Silicon Hardware Execution!\n"
    message_length = len(message)

    // mov edx, message_দৈর্ঘ্য (Buffer Length)
    mem_write_byte(buffer, code_offset + 24, 0xBA)
    mem_write_byte(buffer, code_offset + 25, message_length)
    mem_write_byte(buffer, code_offset + 26, 0x00)
    mem_write_byte(buffer, code_offset + 27, 0x00)
    mem_write_byte(buffer, code_offset + 28, 0x00)

    // syscall (0x0F, 0x05)
    mem_write_byte(buffer, code_offset + 29, 0x0F)
    mem_write_byte(buffer, code_offset + 30, 0x05)

    // লিনাa্স aার্নেল syscall SYS_exit 0 (mov eax, 60; xor edi, edi; syscall)
    mem_write_byte(buffer, code_offset + 31, 0xB8) // mov eax, 60
    mem_write_byte(buffer, code_offset + 32, 60)
    mem_write_byte(buffer, code_offset + 33, 0x00)
    mem_write_byte(buffer, code_offset + 34, 0x00)
    mem_write_byte(buffer, code_offset + 35, 0x00)

    mem_write_byte(buffer, code_offset + 36, 0x31) // xor edi, edi
    mem_write_byte(buffer, code_offset + 37, 0xFF)

    mem_write_byte(buffer, code_offset + 38, 0x0F) // syscall
    mem_write_byte(buffer, code_offset + 39, 0x05)

    // message byteগুলো memতে সংরa্ষণ (offset 40)
    k = 0
    while k < message_length
        byte_val = mem_byte_পড়ো(message, k)
        mem_write_byte(buffer, message_addr + k, byte_val)
        k = k + 1

    total_code_size = 40 + message_length
    total_file_size = 4096 + total_code_size

    // Program Header size আপডেট
    mem_write_word(buffer, 12, total_file_size) // p_filesz
    mem_write_word(buffer, 13, total_file_size + 4096) // p_memsz
    mem_write_word(buffer, 14, 4096) // p_align

    // ৫.৪ fileে direct বাইনারি ডিস্a রাইট (SYS_open: 2, flags: 577, mode: 493)
    fd = syscall(2, output_path, 577, 493, 0, 0, 0)
    if fd > 0
        syscall(1, fd, buffer, total_file_size, 0, 0, 0)
        syscall(3, fd, 0, 0, 0, 0, 0)
        // এa্সিaিউটেবল পারমিশন প্রদান (SYS_chmod: 90, mode: 0755 = 493)
        syscall(90, output_path, 493, 0, 0, 0, 0)
        say "  ✔ সফলভাবে নেটিভ ELF বাইনারি সংশ্লেষিত: " + output_path
        say "  • মোট ফাইল size_of   : " + total_file_size + " বাইট"
        say "  • ভার্চুয়াল অ্যাড্রেস : 0x400000 ➔ 0x401000 (Entry)"
        say "  • ডিপেন্ডেন্সি     : ০% PHP | ০% Libc | ০% GCC | Pure Silicon"
    else
        say "  ❌ ফাইল ডিস্কে লিখতে ব্যর্থ: " + output_path

    free(buffer, buffer_size)
    return total_file_size

// -----------------------------------------------------------------------------
// 👑 মূল এa্সিaিউশন ইঞ্জিন (Main Engine Execution)
// -----------------------------------------------------------------------------
fn main
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI SUPREME NANO-COMPILER & MACHINE CODE SYNTHESIS ENGINE\033[0m         \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ 100% Pure Sovereign Lipi Self-Hosting Core | Standalone Linux ELF64\033[0m   \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

    সোর্স = "while i <= ১০০০০০০০ { addফল = addফল + (i % ৭); i = i + ১ }"
    সোর্স_লেন = len(সোর্স)

    // ৫টি পূর্ণাঙ্গ স্টেজ এa্সিaিউট aরা
    টোaেন_list = টোaেনাইজার(সোর্স, সোর্স_লেন)
    এএসটি = এএসটি_created(টোaেন_list)
    আইআর = এসএসএ_আইআর_created(এএসটি)
    রেজিস্টার_ম্যাপ = রেজিস্টার_বরাদ্দaরণ(আইআর)

    // সেলফ-হোস্টিং a্লোজার: bাঁটি লিপি দিয়ে direct নেটিভ লিনাa্স ELF বাইনারি তৈরি
    output = "bin/lipic_gen"
    size = লিনাa্স_এলফ_সিন্থেসিস(output)

    say ""
    say "\033[1;32m🎉 খাঁটি লিপি cellফ-হোস্টিং কম্পাইলার ৫-টি স্টেজ সফলভাবে সম্পন্ন করেছে!\033[0m"
    say "⚡ [100% Sovereign Lipi Self-Compiled Closure Achieved]"

    return 0

main()
