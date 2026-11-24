// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN SCOPED ARENA MEMORY HELPERS (runtime_arena.lp)
// ⚡ 100% Pure Silicon AMD64 Machine Code | 0% C | 0% Libc | 0% GC Pause
// 🏛️ Module: src/compiler/backend/targets/x86_64/runtime_arena.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Escapes the mainstream dual death traps:
//    - Avoids Rust's cognitive torture of lifetime annotations (&'a mut T).
//    - Avoids Go/Java's unpredictable Stop-the-World garbage collection latency spikes.
// 2. Implements pure hardware-aligned bump-pointer scoped arena mechanics:
//    - arena_mark() captures current allocation watermark in 1 CPU cycle.
//    - arena_reset(mark) rolls back all transient allocations instantly without individual free calls.
//    - arena_free_all() flushes the entire 1GB arena back to base.
// 3. Guaranteed Memory Bounds Safety:
//    - Validates that rollbacks never stray below _heap_base or above current _heap_ptr.
// ==============================================================================

fn x86_synth_emit_arena_helpers s
    // WHY: Emits native AMD64 instructions implementing scoped arena lifecycle.
    // Returns list of byte offsets [mark_off, reset_off, free_off, size_off] for patch phase.

    // ──────────────────────────────────────────────────────────────────────────
    // 1. _lipi_arena_mark() / arena_mark() / অ্যারেনা_চিহ্ন()
    // Returns current _heap_ptr watermark in %rax.
    // ──────────────────────────────────────────────────────────────────────────
    mark_off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_arena_mark", mark_off)
    x86_synth_register_helper_fn(s, "arena_mark", mark_off)
    x86_synth_register_helper_fn(s, "অ্যারেনা_চিহ্ন", mark_off)

    mark_bytes = [
        85,                                            // 0: push rbp
        72, 137, 229,                                  // 1..3: mov rbp, rsp
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,               // 4..13: movabs rax, <heap_base_addr> (patch at mark_off + 6)
        72, 139, 0,                                    // 14..16: mov rax, [rax]
        72, 133, 192,                                  // 17..19: test rax, rax
        117, 12,                                       // 20..21: jnz .mark_ready (rel +12 -> to index 34)
        49, 255,                                       // 22..23: xor edi, edi (trigger initial mmap)
        232, 0, 0, 0, 0,                               // 24..28: call rel32 (__alloc) (patch at mark_off + 25)
        144,                                           // 29: nop (pad)
        144, 144, 144, 144,                            // 30..33: nop
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,               // 34..43: .mark_ready: movabs rax, <heap_ptr_addr> (patch at mark_off + 36)
        72, 139, 0,                                    // 44..46: mov rax, [rax]
        93,                                            // 47: pop rbp
        195                                            // 48: ret
    ]
    x86_synth_emit_bytes(s, mark_bytes)

    alloc_rel = X86CallReloc()
    alloc_rel.cr_patch_offset = mark_off + 25
    alloc_rel.cr_call_site_end = mark_off + 29
    alloc_rel.cr_target_name = "__alloc"
    push(s.synth_call_relocs, alloc_rel)

    // ──────────────────────────────────────────────────────────────────────────
    // 2. _lipi_arena_reset(saved_mark) / arena_reset() / অ্যারেনা_রিসেট()
    // Inputs: %rdi = target watermark. Output: %rax = 0 on success, -1 on invalid bounds.
    // ──────────────────────────────────────────────────────────────────────────
    reset_off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_arena_reset", reset_off)
    x86_synth_register_helper_fn(s, "arena_reset", reset_off)
    x86_synth_register_helper_fn(s, "arena_rollback", reset_off)
    x86_synth_register_helper_fn(s, "_lipi_arena_rollback", reset_off)
    x86_synth_register_helper_fn(s, "অ্যারেনা_রিসেট", reset_off)

    reset_bytes = [
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 0, 72, 57, 199, 15, 130, 235, 0, 0, 0, 72, 186, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 10, 72, 57, 207, 15, 135, 213, 0, 0, 0, 73, 137, 203, 72, 137, 58, 240, 72, 15, 186, 106, 104, 0, 114, 247, 69, 49, 192, 73, 131, 248, 9, 115, 36, 78, 141, 76, 194, 8, 77, 139, 17, 77, 133, 210, 116, 18, 73, 57, 250, 115, 5, 77, 137, 209, 235, 238, 77, 139, 18, 77, 137, 17, 235, 230, 73, 255, 192, 235, 214, 76, 141, 74, 112, 77, 139, 17, 77, 133, 210, 116, 36, 73, 131, 226, 252, 77, 133, 210, 116, 27, 73, 139, 66, 240, 72, 131, 224, 252, 73, 57, 250, 115, 9, 77, 141, 74, 240, 73, 137, 194, 235, 217, 73, 137, 1, 235, 212, 76, 141, 138, 168, 1, 0, 0, 77, 139, 17, 77, 133, 210, 116, 18, 73, 57, 250, 115, 5, 77, 137, 209, 235, 238, 77, 139, 18, 77, 137, 17, 235, 230, 240, 72, 15, 186, 114, 104, 0, 76, 137, 222, 72, 41, 254, 72, 129, 254, 0, 0, 1, 0, 114, 47, 72, 141, 135, 255, 15, 0, 0, 72, 37, 0, 240, 255, 255, 73, 141, 179, 255, 15, 0, 0, 72, 129, 230, 0, 240, 255, 255, 72, 41, 198, 118, 15, 72, 137, 199, 186, 4, 0, 0, 0, 184, 28, 0, 0, 0, 15, 5, 49, 192, 195, 72, 199, 192, 255, 255, 255, 255, 195
    ]
    x86_synth_emit_bytes(s, reset_bytes)

    // ──────────────────────────────────────────────────────────────────────────
    // 3. _lipi_arena_free_all() / arena_free_all() / অ্যারেনা_সব_খালি()
    // Flushes the bump arena back to _heap_base and returns physical pages via SYS_madvise(MADV_DONTNEED).
    // ──────────────────────────────────────────────────────────────────────────
    free_off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_arena_free_all", free_off)
    x86_synth_register_helper_fn(s, "arena_free_all", free_off)
    x86_synth_register_helper_fn(s, "অ্যারেনা_সব_খালি", free_off)

    free_bytes = [
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 0, 72, 186, 0, 0, 0, 0, 0, 0, 0, 0, 76, 139, 26, 72, 137, 2, 240, 72, 15, 186, 106, 104, 0, 114, 247, 49, 201, 72, 131, 249, 9, 115, 14, 72, 199, 68, 202, 8, 0, 0, 0, 0, 72, 255, 193, 235, 236, 72, 199, 66, 112, 0, 0, 0, 0, 72, 199, 130, 128, 1, 0, 0, 0, 0, 0, 0, 72, 199, 130, 168, 1, 0, 0, 0, 0, 0, 0, 240, 72, 15, 186, 114, 104, 0, 72, 133, 192, 116, 45, 72, 141, 184, 255, 15, 0, 0, 72, 129, 231, 0, 240, 255, 255, 73, 141, 179, 255, 15, 0, 0, 72, 129, 230, 0, 240, 255, 255, 72, 41, 254, 118, 12, 186, 4, 0, 0, 0, 184, 28, 0, 0, 0, 15, 5, 49, 192, 195
    ]
    x86_synth_emit_bytes(s, free_bytes)

    // ──────────────────────────────────────────────────────────────────────────
    // 4. _lipi_arena_allocated() / arena_allocated() / অ্যারেনা_ব্যবহৃত()
    // Returns total bytes currently active in arena (%rax = _heap_ptr - _heap_base).
    // ──────────────────────────────────────────────────────────────────────────
    alloc_size_off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_arena_allocated", alloc_size_off)
    x86_synth_register_helper_fn(s, "arena_allocated", alloc_size_off)
    x86_synth_register_helper_fn(s, "অ্যারেনা_ব্যবহৃত", alloc_size_off)

    size_bytes = [
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,               // 0..9: movabs rax, <heap_base_addr> (patch at alloc_size_off + 2)
        72, 139, 0,                                    // 10..12: mov rax, [rax] (_heap_base)
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,               // 13..22: movabs rdx, <heap_ptr_addr> (patch at alloc_size_off + 15)
        72, 139, 18,                                   // 23..25: mov rdx, [rdx] (_heap_ptr)
        72, 41, 194,                                   // 26..28: sub rdx, rax (_heap_ptr - _heap_base)
        72, 137, 208,                                  // 29..31: mov rax, rdx
        195                                            // 32: ret
    ]
    x86_synth_emit_bytes(s, size_bytes)

    res = list()
    push(res, mark_off)
    push(res, reset_off)
    push(res, free_off)
    push(res, alloc_size_off)
    return res

fn x86_synth_patch_arena_helpers s arena_offs heap_base_vaddr heap_ptr_vaddr
    // WHY: Resolves the 64-bit absolute virtual addresses of _heap_base and _heap_ptr
    // into the emitted arena helper machine code.
    if arena_offs.len() >= 4
        m_off = arena_offs[0]
        r_off = arena_offs[1]
        f_off = arena_offs[2]
        s_off = arena_offs[3]

        if m_off > 0
            x86_synth_patch_u64(s, m_off + 6, heap_base_vaddr)
            x86_synth_patch_u64(s, m_off + 36, heap_ptr_vaddr)

        if r_off > 0
            x86_synth_patch_u64(s, r_off + 2, heap_base_vaddr)
            x86_synth_patch_u64(s, r_off + 24, heap_ptr_vaddr)

        if f_off > 0
            x86_synth_patch_u64(s, f_off + 2, heap_base_vaddr)
            x86_synth_patch_u64(s, f_off + 15, heap_ptr_vaddr)

        if s_off > 0
            x86_synth_patch_u64(s, s_off + 2, heap_base_vaddr)
            x86_synth_patch_u64(s, s_off + 15, heap_ptr_vaddr)

    return 0
