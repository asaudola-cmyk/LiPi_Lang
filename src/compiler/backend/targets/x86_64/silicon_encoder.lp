// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — RING-0 SILICON & HARDWARE INTRINSICS ENCODER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | 0% External Assembler (NASM/as)
// 🏛️ File: src/compiler/backend/targets/x86_64/silicon_encoder.lp
//
// WHY THIS MODULE:
// 1. Sovereign Bare-Metal Authority: Gives Lipi direct native x86-64 machine-code
//    emission for Ring-0 CPU control, Port I/O, single-instruction volatile MMIO,
//    hardware atomics, memory fences, CPUID, structured @asm blocks, and UEFI
//    Microsoft x64 ABI calls — with zero Linux syscalls and zero external assemblers.
// 2. Freestanding Purity: Every helper in this file contains ZERO Linux syscall
//    instructions (0F 05), making the entire module 100% safe for --freestanding,
//    --target=multiboot2-bare, --target=elf-kernel, --target=raw-bin, and --target=uefi.
// 3. Single-Instruction Bus Semantics: MMIO read/write intrinsics emit exact 8/16/32/64-bit
//    hardware bus transactions (movzx/mov byte/word/dword/qword) so PCIe, APIC, NVMe,
//    VGA, and VirtIO registers never tear across multiple bus cycles.
// ==============================================================================

fn x86_synth_emit_silicon_port_io s
    // ── Port I/O: inb/outb, inw/outw, inl/outl, io_wait ───────────────────────
    // port_in8(port=%rdi) -> u8 in %rax: mov edx, edi; xor eax, eax; in al, dx; ret
    off_in8 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_in8", off_in8)
    x86_synth_register_helper_fn(s, "inb", off_in8)
    x86_synth_register_helper_fn(s, "পোর্ট_পড়ো৮", off_in8)
    x86_synth_emit_bytes(s, [137, 250, 49, 192, 236, 195])

    // port_out8(port=%rdi, val=%rsi): mov edx, edi; mov eax, esi; out dx, al; ret
    off_out8 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_out8", off_out8)
    x86_synth_register_helper_fn(s, "outb", off_out8)
    x86_synth_register_helper_fn(s, "পোর্ট_লেখো৮", off_out8)
    x86_synth_emit_bytes(s, [137, 250, 137, 240, 238, 195])

    // port_in16(port=%rdi) -> u16 in %rax: mov edx, edi; xor eax, eax; in ax, dx; ret
    off_in16 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_in16", off_in16)
    x86_synth_register_helper_fn(s, "inw", off_in16)
    x86_synth_register_helper_fn(s, "পোর্ট_পড়ো১৬", off_in16)
    x86_synth_emit_bytes(s, [137, 250, 49, 192, 102, 237, 195])

    // port_out16(port=%rdi, val=%rsi): mov edx, edi; mov eax, esi; out dx, ax; ret
    off_out16 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_out16", off_out16)
    x86_synth_register_helper_fn(s, "outw", off_out16)
    x86_synth_register_helper_fn(s, "পোর্ট_লেখো১৬", off_out16)
    x86_synth_emit_bytes(s, [137, 250, 137, 240, 102, 239, 195])

    // port_in32(port=%rdi) -> u32 in %rax: mov edx, edi; in eax, dx; ret
    off_in32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_in32", off_in32)
    x86_synth_register_helper_fn(s, "inl", off_in32)
    x86_synth_register_helper_fn(s, "পোর্ট_পড়ো৩২", off_in32)
    x86_synth_emit_bytes(s, [137, 250, 237, 195])

    // port_out32(port=%rdi, val=%rsi): mov edx, edi; mov eax, esi; out dx, eax; ret
    off_out32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "port_out32", off_out32)
    x86_synth_register_helper_fn(s, "outl", off_out32)
    x86_synth_register_helper_fn(s, "পোর্ট_লেখো৩২", off_out32)
    x86_synth_emit_bytes(s, [137, 250, 137, 240, 239, 195])

    // io_wait(): xor eax, eax; out 0x80, al; ret
    off_iowait = s.synth_code.len()
    x86_synth_register_helper_fn(s, "io_wait", off_iowait)
    x86_synth_register_helper_fn(s, "port_io_wait", off_iowait)
    x86_synth_emit_bytes(s, [49, 192, 230, 128, 195])
    return 0

fn x86_synth_emit_silicon_mmio s
    // ── Single-Instruction Volatile MMIO (8/16/32/64-bit) ─────────────────────
    // mmio_r8(addr=%rdi) -> u8 in %rax: movzx eax, byte ptr [rdi]; ret
    off_r8 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_r8", off_r8)
    x86_synth_register_helper_fn(s, "mmio_read8", off_r8)
    x86_synth_register_helper_fn(s, "mem_u8_read", off_r8)
    x86_synth_emit_bytes(s, [15, 182, 7, 195])

    // mmio_w8(addr=%rdi, val=%rsi): mov byte ptr [rdi], sil; mov rax, rsi; ret
    off_w8 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_w8", off_w8)
    x86_synth_register_helper_fn(s, "mmio_write8", off_w8)
    x86_synth_register_helper_fn(s, "mem_u8_write", off_w8)
    x86_synth_emit_bytes(s, [64, 136, 55, 72, 137, 240, 195])

    // mmio_r16(addr=%rdi) -> u16 in %rax: movzx eax, word ptr [rdi]; ret
    off_r16 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_r16", off_r16)
    x86_synth_register_helper_fn(s, "mmio_read16", off_r16)
    x86_synth_register_helper_fn(s, "mem_u16_read", off_r16)
    x86_synth_register_helper_fn(s, "sys_peek16_hw", off_r16)
    x86_synth_emit_bytes(s, [15, 183, 7, 195])

    // mmio_w16(addr=%rdi, val=%rsi): mov word ptr [rdi], si; mov rax, rsi; ret
    off_w16 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_w16", off_w16)
    x86_synth_register_helper_fn(s, "mmio_write16", off_w16)
    x86_synth_register_helper_fn(s, "mem_u16_write", off_w16)
    x86_synth_register_helper_fn(s, "sys_poke16_hw", off_w16)
    x86_synth_emit_bytes(s, [102, 137, 55, 72, 137, 240, 195])

    // mmio_r32(addr=%rdi) -> u32 in %rax: mov eax, dword ptr [rdi]; ret
    off_r32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_r32", off_r32)
    x86_synth_register_helper_fn(s, "mmio_read32_hw", off_r32)
    x86_synth_register_helper_fn(s, "mem_u32_read", off_r32)
    x86_synth_register_helper_fn(s, "sys_peek32_hw", off_r32)
    x86_synth_emit_bytes(s, [139, 7, 195])

    // mmio_w32(addr=%rdi, val=%rsi): mov dword ptr [rdi], esi; mov rax, rsi; ret
    off_w32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_w32", off_w32)
    x86_synth_register_helper_fn(s, "mmio_write32_hw", off_w32)
    x86_synth_register_helper_fn(s, "mem_u32_write", off_w32)
    x86_synth_register_helper_fn(s, "sys_poke32_hw", off_w32)
    x86_synth_emit_bytes(s, [137, 55, 72, 137, 240, 195])

    // mmio_r64(addr=%rdi) -> u64 in %rax: mov rax, qword ptr [rdi]; ret
    off_r64 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_r64", off_r64)
    x86_synth_register_helper_fn(s, "mmio_read64", off_r64)
    x86_synth_register_helper_fn(s, "mem_u64_read", off_r64)
    x86_synth_register_helper_fn(s, "sys_peek64_hw", off_r64)
    x86_synth_emit_bytes(s, [72, 139, 7, 195])

    // mmio_w64(addr=%rdi, val=%rsi): mov qword ptr [rdi], rsi; mov rax, rsi; ret
    off_w64 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "mmio_w64", off_w64)
    x86_synth_register_helper_fn(s, "mmio_write64", off_w64)
    x86_synth_register_helper_fn(s, "mem_u64_write", off_w64)
    x86_synth_register_helper_fn(s, "sys_poke64_hw", off_w64)
    x86_synth_emit_bytes(s, [72, 137, 55, 72, 137, 240, 195])
    return 0

fn x86_synth_emit_silicon_atomics_and_fences s
    // ── Hardware Atomics (32/64-bit) & Memory Fences ──────────────────────────
    // atomic_cas32(ptr=%rdi, exp=%rsi, new=%rdx) -> 1 if swapped else 0
    off_cas32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_cas32", off_cas32)
    x86_synth_emit_bytes(s, [137, 240, 240, 15, 177, 23, 15, 148, 192, 15, 182, 192, 195])

    // atomic_cas64(ptr=%rdi, exp=%rsi, new=%rdx) -> 1 if swapped else 0 (freestanding copy)
    off_cas64 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_cas64", off_cas64)
    if s.synth_freestanding == 1
        x86_synth_register_helper_fn(s, "atomic_cas", off_cas64)
        x86_synth_register_helper_fn(s, "atomic_compare_swap", off_cas64)
    end
    x86_synth_emit_bytes(s, [72, 137, 240, 240, 72, 15, 177, 23, 15, 148, 192, 72, 15, 182, 192, 195])

    // atomic_xchg32(ptr=%rdi, val=%rsi) -> old u32
    off_x32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_xchg32", off_x32)
    x86_synth_emit_bytes(s, [137, 240, 135, 7, 195])

    // atomic_xchg64(ptr=%rdi, val=%rsi) -> old u64
    off_x64 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_xchg64", off_x64)
    x86_synth_emit_bytes(s, [72, 137, 240, 72, 135, 7, 195])

    // atomic_add32(ptr=%rdi, delta=%rsi) -> old u32
    off_a32 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_add32", off_a32)
    x86_synth_emit_bytes(s, [137, 240, 240, 15, 193, 7, 195])

    // atomic_add64(ptr=%rdi, delta=%rsi) -> old u64
    off_a64 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "atomic_add64", off_a64)
    if s.synth_freestanding == 1
        x86_synth_register_helper_fn(s, "atomic_add", off_a64)
    end
    x86_synth_emit_bytes(s, [72, 137, 240, 240, 72, 15, 193, 7, 195])

    // fence_full() / mfence / cpu_fence / cpu_dmb / cpu_dsb (cross-arch barrier parity)
    off_mf = s.synth_code.len()
    x86_synth_register_helper_fn(s, "fence_full", off_mf)
    x86_synth_register_helper_fn(s, "mfence", off_mf)
    x86_synth_register_helper_fn(s, "cpu_fence", off_mf)
    x86_synth_register_helper_fn(s, "cpu_dmb", off_mf)
    x86_synth_register_helper_fn(s, "cpu_dsb", off_mf)
    x86_synth_register_helper_fn(s, "মেমরি_ব্যারিয়ার", off_mf)
    x86_synth_emit_bytes(s, [15, 174, 240, 195])

    // fence_store() / sfence
    off_sf = s.synth_code.len()
    x86_synth_register_helper_fn(s, "fence_store", off_sf)
    x86_synth_register_helper_fn(s, "sfence", off_sf)
    x86_synth_emit_bytes(s, [15, 174, 248, 195])

    // fence_load() / lfence / cpu_isb (cross-arch instruction barrier parity)
    off_lf = s.synth_code.len()
    x86_synth_register_helper_fn(s, "fence_load", off_lf)
    x86_synth_register_helper_fn(s, "lfence", off_lf)
    x86_synth_register_helper_fn(s, "cpu_isb", off_lf)
    x86_synth_emit_bytes(s, [15, 174, 232, 195])

    // cpu_pause() / cpu_wfi() (cross-arch low-power wait parity)
    off_pause = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_pause", off_pause)
    x86_synth_register_helper_fn(s, "cpu_wfi", off_pause)
    x86_synth_emit_bytes(s, [243, 144, 195])

    // cpu_nop() (cross-arch bare-metal parity with ARM64 & RISC-V 64)
    off_nop = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_nop", off_nop)
    x86_synth_emit_bytes(s, [144, 195])
    return 0

fn x86_synth_emit_silicon_cpu_control s
    // ── Ring-0 CPU Control, Descriptor Tables, CR0..4, MSRs, TLB, CPUID ──────
    // cpu_cli() / cli
    off_cli = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_cli", off_cli)
    x86_synth_register_helper_fn(s, "cli", off_cli)
    x86_synth_emit_bytes(s, [250, 195])

    // cpu_sti() / sti
    off_sti = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_sti", off_sti)
    x86_synth_register_helper_fn(s, "sti", off_sti)
    x86_synth_emit_bytes(s, [251, 195])

    // cpu_hlt() / cpu_halt() / hlt
    off_hlt = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_hlt", off_hlt)
    x86_synth_register_helper_fn(s, "cpu_halt", off_hlt)
    x86_synth_register_helper_fn(s, "hlt", off_hlt)
    x86_synth_emit_bytes(s, [244, 195])

    // cpu_lgdt(gdtr_ptr=%rdi)
    off_lgdt = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_lgdt", off_lgdt)
    x86_synth_register_helper_fn(s, "lgdt", off_lgdt)
    x86_synth_emit_bytes(s, [15, 1, 23, 195])

    // cpu_lidt(idtr_ptr=%rdi)
    off_lidt = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_lidt", off_lidt)
    x86_synth_register_helper_fn(s, "lidt", off_lidt)
    x86_synth_emit_bytes(s, [15, 1, 31, 195])

    // cpu_sgdt(out_ptr=%rdi)
    off_sgdt = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_sgdt", off_sgdt)
    x86_synth_register_helper_fn(s, "sgdt", off_sgdt)
    x86_synth_emit_bytes(s, [15, 1, 7, 195])

    // cpu_sidt(out_ptr=%rdi)
    off_sidt = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_sidt", off_sidt)
    x86_synth_register_helper_fn(s, "sidt", off_sidt)
    x86_synth_emit_bytes(s, [15, 1, 15, 195])

    // cpu_ltr(tss_selector=%rdi)
    off_ltr = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_ltr", off_ltr)
    x86_synth_register_helper_fn(s, "ltr", off_ltr)
    x86_synth_emit_bytes(s, [15, 0, 223, 195])

    // CR0 / CR2 / CR3 / CR4
    off_rcr0 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_cr0", off_rcr0)
    x86_synth_register_helper_fn(s, "read_cr0", off_rcr0)
    x86_synth_emit_bytes(s, [15, 32, 192, 195])

    off_wcr0 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_write_cr0", off_wcr0)
    x86_synth_register_helper_fn(s, "write_cr0", off_wcr0)
    x86_synth_emit_bytes(s, [15, 34, 199, 195])

    off_rcr2 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_cr2", off_rcr2)
    x86_synth_register_helper_fn(s, "read_cr2", off_rcr2)
    x86_synth_emit_bytes(s, [15, 32, 208, 195])

    off_rcr3 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_cr3", off_rcr3)
    x86_synth_register_helper_fn(s, "read_cr3", off_rcr3)
    x86_synth_emit_bytes(s, [15, 32, 216, 195])

    off_wcr3 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_write_cr3", off_wcr3)
    x86_synth_register_helper_fn(s, "write_cr3", off_wcr3)
    x86_synth_emit_bytes(s, [15, 34, 223, 195])

    off_rcr4 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_cr4", off_rcr4)
    x86_synth_register_helper_fn(s, "read_cr4", off_rcr4)
    x86_synth_emit_bytes(s, [15, 32, 224, 195])

    off_wcr4 = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_write_cr4", off_wcr4)
    x86_synth_register_helper_fn(s, "write_cr4", off_wcr4)
    x86_synth_emit_bytes(s, [15, 34, 231, 195])

    // cpu_rdmsr(msr=%rdi) -> u64 in %rax
    off_rdmsr = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_rdmsr", off_rdmsr)
    x86_synth_register_helper_fn(s, "rdmsr", off_rdmsr)
    x86_synth_emit_bytes(s, [137, 249, 15, 50, 72, 193, 226, 32, 72, 9, 208, 195])

    // cpu_wrmsr(msr=%rdi, val=%rsi)
    off_wrmsr = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_wrmsr", off_wrmsr)
    x86_synth_register_helper_fn(s, "wrmsr", off_wrmsr)
    x86_synth_emit_bytes(s, [137, 249, 137, 240, 72, 137, 242, 72, 193, 234, 32, 15, 48, 195])

    // cpu_invlpg(vaddr=%rdi)
    off_invlpg = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_invlpg", off_invlpg)
    x86_synth_register_helper_fn(s, "invlpg", off_invlpg)
    x86_synth_emit_bytes(s, [15, 1, 63, 195])

    // cpu_swapgs()
    off_swapgs = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_swapgs", off_swapgs)
    x86_synth_register_helper_fn(s, "swapgs", off_swapgs)
    x86_synth_emit_bytes(s, [15, 1, 248, 195])

    // cpu_wbinvd()
    off_wbinvd = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_wbinvd", off_wbinvd)
    x86_synth_emit_bytes(s, [15, 9, 195])

    // cpu_rdtsc() / cpu_rdcycle() / cpu_rdtime() -> u64 timestamp counter
    off_rdtsc = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_rdtsc", off_rdtsc)
    x86_synth_register_helper_fn(s, "rdtsc", off_rdtsc)
    x86_synth_register_helper_fn(s, "cpu_rdcycle", off_rdtsc)
    x86_synth_register_helper_fn(s, "cpu_rdtime", off_rdtsc)
    x86_synth_emit_bytes(s, [15, 49, 72, 193, 226, 32, 72, 9, 208, 195])

    // cpu_read_rflags() -> u64 RFLAGS
    off_rf = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_rflags", off_rf)
    x86_synth_register_helper_fn(s, "read_rflags", off_rf)
    x86_synth_emit_bytes(s, [156, 88, 195])

    // cpu_read_rsp() -> u64 current RSP
    off_rsp = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_read_rsp", off_rsp)
    if s.synth_freestanding == 1
        x86_synth_register_helper_fn(s, "stack_pointer", off_rsp)
    end
    x86_synth_emit_bytes(s, [72, 137, 224, 195])

    // cpu_cpuid(leaf=%rdi, subleaf=%rsi, out_buf=%rdx) -> %eax; stores [eax,ebx,ecx,edx] as 4x u32 if out_buf != 0
    off_cpuid = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_cpuid", off_cpuid)
    x86_synth_register_helper_fn(s, "cpuid", off_cpuid)
    x86_synth_emit_bytes(s, [
        83,                       // push rbx
        73, 137, 208,             // mov r8, rdx
        137, 248,                 // mov eax, edi
        137, 241,                 // mov ecx, esi
        15, 162,                  // cpuid
        77, 133, 192,             // test r8, r8
        116, 15,                  // jz +15
        65, 137, 0,               // mov [r8], eax
        65, 137, 88, 4,           // mov [r8+4], ebx
        65, 137, 72, 8,           // mov [r8+8], ecx
        65, 137, 80, 12,          // mov [r8+12], edx
        91,                       // pop rbx
        195                       // ret
    ])

    // uefi_call(fn_ptr=%rdi, a1=%rsi, a2=%rdx, a3=%rcx, a4=%r8, a5=%r9) -> MS x64 ABI return in %rax
    // WHY: Allows pure-Lipi UEFI applications to call EFI_BOOT_SERVICES / ConOut / GOP function
    // pointers directly under Microsoft x64 ABI (rcx, rdx, r8, r9 + [rsp+32] + 32B shadow space).
    off_uefi = s.synth_code.len()
    x86_synth_register_helper_fn(s, "uefi_call", off_uefi)
    x86_synth_register_helper_fn(s, "ms_x64_call", off_uefi)
    x86_synth_emit_bytes(s, [
        85,                       // push rbp
        72, 137, 229,             // mov rbp, rsp
        72, 131, 228, 240,        // and rsp, -16
        72, 131, 236, 48,         // sub rsp, 48 (32B shadow + 8B arg5 + 8B align)
        72, 137, 248,             // mov rax, rdi (fn_ptr)
        76, 137, 76, 36, 32,      // mov [rsp+32], r9 (arg5)
        77, 137, 193,             // mov r9, r8 (arg4)
        73, 137, 200,             // mov r8, rcx (arg3)
        72, 137, 241,             // mov rcx, rsi (arg1; rdx is already arg2)
        255, 208,                 // call rax
        72, 137, 236,             // mov rsp, rbp
        93,                       // pop rbp
        195                       // ret
    ])

    // Cross-arch firmware traps (ARM64 PSCI & RISC-V OpenSBI) return NOT_SUPPORTED (-2) on x86_64
    // WHY: Allows multi-architecture utso/silicon/{gic,pl011,opensbi}.lp drivers to compile cleanly on x86_64 hosts.
    off_fw_nosys = s.synth_code.len()
    x86_synth_register_helper_fn(s, "psci_call", off_fw_nosys)
    x86_synth_register_helper_fn(s, "sbi_ecall", off_fw_nosys)
    x86_synth_register_helper_fn(s, "sbi_ecall_val", off_fw_nosys)
    x86_synth_emit_bytes(s, [72, 199, 192, 254, 255, 255, 255, 195]) // mov rax, -2; ret

    // sbi_ecall_ret(eid=%rdi, fid=%rsi, out_val_ptr=%rdx, ...) -> zero *out_val_ptr if non-null, return -2
    off_sbi_ret_nosys = s.synth_code.len()
    x86_synth_register_helper_fn(s, "sbi_ecall_ret", off_sbi_ret_nosys)
    x86_synth_emit_bytes(s, [72, 133, 210, 116, 7, 72, 199, 2, 0, 0, 0, 0, 72, 199, 192, 254, 255, 255, 255, 195])
    return 0

fn x86_synth_emit_all_silicon_helpers s
    // WHY: Emits the complete zero-syscall Ring-0 silicon & hardware intrinsic library.
    x86_synth_emit_silicon_port_io(s)
    x86_synth_emit_silicon_mmio(s)
    x86_synth_emit_silicon_atomics_and_fences(s)
    x86_synth_emit_silicon_cpu_control(s)
    return 0

fn x86_synth_emit_inline_asm_mnemonic s mnem
    // WHY: Sovereign Lipi @asm structured instruction emitter (zero external assembler).
    if mnem == "nop"
        x86_synth_emit_byte(s, 144)
    elif mnem == "cli"
        x86_synth_emit_byte(s, 250)
    elif mnem == "sti"
        x86_synth_emit_byte(s, 251)
    elif mnem == "hlt"
        x86_synth_emit_byte(s, 244)
    elif mnem == "ret"
        x86_synth_emit_byte(s, 195)
    elif mnem == "iretq"
        x86_synth_emit_bytes(s, [72, 207])
    elif mnem == "pause"
        x86_synth_emit_bytes(s, [243, 144])
    elif mnem == "mfence"
        x86_synth_emit_bytes(s, [15, 174, 240])
    elif mnem == "sfence"
        x86_synth_emit_bytes(s, [15, 174, 248])
    elif mnem == "lfence"
        x86_synth_emit_bytes(s, [15, 174, 232])
    elif mnem == "swapgs"
        x86_synth_emit_bytes(s, [15, 1, 248])
    elif mnem == "wbinvd"
        x86_synth_emit_bytes(s, [15, 9])
    elif mnem == "ud2"
        x86_synth_emit_bytes(s, [15, 11])
    elif mnem == "cld"
        x86_synth_emit_byte(s, 252)
    elif mnem == "std"
        x86_synth_emit_byte(s, 253)
    elif mnem == "syscall"
        x86_synth_emit_bytes(s, [15, 5])
    elif mnem == "sysretq"
        x86_synth_emit_bytes(s, [72, 15, 7])
    elif mnem == "leave"
        x86_synth_emit_byte(s, 201)
    elif mnem == "cpuid"
        x86_synth_emit_bytes(s, [15, 162])
    elif mnem == "rdtsc"
        x86_synth_emit_bytes(s, [15, 49])
    elif mnem == "pushfq"
        x86_synth_emit_byte(s, 156)
    elif mnem == "popfq"
        x86_synth_emit_byte(s, 157)
    elif mnem == "int3"
        x86_synth_emit_byte(s, 204)
    elif mnem == "xor_eax_eax"
        x86_synth_emit_bytes(s, [49, 192])
    else
        say "❌ [Silicon @asm Error]: Unknown mnemonic '" + mnem + "' — use raw byte array @asm [b0, b1, ...] or a supported mnemonic."
        exit(1)
    end
    return 0

fn x86_synth_compile_asm_stmt s toks pos_box
    // WHY: Compiles `@asm [0xFA, 0xF4]` raw opcode byte blocks AND `@asm { cli; hlt; mfence }`
    // structured mnemonic blocks directly into the native silicon code stream.
    list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume @asm
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    p = get(pos_box, 0)
    if p >= toks.len()
        return 0
    end
    t = toks[p]
    if t.tok_kind == TOK_LBRACKET() or (t.tok_kind != TOK_STR() and t.tok_text == "[")
        list_set(pos_box, 0, p + 1)
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cp = get(pos_box, 0)
            if cp >= toks.len() break end
            ct = toks[cp]
            if ct.tok_kind == TOK_RBRACKET() or (ct.tok_kind != TOK_STR() and ct.tok_text == "]")
                list_set(pos_box, 0, cp + 1)
                break
            elif ct.tok_kind == TOK_COMMA() or (ct.tok_kind != TOK_STR() and ct.tok_text == ",")
                list_set(pos_box, 0, cp + 1)
            elif ct.tok_kind == TOK_INT()
                x86_synth_emit_byte(s, ct.tok_int_val & 255)
                list_set(pos_box, 0, cp + 1)
            else
                list_set(pos_box, 0, cp + 1)
            end
        end
        s.synth_last_store_end = 0 - 1
        return 0
    elif t.tok_kind == TOK_LBRACE() or (t.tok_kind != TOK_STR() and t.tok_text == "{")
        list_set(pos_box, 0, p + 1)
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cp = get(pos_box, 0)
            if cp >= toks.len() break end
            ct = toks[cp]
            if ct.tok_kind == TOK_RBRACE() or (ct.tok_kind != TOK_STR() and ct.tok_text == "}")
                list_set(pos_box, 0, cp + 1)
                break
            elif ct.tok_kind == TOK_COMMA() or ct.tok_kind == TOK_SEMI() or (ct.tok_kind != TOK_STR() and (ct.tok_text == "," or ct.tok_text == ";"))
                list_set(pos_box, 0, cp + 1)
            elif ct.tok_kind == TOK_INT()
                x86_synth_emit_byte(s, ct.tok_int_val & 255)
                list_set(pos_box, 0, cp + 1)
            elif ct.tok_kind == TOK_STR() or x86_synth_is_ident_token(ct.tok_kind) == 1
                x86_synth_emit_inline_asm_mnemonic(s, ct.tok_text)
                list_set(pos_box, 0, cp + 1)
            else
                list_set(pos_box, 0, cp + 1)
            end
        end
        s.synth_last_store_end = 0 - 1
        return 0
    elif t.tok_kind == TOK_STR() or x86_synth_is_ident_token(t.tok_kind) == 1
        x86_synth_emit_inline_asm_mnemonic(s, t.tok_text)
        list_set(pos_box, 0, p + 1)
        s.synth_last_store_end = 0 - 1
        return 0
    end
    return 0
