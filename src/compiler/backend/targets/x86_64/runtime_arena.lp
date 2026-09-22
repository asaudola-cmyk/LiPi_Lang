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
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,               // 0..9: movabs rax, <heap_base_addr> (patch at reset_off + 2)
        72, 139, 0,                                    // 10..12: mov rax, [rax] (_heap_base)
        72, 57, 199,                                   // 13..15: cmp rdi, rax
        114, 25,                                       // 16..17: jb .invalid (+25 -> index 43)
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,               // 18..27: movabs rdx, <heap_ptr_addr> (patch at reset_off + 20)
        72, 139, 8,                                    // 28..30: mov rcx, [rdx] (current _heap_ptr)
        72, 57, 207,                                   // 31..33: cmp rdi, rcx
        119, 9,                                        // 34..35: ja .invalid (+9 -> index 45)
        72, 137, 58,                                   // 36..38: mov [rdx], rdi (update _heap_ptr = saved_mark!)
        49, 192,                                       // 39..40: xor eax, eax (success code 0)
        195,                                           // 41: ret
        144, 144, 144,                                 // 42..44: nop
        72, 199, 192, 255, 255, 255, 255,              // 45..51: .invalid: mov rax, -1
        195                                            // 52: ret
    ]
    x86_synth_emit_bytes(s, reset_bytes)

    // ──────────────────────────────────────────────────────────────────────────
    // 3. _lipi_arena_free_all() / arena_free_all() / অ্যারেনা_সব_খালি()
    // Flushes the entire 1GB bump arena back to _heap_base. Output: %rax = 0.
    // ──────────────────────────────────────────────────────────────────────────
    free_off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_arena_free_all", free_off)
    x86_synth_register_helper_fn(s, "arena_free_all", free_off)
    x86_synth_register_helper_fn(s, "অ্যারেনা_সব_খালি", free_off)

    free_bytes = [
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,               // 0..9: movabs rax, <heap_base_addr> (patch at free_off + 2)
        72, 139, 0,                                    // 10..12: mov rax, [rax] (_heap_base)
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,               // 13..22: movabs rdx, <heap_ptr_addr> (patch at free_off + 15)
        72, 137, 2,                                    // 23..25: mov [rdx], rax (reset _heap_ptr = _heap_base)
        49, 192,                                       // 26..27: xor eax, eax (return 0)
        195                                            // 28: ret
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
            x86_synth_patch_u64(s, r_off + 20, heap_ptr_vaddr)

        if f_off > 0
            x86_synth_patch_u64(s, f_off + 2, heap_base_vaddr)
            x86_synth_patch_u64(s, f_off + 15, heap_ptr_vaddr)

        if s_off > 0
            x86_synth_patch_u64(s, s_off + 2, heap_base_vaddr)
            x86_synth_patch_u64(s, s_off + 15, heap_ptr_vaddr)

    return 0
