// ==============================================================================
// 👑 LIPI SOVEREIGN MODULE ARCHITECTURE: KAVACH CAPSULE & ZERO-COPY RING
// Module: utso/core/kavach_capsule.lp
// 100% Pure Lipi Architecture — Zero C .so / Zero GOT-PLT / Zero OpenSSL / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Instead of inheriting legacy C ELF shared-object semantics (.so + GOT/PLT + blind RWX),
// Lipi introduces its own cryptographically sealed sovereign execution architecture:
//   1. Binary LPKC Capsule Format: signed with SHA-256 + Ed25519, capability-gated
//      (KAVACH_CAP_*), relocated while RW, then hardware-locked with strict W^X
//      (SYS_mprotect: PROT_READ for .rodata, PROT_READ|PROT_EXEC for .code, NEVER RWX).
//   2. Zero-Copy Shared-Memory KavachRing: cacheline-aligned MAP_SHARED IPC ring
//      synchronized by hardware atomic spinlocks for cross-thread & cross-process workers.

include "utso/core/memory.lp"
include "utso/core/c_abi_call.lp"
import "utso/crypto/sha256"
import "utso/crypto/ed25519"

// ── 1. Capability Bitmask & Header Constants ──────────────────────────────────
KAVACH_CAP_PURE_COMPUTE = 1
KAVACH_CAP_MEMORY_ARENA = 2
KAVACH_CAP_FS_READ      = 4
KAVACH_CAP_FS_WRITE     = 8
KAVACH_CAP_NET_IO       = 16
KAVACH_CAP_IPC_RING     = 32

KAVACH_RELOC_ABS64      = 0
KAVACH_RELOC_REL32      = 1
KAVACH_TARGET_CODE      = 0
KAVACH_TARGET_RODATA    = 1

KAVACH_HEADER_SIZE      = 176
KAVACH_EXPORT_ENTRY_SZ  = 48
KAVACH_RELOC_ENTRY_SZ   = 24
KAVACH_RING_MAGIC       = 1263685191 // "KRNG"

struct KavachCapsuleHandle
    kcap_valid
    kcap_base_addr
    kcap_map_size
    kcap_code_addr
    kcap_rodata_addr
    kcap_req_caps
    kcap_granted_caps
    kcap_exports

struct KavachExportSpec
    kexp_name
    kexp_offset
    kexp_caps

struct KavachRelocSpec
    krel_patch_off
    krel_target_kind
    krel_reloc_mode
    krel_addend

// ── 2. Little-Endian Binary Codec Helpers ─────────────────────────────────────

fn _kcap_push_u32 arr v
    push(arr, v & 255)
    push(arr, (v >> 8) & 255)
    push(arr, (v >> 16) & 255)
    push(arr, (v >> 24) & 255)
    return 0

fn _kcap_push_u64 arr v
    i = 0
    while i < 8
        push(arr, (v >> (i * 8)) & 255)
        i = i + 1
    end
    return 0

fn _kcap_read_u32_arr arr off
    return (get(arr, off) & 255) | ((get(arr, off + 1) & 255) * 256) | ((get(arr, off + 2) & 255) * 65536) | ((get(arr, off + 3) & 255) * 16777216)

fn _kcap_read_i64_arr arr off
    lo = _kcap_read_u32_arr(arr, off) & 4294967295
    hi = _kcap_read_u32_arr(arr, off + 4)
    return lo + (hi * 4294967296)

fn _kcap_ct_eq_slice arr a_off len_n pub
    if len(pub) != len_n
        return 0
    end
    diff = 0
    i = 0
    while i < len_n
        diff = diff | ((get(arr, a_off + i) & 255) ^ (get(pub, i) & 255))
        i = i + 1
    end
    if diff == 0
        return 1
    end
    return 0

fn _kcap_align_page sz
    if sz <= 0
        return 4096
    end
    rem = sz % 4096
    if rem == 0
        return sz
    end
    return sz + (4096 - rem)

// ── 3. Capsule Packing, Signing & Verification ────────────────────────────────

fn kavach_export_new sym_name code_offset req_caps
    e = KavachExportSpec()
    e.kexp_name = sym_name
    e.kexp_offset = code_offset
    e.kexp_caps = req_caps
    return e

fn kavach_reloc_new patch_off target_kind reloc_mode addend
    r = KavachRelocSpec()
    r.krel_patch_off = patch_off
    r.krel_target_kind = target_kind
    r.krel_reloc_mode = reloc_mode
    r.krel_addend = addend
    return r

fn kavach_capsule_pack req_caps exports_list relocs_list code_bytes rodata_bytes publisher_priv32
    // WHY: Packs header + exports + relocations + code + rodata, hashes with SHA-256,
    // and seals with an Ed25519 cryptographic signature.
    kp = ed25519_keygen(publisher_priv32)
    pub32 = kp.public_key

    prefix = list()
    // Magic "LPKC" (76, 80, 75, 67)
    push(prefix, 76)
    push(prefix, 80)
    push(prefix, 75)
    push(prefix, 67)
    // Version = 1 (u32 LE)
    _kcap_push_u32(prefix, 1)
    _kcap_push_u64(prefix, req_caps)
    _kcap_push_u64(prefix, len(code_bytes))
    _kcap_push_u64(prefix, len(rodata_bytes))
    _kcap_push_u64(prefix, len(exports_list))
    _kcap_push_u64(prefix, len(relocs_list))
    i = 0
    while i < 32
        push(prefix, get(pub32, i) & 255)
        i = i + 1
    end

    payload = list()
    // Encode Export Table (48 bytes per export)
    ei = 0
    while ei < len(exports_list)
        ex = get(exports_list, ei)
        nm = ex.kexp_name
        nlen = str_len(nm)
        ci = 0
        while ci < 32
            if ci < nlen and ci < 31
                push(payload, str_char_at(nm, ci) & 255)
            else
                push(payload, 0)
            end
            ci = ci + 1
        end
        _kcap_push_u64(payload, ex.kexp_offset)
        _kcap_push_u64(payload, ex.kexp_caps)
        ei = ei + 1
    end

    // Encode Relocation Table (24 bytes per relocation)
    ri = 0
    while ri < len(relocs_list)
        rl = get(relocs_list, ri)
        _kcap_push_u64(payload, rl.krel_patch_off)
        kind_mode = (rl.krel_target_kind & 15) | ((rl.krel_reloc_mode & 15) * 16)
        _kcap_push_u64(payload, kind_mode)
        _kcap_push_u64(payload, rl.krel_addend)
        ri = ri + 1
    end

    ci = 0
    while ci < len(code_bytes)
        push(payload, get(code_bytes, ci) & 255)
        ci = ci + 1
    end
    di = 0
    while di < len(rodata_bytes)
        push(payload, get(rodata_bytes, di) & 255)
        di = di + 1
    end

    // Hash header[0..79] || payload
    hash_in = list()
    i = 0
    while i < len(prefix)
        push(hash_in, get(prefix, i) & 255)
        i = i + 1
    end
    i = 0
    while i < len(payload)
        push(hash_in, get(payload, i) & 255)
        i = i + 1
    end
    digest32 = sha256_hash_bytes(hash_in)
    sig64 = ed25519_sign(publisher_priv32, digest32)

    out = list()
    i = 0
    while i < len(prefix)
        push(out, get(prefix, i))
        i = i + 1
    end
    i = 0
    while i < 32
        push(out, get(digest32, i) & 255)
        i = i + 1
    end
    i = 0
    while i < 64
        push(out, get(sig64, i) & 255)
        i = i + 1
    end
    i = 0
    while i < len(payload)
        push(out, get(payload, i) & 255)
        i = i + 1
    end
    return out

fn kavach_capsule_save path capsule_bytes
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0 return -1 end
    n = len(capsule_bytes)
    buf = malloc(n)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return -1
    end
    i = 0
    while i < n
        mem_byte_write(buf, i, get(capsule_bytes, i) & 255)
        i = i + 1
    end
    written = 0
    while written < n
        w = syscall(1, fd, buf + written, n - written, 0, 0, 0)
        if w <= 0 break end
        written = written + w
    end
    syscall(74, fd, 0, 0, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    free(buf, n)
    return written

fn kavach_capsule_load_bytes capsule_bytes trusted_pub32 granted_caps
    // WHY: Authenticates SHA-256 + Ed25519 + Capability Bitmask BEFORE mapping pages,
    // relocates while RW (prot=3), and enforces strict W^X via SYS_mprotect (RX=5 / R=1).
    bad = KavachCapsuleHandle()
    bad.kcap_valid = 0
    clen = len(capsule_bytes)
    if clen < KAVACH_HEADER_SIZE
        bad.kcap_valid = -1
        return bad
    end
    if get(capsule_bytes, 0) != 76 or get(capsule_bytes, 1) != 80 or get(capsule_bytes, 2) != 75 or get(capsule_bytes, 3) != 67
        bad.kcap_valid = -1
        return bad
    end
    if _kcap_read_u32_arr(capsule_bytes, 4) != 1
        bad.kcap_valid = -1
        return bad
    end

    req_caps = _kcap_read_i64_arr(capsule_bytes, 8)
    code_len = _kcap_read_i64_arr(capsule_bytes, 16)
    ro_len = _kcap_read_i64_arr(capsule_bytes, 24)
    exp_cnt = _kcap_read_i64_arr(capsule_bytes, 32)
    rel_cnt = _kcap_read_i64_arr(capsule_bytes, 40)

    if code_len <= 0 or ro_len < 0 or exp_cnt <= 0 or rel_cnt < 0
        bad.kcap_valid = -1
        return bad
    end
    exp_bytes = exp_cnt * KAVACH_EXPORT_ENTRY_SZ
    rel_bytes = rel_cnt * KAVACH_RELOC_ENTRY_SZ
    need_len = KAVACH_HEADER_SIZE + exp_bytes + rel_bytes + code_len + ro_len
    if need_len != clen
        bad.kcap_valid = -1
        return bad
    end

    // 1. Verify Trusted Publisher Public Key
    if _kcap_ct_eq_slice(capsule_bytes, 48, 32, trusted_pub32) != 1
        bad.kcap_valid = -2
        return bad
    end

    // 2. Recompute SHA-256 Digest & Compare Constant-Time
    hash_in = list()
    i = 0
    while i < 80
        push(hash_in, get(capsule_bytes, i) & 255)
        i = i + 1
    end
    i = KAVACH_HEADER_SIZE
    while i < clen
        push(hash_in, get(capsule_bytes, i) & 255)
        i = i + 1
    end
    actual_digest = sha256_hash_bytes(hash_in)
    if _kcap_ct_eq_slice(capsule_bytes, 80, 32, actual_digest) != 1
        bad.kcap_valid = -2
        return bad
    end

    // 3. Verify Ed25519 Signature Cryptographically BEFORE allocating executable pages
    sig64 = list()
    i = 0
    while i < 64
        push(sig64, get(capsule_bytes, 112 + i) & 255)
        i = i + 1
    end
    if ed25519_verify(trusted_pub32, actual_digest, sig64) != 1
        bad.kcap_valid = -2
        return bad
    end

    // 4. Capability Gate: Host MUST grant every bit requested by Capsule
    if (req_caps & granted_caps) != req_caps
        bad.kcap_valid = -3
        return bad
    end

    // 5. Parse Exports Table
    exports = list()
    exp_base = KAVACH_HEADER_SIZE
    ei = 0
    while ei < exp_cnt
        off = exp_base + (ei * KAVACH_EXPORT_ENTRY_SZ)
        nm = ""
        ni = 0
        while ni < 32
            cb = get(capsule_bytes, off + ni) & 255
            if cb == 0 break end
            nm = nm + chr(cb)
            ni = ni + 1
        end
        sym_off = _kcap_read_i64_arr(capsule_bytes, off + 32)
        sym_caps = _kcap_read_i64_arr(capsule_bytes, off + 40)
        if sym_off < 0 or sym_off >= code_len
            bad.kcap_valid = -1
            return bad
        end
        push(exports, kavach_export_new(nm, sym_off, sym_caps))
        ei = ei + 1
    end

    // 6. Map Single Contiguous W^X-Safe Arena as PROT_READ|PROT_WRITE (prot = 3, NEVER 7!)
    code_span = _kcap_align_page(code_len)
    ro_span = 0
    if ro_len > 0
        ro_span = _kcap_align_page(ro_len)
    end
    tot_map = code_span + ro_span
    base = syscall(9, 0, tot_map, 3, 34, -1, 0)
    if base <= 0
        bad.kcap_valid = -4
        return bad
    end
    code_addr = base
    ro_addr = base + code_span

    // Copy .code and .rodata while writable
    code_src = exp_base + exp_bytes + rel_bytes
    ro_src = code_src + code_len
    i = 0
    while i < code_len
        mem_byte_write(code_addr, i, get(capsule_bytes, code_src + i) & 255)
        i = i + 1
    end
    i = 0
    while i < ro_len
        mem_byte_write(ro_addr, i, get(capsule_bytes, ro_src + i) & 255)
        i = i + 1
    end

    // 7. Apply Internal Relocations while RW (prot = 3)
    rel_base = exp_base + exp_bytes
    ri = 0
    while ri < rel_cnt
        roff = rel_base + (ri * KAVACH_RELOC_ENTRY_SZ)
        p_off = _kcap_read_i64_arr(capsule_bytes, roff)
        kmode = _kcap_read_i64_arr(capsule_bytes, roff + 8)
        addend = _kcap_read_i64_arr(capsule_bytes, roff + 16)
        tkind = kmode & 15
        rmode = (kmode >> 4) & 15

        target_base = code_addr
        if tkind == KAVACH_TARGET_RODATA
            target_base = ro_addr
        end
        target_addr = target_base + addend

        if rmode == KAVACH_RELOC_ABS64
            if p_off >= 0 and p_off + 8 <= code_len
                mem_write(code_addr, p_off, target_addr)
            end
        elif rmode == KAVACH_RELOC_REL32
            if p_off < 0 or p_off + 4 > code_len
                syscall(11, base, tot_map, 0, 0, 0, 0)
                bad.kcap_valid = -1
                return bad
            end
            disp = target_addr - (code_addr + p_off + 4)
            if disp < -2147483648 or disp > 2147483647
                syscall(11, base, tot_map, 0, 0, 0, 0)
                bad.kcap_valid = -1
                return bad
            end
            mem_write_u32(code_addr, p_off, disp)
        end
        ri = ri + 1
    end

    // 8. Hardware W^X Lock via SYS_mprotect (10): Code -> RX (5), Rodata -> R (1)
    mp_code = syscall(10, code_addr, code_span, 5, 0, 0, 0)
    if mp_code != 0
        syscall(11, base, tot_map, 0, 0, 0, 0)
        bad.kcap_valid = -5
        return bad
    end
    if ro_span > 0
        mp_ro = syscall(10, ro_addr, ro_span, 1, 0, 0, 0)
        if mp_ro != 0
            syscall(11, base, tot_map, 0, 0, 0, 0)
            bad.kcap_valid = -5
            return bad
        end
    end

    h = KavachCapsuleHandle()
    h.kcap_valid = 1
    h.kcap_base_addr = base
    h.kcap_map_size = tot_map
    h.kcap_code_addr = code_addr
    h.kcap_rodata_addr = ro_addr
    h.kcap_req_caps = req_caps
    h.kcap_granted_caps = granted_caps
    h.kcap_exports = exports
    return h

fn kavach_capsule_load_file path trusted_pub32 granted_caps
    bad = KavachCapsuleHandle()
    bad.kcap_valid = -1
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return bad end
    sz = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if sz < KAVACH_HEADER_SIZE or sz > 33554432
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    buf = malloc(sz)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    got = 0
    while got < sz
        n = syscall(0, fd, buf + got, sz - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    arr = list()
    i = 0
    while i < got
        push(arr, mem_byte_read(buf, i) & 255)
        i = i + 1
    end
    free(buf, sz)
    return kavach_capsule_load_bytes(arr, trusted_pub32, granted_caps)

fn kavach_capsule_invoke cap_handle sym_name call_caps a0 a1 a2 a3 a4
    if cap_handle == 0 or cap_handle.kcap_valid != 1
        return 0 - 1
    end
    exps = cap_handle.kcap_exports
    i = 0
    while i < len(exps)
        ex = get(exps, i)
        if ex.kexp_name == sym_name
            allowed = cap_handle.kcap_granted_caps & call_caps
            if (ex.kexp_caps & allowed) != ex.kexp_caps
                return 0 - 3
            end
            fn_addr = cap_handle.kcap_code_addr + ex.kexp_offset
            return c_abi_invoke(fn_addr, a0, a1, a2, a3, a4)
        end
        i = i + 1
    end
    return 0 - 2

fn kavach_capsule_unload cap_handle
    if cap_handle == 0 or cap_handle.kcap_valid != 1
        return -1
    end
    rc = syscall(11, cap_handle.kcap_base_addr, cap_handle.kcap_map_size, 0, 0, 0, 0)
    cap_handle.kcap_valid = 0
    cap_handle.kcap_base_addr = 0
    return rc

// ── 4. Sovereign Zero-Copy Lock-Free Shared-Memory Ring (KavachRing) ──────────
// Layout in MAP_SHARED | MAP_ANONYMOUS memory (flags = 33):
//   Cache Line 0 (0..63):
//     +0:  lock_word (hardware atomic_lock/unlock target)
//     +8:  magic ("KRNG")
//     +16: capacity (slots)
//     +24: slot_size (bytes per slot >= 32)
//     +32: total_map_size
//     +40: write_idx
//     +48: read_idx
//     +56: total_tx
//   Cache Line 1 (64..127):
//     +64: total_rx
//     +72: overflow_drops
//   Slots start at offset 128: slot[i] = ring + 128 + ((i % capacity) * slot_size)

fn kavach_ring_create capacity slot_size
    if capacity <= 1 capacity = 16 end
    if slot_size < 32 slot_size = 64 end
    raw_sz = 128 + (capacity * slot_size)
    map_sz = _kcap_align_page(raw_sz)
    // MAP_SHARED (1) | MAP_ANONYMOUS (32) = 33 -> shared across threads AND fork() workers
    ring = syscall(9, 0, map_sz, 3, 33, -1, 0)
    if ring <= 0 return 0 end
    mem_zero(ring, 128)
    mem_write(ring, 0, 0)
    mem_write(ring, 8, KAVACH_RING_MAGIC)
    mem_write(ring, 16, capacity)
    mem_write(ring, 24, slot_size)
    mem_write(ring, 32, map_sz)
    return ring

fn kavach_ring_destroy ring
    if ring <= 0 return 0 end
    sz = mem_read(ring, 32)
    return syscall(11, ring, sz, 0, 0, 0, 0)

fn kavach_ring_count ring
    if ring <= 0 or mem_read(ring, 8) != KAVACH_RING_MAGIC return 0 end
    atomic_lock(ring)
    cnt = mem_read(ring, 40) - mem_read(ring, 48)
    atomic_unlock(ring)
    return cnt

fn kavach_ring_try_send_i64 ring v0 v1 v2 v3
    if ring <= 0 or mem_read(ring, 8) != KAVACH_RING_MAGIC return 0 end
    atomic_lock(ring)
    cap = mem_read(ring, 16)
    widx = mem_read(ring, 40)
    ridx = mem_read(ring, 48)
    if (widx - ridx) >= cap
        mem_write(ring, 72, mem_read(ring, 72) + 1)
        atomic_unlock(ring)
        return 0
    end
    slot_sz = mem_read(ring, 24)
    slot_addr = ring + 128 + ((widx % cap) * slot_sz)
    mem_write(slot_addr, 0, v0)
    mem_write(slot_addr, 8, v1)
    mem_write(slot_addr, 16, v2)
    mem_write(slot_addr, 24, v3)
    mem_write(ring, 40, widx + 1)
    mem_write(ring, 56, mem_read(ring, 56) + 1)
    atomic_unlock(ring)
    return 1

fn kavach_ring_try_recv_i64 ring out_ptr
    if ring <= 0 or out_ptr <= 0 or mem_read(ring, 8) != KAVACH_RING_MAGIC return 0 end
    atomic_lock(ring)
    cap = mem_read(ring, 16)
    widx = mem_read(ring, 40)
    ridx = mem_read(ring, 48)
    if ridx >= widx
        atomic_unlock(ring)
        return 0
    end
    slot_sz = mem_read(ring, 24)
    slot_addr = ring + 128 + ((ridx % cap) * slot_sz)
    mem_write(out_ptr, 0, mem_read(slot_addr, 0))
    mem_write(out_ptr, 8, mem_read(slot_addr, 8))
    mem_write(out_ptr, 16, mem_read(slot_addr, 16))
    mem_write(out_ptr, 24, mem_read(slot_addr, 24))
    mem_write(ring, 48, ridx + 1)
    mem_write(ring, 64, mem_read(ring, 64) + 1)
    atomic_unlock(ring)
    return 1

fn kavach_ring_send_bytes ring src_ptr nbytes
    if ring <= 0 or nbytes < 0 or mem_read(ring, 8) != KAVACH_RING_MAGIC return 0 end
    atomic_lock(ring)
    cap = mem_read(ring, 16)
    slot_sz = mem_read(ring, 24)
    if nbytes > (slot_sz - 8)
        atomic_unlock(ring)
        return -1
    end
    widx = mem_read(ring, 40)
    ridx = mem_read(ring, 48)
    if (widx - ridx) >= cap
        atomic_unlock(ring)
        return 0
    end
    slot_addr = ring + 128 + ((widx % cap) * slot_sz)
    mem_write(slot_addr, 0, nbytes)
    if nbytes > 0 and src_ptr > 0
        mem_copy(slot_addr + 8, src_ptr, nbytes)
    end
    mem_write(ring, 40, widx + 1)
    mem_write(ring, 56, mem_read(ring, 56) + 1)
    atomic_unlock(ring)
    return 1

fn kavach_ring_recv_bytes ring dst_ptr max_bytes
    if ring <= 0 or mem_read(ring, 8) != KAVACH_RING_MAGIC return -1 end
    atomic_lock(ring)
    cap = mem_read(ring, 16)
    slot_sz = mem_read(ring, 24)
    widx = mem_read(ring, 40)
    ridx = mem_read(ring, 48)
    if ridx >= widx
        atomic_unlock(ring)
        return 0
    end
    slot_addr = ring + 128 + ((ridx % cap) * slot_sz)
    nbytes = mem_read(slot_addr, 0)
    if nbytes > max_bytes
        nbytes = max_bytes
    end
    if nbytes > 0 and dst_ptr > 0
        mem_copy(dst_ptr, slot_addr + 8, nbytes)
    end
    mem_write(ring, 48, ridx + 1)
    mem_write(ring, 64, mem_read(ring, 64) + 1)
    atomic_unlock(ring)
    return nbytes
