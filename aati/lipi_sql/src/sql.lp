// ==============================================================================
// 👑 LIPI SOVEREIGN PERSISTENT RELATIONAL SQL ENGINE (aati/lipi_sql/src/sql.lp)
// ⚡ Zero Libc | Zero SQLite | Dynamic Tables/Rows + String Pool + CRC-32 WAL + fsync
// ==============================================================================
//
// WHY: Production SQL workloads require unbounded table/row growth, textual values,
// SQL mutations, and power-fail-safe disk persistence. lipi_sql pairs O(1) columnar
// storage with an IEEE 802.3 CRC-32 Write-Ahead Log ("LSQL" / "SQLR") over Linux
// SYS_write + SYS_fsync and automatic torn-tail truncation via SYS_ftruncate.

include "utso/memory.lp"

// Engine Descriptor Offsets (128 bytes)
//   +0:   table_count (i64)
//   +8:   table_capacity (i64, starts 32, doubles dynamically)
//   +16:  tables_ptr (i64 array pointer)
//   +24:  wal_fd (i64, -1 = pure RAM, >= 0 = persistent WAL fd)
//   +32:  crc_table_ptr (i64 -> 256*8 byte IEEE 802.3 CRC-32 table)
//   +40:  replaying (i64, 1 during WAL replay)
//   +48:  str_count (i64)
//   +56:  str_cap (i64)
//   +64:  str_ptrs (i64 array of str ptrs)
//   +72:  str_lens (i64 array of str byte lengths)
//   +80:  in_tx (i64, 1 inside explicit BEGIN..COMMIT/ROLLBACK transaction)
//   +88:  tx_undo_ptr (i64 -> flat array of 48-byte undo records)
//   +96:  tx_undo_count (i64)
//   +104: tx_undo_cap (i64)
//   +112: tx_wal_hdr (i64 -> 24-byte [buf_ptr, used_len, cap_len] buffered WAL)
//   +120: tx_committed_count (i64)

// Table Descriptor Offsets (64 bytes)
//   +0:  table_id (i64)
//   +8:  col_count (i64)
//   +16: row_count (i64)
//   +24: max_rows (i64, auto-doubles on overflow)
//   +32: data_ptr (i64)
//   +40: mask_ptr (i64)
//   +48: idx_count (i64, number of secondary hash indexes)
//   +56: idx_list_ptr (i64, array of IndexDesc pointers)

SQL_SYS_READ      = 0
SQL_SYS_WRITE     = 1
SQL_SYS_OPEN      = 2
SQL_SYS_CLOSE     = 3
SQL_SYS_LSEEK     = 8
SQL_SYS_FSYNC     = 74
SQL_SYS_FTRUNCATE = 77
SQL_SYS_RENAME    = 82

SQL_OP_CREATE_TABLE = 1
SQL_OP_INSERT_ROW   = 2
SQL_OP_UPDATE_EQ    = 3
SQL_OP_DELETE_EQ    = 4
SQL_OP_INTERN_STR   = 5
SQL_OP_CREATE_INDEX = 6

SQL_UNDO_CREATE_TABLE = 1
SQL_UNDO_INSERT_ROW   = 2
SQL_UNDO_UPDATE_CELL  = 3
SQL_UNDO_DELETE_ROW   = 4
SQL_UNDO_INTERN_STR   = 5

// ── 1. IEEE 802.3 CRC-32 & Binary Codec Helpers ───────────────────────────────

fn _sql_crc32_init_table
    tbl = sys_alloc(2048)
    i = 0
    while i < 256
        c = i
        j = 0
        while j < 8
            if (c & 1) != 0
                c = (((c / 2) & 2147483647) ^ 3988292384) & 4294967295
            else
                c = (c / 2) & 2147483647
            j = j + 1
        mem_write_idx(tbl, i, c)
        i = i + 1
    return tbl

fn _sql_crc32_compute crc_tbl buf start_off total_end
    crc = 4294967295
    i = start_off
    while i < total_end
        b = mem_byte_read(buf, i) & 255
        idx = (crc ^ b) & 255
        crc = ((crc / 256) & 16777215) ^ mem_read_idx(crc_tbl, idx)
        crc = crc & 4294967295
        i = i + 1
    return (crc ^ 4294967295) & 4294967295

fn _sql_write_exact fd buf n
    sent = 0
    while sent < n
        w = syscall(SQL_SYS_WRITE, fd, buf + sent, n - sent, 0, 0, 0)
        if w <= 0 return -1
        sent = sent + w
    return sent

fn _sql_tx_push_undo engine op table_id row_idx col_idx old_val extra
    if engine == 0 return 0
    if mem_read(engine, 80) != 1 or mem_read(engine, 40) == 1
        return 0
    end
    ucnt = mem_read(engine, 96)
    ucap = mem_read(engine, 104)
    uptr = mem_read(engine, 88)
    if ucnt >= ucap
        ncap = ucap * 2
        if ncap < 64 ncap = 64 end
        nu = sys_alloc(ncap * 48)
        if uptr > 0 and ucnt > 0
            mem_copy(nu, uptr, ucnt * 48)
            sys_free(uptr)
        end
        uptr = nu
        mem_write(engine, 88, uptr)
        mem_write(engine, 104, ncap)
    end
    off = ucnt * 48
    mem_write(uptr, off + 0, op)
    mem_write(uptr, off + 8, table_id)
    mem_write(uptr, off + 16, row_idx)
    mem_write(uptr, off + 24, col_idx)
    mem_write(uptr, off + 32, old_val)
    mem_write(uptr, off + 40, extra)
    mem_write(engine, 96, ucnt + 1)
    return 1

fn _sql_tx_wal_append engine rec tot
    hdr = mem_read(engine, 112)
    if hdr == 0 return 0 end
    buf = mem_read(hdr, 0)
    used = mem_read(hdr, 8)
    cap = mem_read(hdr, 16)
    if used + tot > cap
        ncap = cap * 2
        if ncap < 4096 ncap = 4096 end
        while ncap < used + tot
            ncap = ncap * 2
        end
        nb = sys_alloc(ncap)
        if buf > 0 and used > 0
            mem_copy(nb, buf, used)
            sys_free(buf)
        end
        buf = nb
        mem_write(hdr, 0, buf)
        mem_write(hdr, 16, ncap)
    end
    mem_copy(buf + used, rec, tot)
    mem_write(hdr, 8, used + tot)
    return 1

fn _sql_append_wal engine op_type table_id payload_buf payload_len
    if engine == 0 return 0
    fd = mem_read(engine, 24)
    if fd < 0 or mem_read(engine, 40) == 1
        return 0
    tot = 24 + payload_len
    rec = sys_alloc(tot)
    // Magic "SQLR" (83, 81, 76, 82)
    mem_byte_write(rec, 0, 83)
    mem_byte_write(rec, 1, 81)
    mem_byte_write(rec, 2, 76)
    mem_byte_write(rec, 3, 82)
    mem_write_u32(rec, 8, op_type)
    mem_write_u32(rec, 12, payload_len)
    mem_write(rec, 16, table_id)
    if payload_len > 0 and payload_buf > 0
        mem_copy(rec + 24, payload_buf, payload_len)
    crc_tbl = mem_read(engine, 32)
    crc = _sql_crc32_compute(crc_tbl, rec, 8, tot)
    mem_write_u32(rec, 4, crc)
    if mem_read(engine, 80) == 1
        // WHY: Inside an explicit transaction, stage CRC-32 records in RAM until COMMIT
        // so uncommitted mutations NEVER hit disk even on abrupt crash/power loss.
        _sql_tx_wal_append(engine, rec, tot)
    else
        _sql_write_exact(fd, rec, tot)
        syscall(SQL_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
    end
    sys_free(rec)
    return 1

// ── 1b. Secondary Hash Index Engine (O(1) Equality Acceleration) ──────────────

fn _sql_idx_hash key bucket_mask
    // Knuth multiplicative 64-bit mixing hash masked to power-of-2 bucket count
    h = (key ^ (key >> 16)) * 2654435761
    return h & bucket_mask

fn _sql_idx_new col_idx bucket_count
    idx = sys_alloc(48)
    bptr = sys_alloc(bucket_count * 8)
    bi = 0
    while bi < bucket_count
        mem_write_idx(bptr, bi, 0 - 1)
        bi = bi + 1
    end
    ncap = 256
    nptr = sys_alloc(ncap * 24)
    mem_write(idx, 0, col_idx)
    mem_write(idx, 8, bucket_count)
    mem_write(idx, 16, bptr)
    mem_write(idx, 24, nptr)
    mem_write(idx, 32, 0)
    mem_write(idx, 40, ncap)
    return idx

fn _sql_idx_free idx
    if idx <= 0 return 0 end
    sys_free(mem_read(idx, 16))
    sys_free(mem_read(idx, 24))
    sys_free(idx)
    return 1

fn _sql_idx_insert idx key row_idx
    if idx <= 0 return 0 end
    bcount = mem_read(idx, 8)
    bptr = mem_read(idx, 16)
    ncnt = mem_read(idx, 32)
    ncap = mem_read(idx, 40)
    nptr = mem_read(idx, 24)
    if ncnt >= ncap
        new_cap = ncap * 2
        nn = sys_alloc(new_cap * 24)
        mem_copy(nn, nptr, ncnt * 24)
        sys_free(nptr)
        nptr = nn
        mem_write(idx, 24, nptr)
        mem_write(idx, 40, new_cap)
    end
    b = _sql_idx_hash(key, bcount - 1)
    old_head = mem_read_idx(bptr, b)
    off = ncnt * 24
    mem_write(nptr, off + 0, key)
    mem_write(nptr, off + 8, row_idx)
    mem_write(nptr, off + 16, old_head)
    mem_write_idx(bptr, b, ncnt)
    mem_write(idx, 32, ncnt + 1)
    return 1

fn _sql_idx_rebuild tbl idx
    if tbl <= 0 or idx <= 0 return 0 end
    bcount = mem_read(idx, 8)
    bptr = mem_read(idx, 16)
    bi = 0
    while bi < bcount
        mem_write_idx(bptr, bi, 0 - 1)
        bi = bi + 1
    end
    mem_write(idx, 32, 0)

    col_idx = mem_read(idx, 0)
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)
    // Insert in reverse so bucket chains iterate in ascending row_idx order
    r = row_count - 1
    while r >= 0
        if mem_byte_read(mask_buf, r) == 1
            k = mem_read_idx(data_buf, (r * col_count) + col_idx)
            _sql_idx_insert(idx, k, r)
        end
        r = r - 1
    end
    return 1

fn _sql_find_index tbl col_idx
    if tbl <= 0 return 0 end
    icnt = mem_read(tbl, 48)
    iptr = mem_read(tbl, 56)
    if icnt <= 0 or iptr <= 0 return 0 end
    i = 0
    while i < icnt
        idx = mem_read_idx(iptr, i)
        if idx > 0 and mem_read(idx, 0) == col_idx
            return idx
        end
        i = i + 1
    end
    return 0

fn _sql_tbl_index_row tbl row_idx
    icnt = mem_read(tbl, 48)
    if icnt <= 0 return 0 end
    iptr = mem_read(tbl, 56)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    i = 0
    while i < icnt
        idx = mem_read_idx(iptr, i)
        if idx > 0
            c = mem_read(idx, 0)
            if c < col_count
                _sql_idx_insert(idx, mem_read_idx(data_buf, (row_idx * col_count) + c), row_idx)
            end
        end
        i = i + 1
    end
    return 1

fn _sql_tbl_rebuild_all_indexes tbl
    if tbl <= 0 return 0 end
    icnt = mem_read(tbl, 48)
    if icnt <= 0 return 0 end
    iptr = mem_read(tbl, 56)
    i = 0
    while i < icnt
        idx = mem_read_idx(iptr, i)
        if idx > 0
            _sql_idx_rebuild(tbl, idx)
        end
        i = i + 1
    end
    return 1

fn sql_create_index engine table_id col_idx
    // WHY: Attaches an O(1) secondary hash index on (table_id, col_idx), populates all active rows,
    // and persists index creation to the CRC-32 WAL so indexes survive crash recovery.
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0 end
    col_count = mem_read(tbl, 8)
    if col_idx < 0 or col_idx >= col_count return 0 end
    existing = _sql_find_index(tbl, col_idx)
    if existing > 0 return 1 end

    icnt = mem_read(tbl, 48)
    iptr = mem_read(tbl, 56)
    if iptr == 0
        iptr = sys_alloc(16 * 8)
        mem_zero(iptr, 16 * 8)
        mem_write(tbl, 56, iptr)
    end
    if icnt >= 16 return 0 end

    idx = _sql_idx_new(col_idx, 1024)
    _sql_idx_rebuild(tbl, idx)
    mem_write_idx(iptr, icnt, idx)
    mem_write(tbl, 48, icnt + 1)

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        pbuf = sys_alloc(8)
        mem_write(pbuf, 0, col_idx)
        _sql_append_wal(engine, SQL_OP_CREATE_INDEX, table_id, pbuf, 8)
        sys_free(pbuf)
    end
    return 1

fn sql_has_index engine table_id col_idx
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0 end
    if _sql_find_index(tbl, col_idx) > 0 return 1 end
    return 0

// ── 2. Engine Allocation, Dynamic Expansion & String Pool ─────────────────────

fn sql_engine_new
    engine = sys_alloc(128)
    mem_zero(engine, 128)
    init_cap = 32
    tptrs = sys_alloc(init_cap * 8)
    mem_zero(tptrs, init_cap * 8)
    str_cap = 64
    sptrs = sys_alloc(str_cap * 8)
    mem_zero(sptrs, str_cap * 8)
    slens = sys_alloc(str_cap * 8)
    mem_zero(slens, str_cap * 8)

    tx_wal_hdr = sys_alloc(24)
    mem_zero(tx_wal_hdr, 24)

    mem_write(engine, 0, 0)
    mem_write(engine, 8, init_cap)
    mem_write(engine, 16, tptrs)
    mem_write(engine, 24, 0 - 1) // -1 = RAM-only until sql_engine_open
    mem_write(engine, 32, _sql_crc32_init_table())
    mem_write(engine, 40, 0)
    mem_write(engine, 48, 0)
    mem_write(engine, 56, str_cap)
    mem_write(engine, 64, sptrs)
    mem_write(engine, 72, slens)
    mem_write(engine, 80, 0)
    mem_write(engine, 88, 0)
    mem_write(engine, 96, 0)
    mem_write(engine, 104, 0)
    mem_write(engine, 112, tx_wal_hdr)
    mem_write(engine, 120, 0)
    return engine

fn _sql_intern_raw engine bytes_ptr blen
    scnt = mem_read(engine, 48)
    sptrs = mem_read(engine, 64)
    slens = mem_read(engine, 72)
    i = 0
    while i < scnt
        if mem_read_idx(slens, i) == blen
            p = mem_read_idx(sptrs, i)
            eq = 1
            k = 0
            while k < blen
                if mem_byte_read(p, k) != mem_byte_read(bytes_ptr, k)
                    eq = 0
                    break
                k = k + 1
            if eq == 1
                return i + 1
        i = i + 1

    scap = mem_read(engine, 56)
    if scnt >= scap
        new_cap = scap * 2
        np = sys_alloc(new_cap * 8)
        nl = sys_alloc(new_cap * 8)
        mem_copy(np, sptrs, scnt * 8)
        mem_copy(nl, slens, scnt * 8)
        sys_free(sptrs)
        sys_free(slens)
        sptrs = np
        slens = nl
        mem_write(engine, 56, new_cap)
        mem_write(engine, 64, sptrs)
        mem_write(engine, 72, slens)

    copy_sz = blen
    if copy_sz <= 0 copy_sz = 1
    sb = sys_alloc(copy_sz)
    if blen > 0
        mem_copy(sb, bytes_ptr, blen)
    mem_write_idx(sptrs, scnt, sb)
    mem_write_idx(slens, scnt, blen)
    mem_write(engine, 48, scnt + 1)
    _sql_tx_push_undo(engine, SQL_UNDO_INTERN_STR, 0, scnt, 0, 0, 0)
    id = scnt + 1

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        pbuf = sys_alloc(8 + blen)
        mem_write(pbuf, 0, blen)
        if blen > 0
            mem_copy(pbuf + 8, bytes_ptr, blen)
        _sql_append_wal(engine, SQL_OP_INTERN_STR, id, pbuf, 8 + blen)
        sys_free(pbuf)
    return id

fn sql_intern_string engine text_str
    if engine == 0 return 0
    n = str_len(text_str)
    asz = n
    if asz <= 0 asz = 1
    tmp = sys_alloc(asz)
    i = 0
    while i < n
        mem_byte_write(tmp, i, str_char_at(text_str, i) & 255)
        i = i + 1
    id = _sql_intern_raw(engine, tmp, n)
    sys_free(tmp)
    return id

fn sql_get_string engine str_id
    if engine == 0 or str_id <= 0 return ""
    scnt = mem_read(engine, 48)
    idx = str_id - 1
    if idx >= scnt return ""
    p = mem_read_idx(mem_read(engine, 64), idx)
    slen = mem_read_idx(mem_read(engine, 72), idx)
    out = ""
    i = 0
    while i < slen
        out = out + chr(mem_byte_read(p, i) & 255)
        i = i + 1
    return out

fn sql_create_table engine table_id col_count max_rows
    if engine == 0 return 0
    if col_count <= 0 return 0
    if max_rows <= 0 max_rows = 16

    cur_count = mem_read(engine, 0)
    cur_cap = mem_read(engine, 8)
    tptrs = mem_read(engine, 16)
    if cur_count >= cur_cap
        new_cap = cur_cap * 2
        nt = sys_alloc(new_cap * 8)
        mem_zero(nt, new_cap * 8)
        mem_copy(nt, tptrs, cur_count * 8)
        sys_free(tptrs)
        tptrs = nt
        mem_write(engine, 8, new_cap)
        mem_write(engine, 16, tptrs)

    tbl = sys_alloc(64)
    mem_zero(tbl, 64)

    data_size = max_rows * col_count * 8
    data_buf = sys_alloc(data_size)
    mem_zero(data_buf, data_size)

    mask_buf = sys_alloc(max_rows)
    mem_zero(mask_buf, max_rows)

    mem_write(tbl, 0, table_id)
    mem_write(tbl, 8, col_count)
    mem_write(tbl, 16, 0)
    mem_write(tbl, 24, max_rows)
    mem_write(tbl, 32, data_buf)
    mem_write(tbl, 40, mask_buf)

    mem_write_idx(tptrs, cur_count, tbl)
    mem_write(engine, 0, cur_count + 1)
    _sql_tx_push_undo(engine, SQL_UNDO_CREATE_TABLE, table_id, cur_count, 0, 0, 0)

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        pbuf = sys_alloc(16)
        mem_write(pbuf, 0, col_count)
        mem_write(pbuf, 8, max_rows)
        _sql_append_wal(engine, SQL_OP_CREATE_TABLE, table_id, pbuf, 16)
        sys_free(pbuf)

    return tbl

fn sql_get_table engine table_id
    if engine == 0 return 0
    cur_count = mem_read(engine, 0)
    tptrs = mem_read(engine, 16)
    i = 0
    while i < cur_count
        tbl = mem_read_idx(tptrs, i)
        if tbl > 0
            if mem_read(tbl, 0) == table_id
                return tbl
        i = i + 1
    return 0

fn _sql_ensure_row_capacity tbl
    row_count = mem_read(tbl, 16)
    max_rows = mem_read(tbl, 24)
    if row_count < max_rows
        return 1
    new_max = max_rows * 2
    if new_max < 16 new_max = 16
    col_count = mem_read(tbl, 8)
    old_data = mem_read(tbl, 32)
    old_mask = mem_read(tbl, 40)

    new_data = sys_alloc(new_max * col_count * 8)
    mem_zero(new_data, new_max * col_count * 8)
    mem_copy(new_data, old_data, row_count * col_count * 8)
    sys_free(old_data)

    new_mask = sys_alloc(new_max)
    mem_zero(new_mask, new_max)
    mem_copy(new_mask, old_mask, row_count)
    sys_free(old_mask)

    mem_write(tbl, 24, new_max)
    mem_write(tbl, 32, new_data)
    mem_write(tbl, 40, new_mask)
    return 1

fn _sql_wal_log_row engine table_id vals_ptr vcnt
    if mem_read(engine, 24) < 0 or mem_read(engine, 40) == 1
        return 0
    plen = 8 + (vcnt * 8)
    pbuf = sys_alloc(plen)
    mem_write(pbuf, 0, vcnt)
    i = 0
    while i < vcnt
        mem_write(pbuf, 8 + (i * 8), mem_read_idx(vals_ptr, i))
        i = i + 1
    _sql_append_wal(engine, SQL_OP_INSERT_ROW, table_id, pbuf, plen)
    sys_free(pbuf)
    return 1

fn sql_insert_2 engine table_id val0 val1
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    _sql_ensure_row_capacity(tbl)
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    base_idx = row_count * col_count
    mem_write_idx(data_buf, base_idx, val0)
    if col_count > 1
        mem_write_idx(data_buf, base_idx + 1, val1)
    mem_byte_write(mask_buf, row_count, 1)
    mem_write(tbl, 16, row_count + 1)
    _sql_tbl_index_row(tbl, row_count)
    _sql_tx_push_undo(engine, SQL_UNDO_INSERT_ROW, table_id, row_count, 0, 0, 0)

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        vb = sys_alloc(16)
        mem_write_idx(vb, 0, val0)
        mem_write_idx(vb, 1, val1)
        _sql_wal_log_row(engine, table_id, vb, 2)
        sys_free(vb)
    return row_count + 1

fn sql_insert_3 engine table_id val0 val1 val2
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    _sql_ensure_row_capacity(tbl)
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    base_idx = row_count * col_count
    mem_write_idx(data_buf, base_idx, val0)
    if col_count > 1
        mem_write_idx(data_buf, base_idx + 1, val1)
    if col_count > 2
        mem_write_idx(data_buf, base_idx + 2, val2)
    mem_byte_write(mask_buf, row_count, 1)
    mem_write(tbl, 16, row_count + 1)
    _sql_tbl_index_row(tbl, row_count)
    _sql_tx_push_undo(engine, SQL_UNDO_INSERT_ROW, table_id, row_count, 0, 0, 0)

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        vb = sys_alloc(24)
        mem_write_idx(vb, 0, val0)
        mem_write_idx(vb, 1, val1)
        mem_write_idx(vb, 2, val2)
        _sql_wal_log_row(engine, table_id, vb, 3)
        sys_free(vb)
    return row_count + 1

fn sql_insert_row_slice engine table_id vals_ptr vcnt
    // WHY: Arbitrary N-column insertion (1..N columns) preserving all cells across WAL & checkpoints.
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    _sql_ensure_row_capacity(tbl)
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    base_idx = row_count * col_count
    ci = 0
    while ci < col_count
        v = 0
        if ci < vcnt
            v = mem_read_idx(vals_ptr, ci)
        mem_write_idx(data_buf, base_idx + ci, v)
        ci = ci + 1
    mem_byte_write(mask_buf, row_count, 1)
    mem_write(tbl, 16, row_count + 1)
    _sql_tbl_index_row(tbl, row_count)
    _sql_tx_push_undo(engine, SQL_UNDO_INSERT_ROW, table_id, row_count, 0, 0, 0)

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        _sql_wal_log_row(engine, table_id, vals_ptr, vcnt)
    return row_count + 1

fn sql_insert_1 engine table_id val0
    vb = sys_alloc(8)
    mem_write_idx(vb, 0, val0)
    rc = sql_insert_row_slice(engine, table_id, vb, 1)
    sys_free(vb)
    return rc

fn sql_insert_4 engine table_id val0 val1 val2 val3
    vb = sys_alloc(32)
    mem_write_idx(vb, 0, val0)
    mem_write_idx(vb, 1, val1)
    mem_write_idx(vb, 2, val2)
    mem_write_idx(vb, 3, val3)
    rc = sql_insert_row_slice(engine, table_id, vb, 4)
    sys_free(vb)
    return rc

fn sql_insert_text_2 engine table_id id_val text_str
    sid = sql_intern_string(engine, text_str)
    return sql_insert_2(engine, table_id, id_val, sid)

fn sql_select_cell engine table_id row_idx col_idx
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    row_count = mem_read(tbl, 16)
    if row_idx >= row_count return 0
    col_count = mem_read(tbl, 8)
    if col_idx >= col_count return 0
    data_buf = mem_read(tbl, 32)
    return mem_read_idx(data_buf, (row_idx * col_count) + col_idx)

fn sql_select_text_cell engine table_id row_idx col_idx
    sid = sql_select_cell(engine, table_id, row_idx, col_idx)
    return sql_get_string(engine, sid)

fn sql_count_active engine table_id
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    row_count = mem_read(tbl, 16)
    mask_buf = mem_read(tbl, 40)
    active = 0
    i = 0
    while i < row_count
        if mem_byte_read(mask_buf, i) == 1
            active = active + 1
        i = i + 1
    return active

fn sql_select_where_eq engine table_id col_idx target_val
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    // O(1) secondary hash index fast path if col_idx is indexed
    idx = _sql_find_index(tbl, col_idx)
    if idx > 0
        bcount = mem_read(idx, 8)
        bptr = mem_read(idx, 16)
        nptr = mem_read(idx, 24)
        b = _sql_idx_hash(target_val, bcount - 1)
        cur = mem_read_idx(bptr, b)
        hits = 0
        while cur >= 0
            noff = cur * 24
            if mem_read(nptr, noff + 0) == target_val
                r = mem_read(nptr, noff + 8)
                if r < row_count and mem_byte_read(mask_buf, r) == 1
                    if mem_read_idx(data_buf, (r * col_count) + col_idx) == target_val
                        hits = hits + 1
                    end
                end
            end
            cur = mem_read(nptr, noff + 16)
        end
        return hits
    end

    match_count = 0
    r = 0
    while r < row_count
        if mem_byte_read(mask_buf, r) == 1
            val = mem_read_idx(data_buf, (r * col_count) + col_idx)
            if val == target_val
                match_count = match_count + 1
        r = r + 1
    return match_count

fn sql_select_first_where_eq engine table_id filter_col target_val return_col
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0 - 1
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    // O(1) secondary hash index fast path preserving lowest matching row_idx semantics
    idx = _sql_find_index(tbl, filter_col)
    if idx > 0
        bcount = mem_read(idx, 8)
        bptr = mem_read(idx, 16)
        nptr = mem_read(idx, 24)
        b = _sql_idx_hash(target_val, bcount - 1)
        cur = mem_read_idx(bptr, b)
        best_r = 0 - 1
        while cur >= 0
            noff = cur * 24
            if mem_read(nptr, noff + 0) == target_val
                r = mem_read(nptr, noff + 8)
                if r < row_count and mem_byte_read(mask_buf, r) == 1
                    if mem_read_idx(data_buf, (r * col_count) + filter_col) == target_val
                        if best_r < 0 or r < best_r
                            best_r = r
                        end
                    end
                end
            end
            cur = mem_read(nptr, noff + 16)
        end
        if best_r >= 0
            return mem_read_idx(data_buf, (best_r * col_count) + return_col)
        end
        return 0 - 1
    end

    r = 0
    while r < row_count
        if mem_byte_read(mask_buf, r) == 1
            val = mem_read_idx(data_buf, (r * col_count) + filter_col)
            if val == target_val
                return mem_read_idx(data_buf, (r * col_count) + return_col)
        r = r + 1
    return 0 - 1

fn sql_update_where_eq engine table_id filter_col target_val update_col new_val
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    updated_count = 0
    r = 0
    while r < row_count
        if mem_byte_read(mask_buf, r) == 1
            val = mem_read_idx(data_buf, (r * col_count) + filter_col)
            if val == target_val
                old_v = mem_read_idx(data_buf, (r * col_count) + update_col)
                _sql_tx_push_undo(engine, SQL_UNDO_UPDATE_CELL, table_id, r, update_col, old_v, 0)
                mem_write_idx(data_buf, (r * col_count) + update_col, new_val)
                updated_count = updated_count + 1
        r = r + 1

    if updated_count > 0
        u_idx = _sql_find_index(tbl, update_col)
        if u_idx > 0
            _sql_idx_rebuild(tbl, u_idx)
        end
    end

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        pbuf = sys_alloc(32)
        mem_write(pbuf, 0, filter_col)
        mem_write(pbuf, 8, target_val)
        mem_write(pbuf, 16, update_col)
        mem_write(pbuf, 24, new_val)
        _sql_append_wal(engine, SQL_OP_UPDATE_EQ, table_id, pbuf, 32)
        sys_free(pbuf)
    return updated_count

fn sql_delete_where_eq engine table_id filter_col target_val
    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return 0
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    deleted_count = 0
    r = 0
    while r < row_count
        if mem_byte_read(mask_buf, r) == 1
            val = mem_read_idx(data_buf, (r * col_count) + filter_col)
            if val == target_val
                _sql_tx_push_undo(engine, SQL_UNDO_DELETE_ROW, table_id, r, 0, 1, 0)
                mem_byte_write(mask_buf, r, 0)
                deleted_count = deleted_count + 1
        r = r + 1

    if mem_read(engine, 24) >= 0 and mem_read(engine, 40) == 0
        pbuf = sys_alloc(16)
        mem_write(pbuf, 0, filter_col)
        mem_write(pbuf, 8, target_val)
        _sql_append_wal(engine, SQL_OP_DELETE_EQ, table_id, pbuf, 16)
        sys_free(pbuf)
    return deleted_count

// ── 3. Sovereign Disk Persistence, Replay & Torn-Tail Crash Recovery ──────────

fn sql_engine_open db_path
    // WHY: Opens or creates a binary "LSQL" Write-Ahead Log, replays all CRC-32 verified
    // records into memory, and cleanly ftruncates any torn tail from power loss.
    engine = sql_engine_new()
    fd = syscall(SQL_SYS_OPEN, db_path, 66, 420, 0, 0, 0) // O_RDWR | O_CREAT, 0644
    if fd < 0
        return engine
    sz = syscall(SQL_SYS_LSEEK, fd, 0, 2, 0, 0, 0)
    syscall(SQL_SYS_LSEEK, fd, 0, 0, 0, 0, 0)

    if sz < 16
        syscall(SQL_SYS_FTRUNCATE, fd, 0, 0, 0, 0, 0)
        syscall(SQL_SYS_LSEEK, fd, 0, 0, 0, 0, 0)
        hdr = sys_alloc(16)
        mem_zero(hdr, 16)
        mem_byte_write(hdr, 0, 76) // 'L'
        mem_byte_write(hdr, 1, 83) // 'S'
        mem_byte_write(hdr, 2, 81) // 'Q'
        mem_byte_write(hdr, 3, 76) // 'L'
        mem_write_u32(hdr, 4, 1)
        _sql_write_exact(fd, hdr, 16)
        syscall(SQL_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
        sys_free(hdr)
        mem_write(engine, 24, fd)
        return engine

    buf = sys_alloc(sz)
    got = 0
    while got < sz
        n = syscall(SQL_SYS_READ, fd, buf + got, sz - got, 0, 0, 0)
        if n <= 0 break
        got = got + n

    valid_end = 16
    if got >= 16 and mem_byte_read(buf, 0) == 76 and mem_byte_read(buf, 1) == 83 and mem_byte_read(buf, 2) == 81 and mem_byte_read(buf, 3) == 76
        mem_write(engine, 40, 1) // replaying = 1
        crc_tbl = mem_read(engine, 32)
        pos = 16
        while pos + 24 <= got
            if mem_byte_read(buf, pos) != 83 or mem_byte_read(buf, pos + 1) != 81 or mem_byte_read(buf, pos + 2) != 76 or mem_byte_read(buf, pos + 3) != 82
                break
            exp_crc = mem_read_u32(buf, pos + 4)
            op = mem_read_u32(buf, pos + 8)
            plen = mem_read_u32(buf, pos + 12)
            tid = mem_read(buf, pos + 16)
            if plen < 0 or plen > 16777216 or (pos + 24 + plen) > got
                break
            act_crc = _sql_crc32_compute(crc_tbl, buf, pos + 8, pos + 24 + plen)
            if act_crc != exp_crc
                break

            p = buf + pos + 24
            if op == SQL_OP_CREATE_TABLE and plen >= 16
                sql_create_table(engine, tid, mem_read(p, 0), mem_read(p, 8))
            elif op == SQL_OP_INSERT_ROW and plen >= 16
                vcnt = mem_read(p, 0)
                if vcnt >= 1 and (8 + (vcnt * 8)) <= plen
                    sql_insert_row_slice(engine, tid, p + 8, vcnt)
                end
            elif op == SQL_OP_UPDATE_EQ and plen >= 32
                sql_update_where_eq(engine, tid, mem_read(p, 0), mem_read(p, 8), mem_read(p, 16), mem_read(p, 24))
            elif op == SQL_OP_DELETE_EQ and plen >= 16
                sql_delete_where_eq(engine, tid, mem_read(p, 0), mem_read(p, 8))
            elif op == SQL_OP_INTERN_STR and plen >= 8
                slen = mem_read(p, 0)
                if 8 + slen <= plen
                    _sql_intern_raw(engine, p + 8, slen)
                end
            elif op == SQL_OP_CREATE_INDEX and plen >= 8
                sql_create_index(engine, tid, mem_read(p, 0))
            end

            pos = pos + 24 + plen
            valid_end = pos
        mem_write(engine, 40, 0)

    sys_free(buf)
    if valid_end < sz
        syscall(SQL_SYS_FTRUNCATE, fd, valid_end, 0, 0, 0, 0)
        syscall(SQL_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
    syscall(SQL_SYS_LSEEK, fd, valid_end, 0, 0, 0, 0)
    mem_write(engine, 24, fd)
    return engine

fn sql_engine_checkpoint engine db_path
    if engine == 0 return -1
    tmp_path = db_path + ".tmp"
    tfd = syscall(SQL_SYS_OPEN, tmp_path, 578, 420, 0, 0, 0) // O_RDWR | O_CREAT | O_TRUNC
    if tfd < 0 return -1

    hdr = sys_alloc(16)
    mem_zero(hdr, 16)
    mem_byte_write(hdr, 0, 76)
    mem_byte_write(hdr, 1, 83)
    mem_byte_write(hdr, 2, 81)
    mem_byte_write(hdr, 3, 76)
    mem_write_u32(hdr, 4, 1)
    _sql_write_exact(tfd, hdr, 16)
    sys_free(hdr)

    old_fd = mem_read(engine, 24)
    old_rep = mem_read(engine, 40)
    mem_write(engine, 24, tfd)
    mem_write(engine, 40, 0)

    // Write interned strings
    scnt = mem_read(engine, 48)
    sptrs = mem_read(engine, 64)
    slens = mem_read(engine, 72)
    si = 0
    while si < scnt
        sp = mem_read_idx(sptrs, si)
        sl = mem_read_idx(slens, si)
        pb = sys_alloc(8 + sl)
        mem_write(pb, 0, sl)
        if sl > 0 mem_copy(pb + 8, sp, sl)
        _sql_append_wal(engine, SQL_OP_INTERN_STR, si + 1, pb, 8 + sl)
        sys_free(pb)
        si = si + 1

    // Write tables and active rows
    tcnt = mem_read(engine, 0)
    tptrs = mem_read(engine, 16)
    ti = 0
    while ti < tcnt
        tbl = mem_read_idx(tptrs, ti)
        if tbl > 0
            tid = mem_read(tbl, 0)
            cols = mem_read(tbl, 8)
            rows = mem_read(tbl, 16)
            mrows = mem_read(tbl, 24)
            dbuf = mem_read(tbl, 32)
            mbuf = mem_read(tbl, 40)

            cp = sys_alloc(16)
            mem_write(cp, 0, cols)
            mem_write(cp, 8, mrows)
            _sql_append_wal(engine, SQL_OP_CREATE_TABLE, tid, cp, 16)
            sys_free(cp)

            r = 0
            while r < rows
                if mem_byte_read(mbuf, r) == 1
                    rb = sys_alloc(8 + (cols * 8))
                    mem_write(rb, 0, cols)
                    ci = 0
                    while ci < cols
                        mem_write(rb, 8 + (ci * 8), mem_read_idx(dbuf, (r * cols) + ci))
                        ci = ci + 1
                    _sql_append_wal(engine, SQL_OP_INSERT_ROW, tid, rb, 8 + (cols * 8))
                    sys_free(rb)
                r = r + 1

            icnt = mem_read(tbl, 48)
            iptr = mem_read(tbl, 56)
            ii = 0
            while ii < icnt
                idx = mem_read_idx(iptr, ii)
                if idx > 0
                    ib = sys_alloc(8)
                    mem_write(ib, 0, mem_read(idx, 0))
                    _sql_append_wal(engine, SQL_OP_CREATE_INDEX, tid, ib, 8)
                    sys_free(ib)
                end
                ii = ii + 1
            end
        ti = ti + 1

    syscall(SQL_SYS_FSYNC, tfd, 0, 0, 0, 0, 0)
    syscall(SQL_SYS_CLOSE, tfd, 0, 0, 0, 0, 0)
    if old_fd >= 0
        syscall(SQL_SYS_CLOSE, old_fd, 0, 0, 0, 0, 0)
    syscall(SQL_SYS_RENAME, tmp_path, db_path, 0, 0, 0, 0)
    nfd = syscall(SQL_SYS_OPEN, db_path, 66, 420, 0, 0, 0)
    if nfd >= 0
        syscall(SQL_SYS_LSEEK, nfd, 0, 2, 0, 0, 0)
    mem_write(engine, 24, nfd)
    mem_write(engine, 40, old_rep)
    return 1

fn sql_engine_close engine
    return sql_engine_free(engine)

fn sql_engine_free engine
    if engine == 0 return 0
    fd = mem_read(engine, 24)
    if fd >= 0
        syscall(SQL_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
        syscall(SQL_SYS_CLOSE, fd, 0, 0, 0, 0, 0)

    cur_count = mem_read(engine, 0)
    tptrs = mem_read(engine, 16)
    i = 0
    while i < cur_count
        tbl = mem_read_idx(tptrs, i)
        if tbl > 0
            icnt = mem_read(tbl, 48)
            iptr = mem_read(tbl, 56)
            if iptr > 0
                ii = 0
                while ii < icnt
                    _sql_idx_free(mem_read_idx(iptr, ii))
                    ii = ii + 1
                end
                sys_free(iptr)
            end
            sys_free(mem_read(tbl, 32))
            sys_free(mem_read(tbl, 40))
            sys_free(tbl)
        i = i + 1
    sys_free(tptrs)
    sys_free(mem_read(engine, 32))

    uptr = mem_read(engine, 88)
    if uptr > 0
        sys_free(uptr)
    end
    twh = mem_read(engine, 112)
    if twh > 0
        twb = mem_read(twh, 0)
        if twb > 0 sys_free(twb) end
        sys_free(twh)
    end

    scnt = mem_read(engine, 48)
    sptrs = mem_read(engine, 64)
    slens = mem_read(engine, 72)
    si = 0
    while si < scnt
        sp = mem_read_idx(sptrs, si)
        if sp > 0 sys_free(sp)
        si = si + 1
    sys_free(sptrs)
    sys_free(slens)
    sys_free(engine)
    return 0

// ── 4. SQL Text Query Tokenizer & Execution Planner ───────────────────────────

fn sql_tokenize_text q
    toks = list()
    cur = ""
    i = 0
    qlen = len(q)
    while i < qlen
        ch = mem_byte_read(q, i)
        if ch == 32 or ch == 9 or ch == 10 or ch == 13 or ch == 44 or ch == 40 or ch == 41 or ch == 59
            if len(cur) > 0
                push(toks, cur)
                cur = ""
            end
        elif ch == 61
            if len(cur) > 0
                push(toks, cur)
                cur = ""
            end
            push(toks, "=")
        else
            cur = cur + chr(ch)
        end
        i = i + 1
    end
    if len(cur) > 0
        push(toks, cur)
    end
    return toks

fn sql_parse_int_tok s
    if len(s) == 0 return 0 end
    neg = 0
    i = 0
    if mem_byte_read(s, 0) == 45
        neg = 1
        i = 1
    end
    val = 0
    while i < len(s)
        c = mem_byte_read(s, i)
        if c >= 48 and c <= 57
            val = (val * 10) + (c - 48)
        end
        i = i + 1
    end
    if neg == 1 return 0 - val end
    return val

// ── 5. Explicit ACID Transactions (BEGIN / COMMIT / ROLLBACK) ─────────────────

fn sql_in_transaction engine
    if engine == 0 return 0 end
    return mem_read(engine, 80)

fn sql_begin engine
    // WHY: Starts an explicit ACID transaction; mutations record undo entries and stage WAL
    // frames in RAM until sql_commit() atomically flushes + SYS_fsyncs them to disk.
    if engine == 0 return 0 end
    if mem_read(engine, 80) == 1
        return 0
    end
    mem_write(engine, 80, 1)
    mem_write(engine, 96, 0)
    twh = mem_read(engine, 112)
    if twh > 0
        mem_write(twh, 8, 0)
    end
    return 1

fn sql_commit engine
    if engine == 0 return 0 end
    if mem_read(engine, 80) != 1
        return 0
    end
    fd = mem_read(engine, 24)
    twh = mem_read(engine, 112)
    if fd >= 0 and twh > 0
        buf = mem_read(twh, 0)
        used = mem_read(twh, 8)
        if buf > 0 and used > 0
            if _sql_write_exact(fd, buf, used) < 0
                return 0 - 1
            end
            syscall(SQL_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
        end
        mem_write(twh, 8, 0)
    end
    mem_write(engine, 96, 0)
    mem_write(engine, 80, 0)
    mem_write(engine, 120, mem_read(engine, 120) + 1)
    return 1

fn sql_rollback engine
    // WHY: Replays transaction undo records in strict reverse LIFO order, discards all staged
    // WAL frames without touching disk, and rebuilds secondary indexes on all tables.
    if engine == 0 return 0 end
    if mem_read(engine, 80) != 1
        return 0
    end
    ucnt = mem_read(engine, 96)
    uptr = mem_read(engine, 88)
    i = ucnt - 1
    while i >= 0
        off = i * 48
        op = mem_read(uptr, off + 0)
        tid = mem_read(uptr, off + 8)
        ridx = mem_read(uptr, off + 16)
        cidx = mem_read(uptr, off + 24)
        old_val = mem_read(uptr, off + 32)

        if op == SQL_UNDO_INSERT_ROW
            tbl = sql_get_table(engine, tid)
            if tbl > 0
                mask_buf = mem_read(tbl, 40)
                mem_byte_write(mask_buf, ridx, 0)
                if mem_read(tbl, 16) == ridx + 1
                    mem_write(tbl, 16, ridx)
                end
            end
        elif op == SQL_UNDO_UPDATE_CELL
            tbl = sql_get_table(engine, tid)
            if tbl > 0
                cols = mem_read(tbl, 8)
                dbuf = mem_read(tbl, 32)
                mem_write_idx(dbuf, (ridx * cols) + cidx, old_val)
            end
        elif op == SQL_UNDO_DELETE_ROW
            tbl = sql_get_table(engine, tid)
            if tbl > 0
                mask_buf = mem_read(tbl, 40)
                mem_byte_write(mask_buf, ridx, 1)
            end
        elif op == SQL_UNDO_CREATE_TABLE
            tcnt = mem_read(engine, 0)
            tptrs = mem_read(engine, 16)
            if ridx >= 0 and ridx < tcnt
                tbl = mem_read_idx(tptrs, ridx)
                if tbl > 0
                    icnt = mem_read(tbl, 48)
                    iptr = mem_read(tbl, 56)
                    if iptr > 0
                        ii = 0
                        while ii < icnt
                            _sql_idx_free(mem_read_idx(iptr, ii))
                            ii = ii + 1
                        end
                        sys_free(iptr)
                    end
                    sys_free(mem_read(tbl, 32))
                    sys_free(mem_read(tbl, 40))
                    sys_free(tbl)
                    mem_write_idx(tptrs, ridx, 0)
                end
                if tcnt == ridx + 1
                    mem_write(engine, 0, ridx)
                end
            end
        elif op == SQL_UNDO_INTERN_STR
            scnt = mem_read(engine, 48)
            sptrs = mem_read(engine, 64)
            if ridx >= 0 and ridx < scnt
                sp = mem_read_idx(sptrs, ridx)
                if sp > 0
                    sys_free(sp)
                    mem_write_idx(sptrs, ridx, 0)
                end
                if scnt == ridx + 1
                    mem_write(engine, 48, ridx)
                end
            end
        end
        i = i - 1
    end

    // Rebuild all table secondary indexes after state restoration
    tcnt = mem_read(engine, 0)
    tptrs = mem_read(engine, 16)
    ti = 0
    while ti < tcnt
        tbl = mem_read_idx(tptrs, ti)
        if tbl > 0
            _sql_tbl_rebuild_all_indexes(tbl)
        end
        ti = ti + 1
    end

    twh = mem_read(engine, 112)
    if twh > 0
        mem_write(twh, 8, 0)
    end
    mem_write(engine, 96, 0)
    mem_write(engine, 80, 0)
    return 1

// ── 6. Relational O(N + M) Hash Join (INNER JOIN & LEFT JOIN) ─────────────────
// JoinResult Descriptor (32 bytes):
//   +0:  count (i64)
//   +8:  cap (i64)
//   +16: left_rows_ptr (i64 array of matching left row indices)
//   +24: right_rows_ptr (i64 array of matching right row indices, or -1 for unmatched LEFT JOIN)

fn _sql_join_push jr l_row r_row
    cnt = mem_read(jr, 0)
    cap = mem_read(jr, 8)
    lptr = mem_read(jr, 16)
    rptr = mem_read(jr, 24)
    if cnt >= cap
        ncap = cap * 2
        if ncap < 32 ncap = 32 end
        nl = sys_alloc(ncap * 8)
        nr = sys_alloc(ncap * 8)
        if cnt > 0
            mem_copy(nl, lptr, cnt * 8)
            mem_copy(nr, rptr, cnt * 8)
            sys_free(lptr)
            sys_free(rptr)
        end
        lptr = nl
        rptr = nr
        mem_write(jr, 8, ncap)
        mem_write(jr, 16, lptr)
        mem_write(jr, 24, rptr)
    end
    mem_write_idx(lptr, cnt, l_row)
    mem_write_idx(rptr, cnt, r_row)
    mem_write(jr, 0, cnt + 1)
    return 1

fn _sql_hash_join_impl engine left_tid left_col right_tid right_col is_left_join
    jr = sys_alloc(32)
    cap = 32
    mem_write(jr, 0, 0)
    mem_write(jr, 8, cap)
    mem_write(jr, 16, sys_alloc(cap * 8))
    mem_write(jr, 24, sys_alloc(cap * 8))

    ltbl = sql_get_table(engine, left_tid)
    rtbl = sql_get_table(engine, right_tid)
    if ltbl == 0 or rtbl == 0
        return jr
    end

    // Build phase: hash right table active rows on right_col (O(M))
    r_idx = _sql_idx_new(right_col, 1024)
    _sql_idx_rebuild(rtbl, r_idx)
    bcount = mem_read(r_idx, 8)
    bptr = mem_read(r_idx, 16)
    nptr = mem_read(r_idx, 24)

    l_rows = mem_read(ltbl, 16)
    l_cols = mem_read(ltbl, 8)
    l_data = mem_read(ltbl, 32)
    l_mask = mem_read(ltbl, 40)

    // Probe phase: stream left table active rows through right hash index (O(N))
    lr = 0
    while lr < l_rows
        if mem_byte_read(l_mask, lr) == 1
            lkey = mem_read_idx(l_data, (lr * l_cols) + left_col)
            b = _sql_idx_hash(lkey, bcount - 1)
            cur = mem_read_idx(bptr, b)
            matched = 0
            while cur >= 0
                noff = cur * 24
                if mem_read(nptr, noff + 0) == lkey
                    rr = mem_read(nptr, noff + 8)
                    _sql_join_push(jr, lr, rr)
                    matched = 1
                end
                cur = mem_read(nptr, noff + 16)
            end
            if matched == 0 and is_left_join == 1
                _sql_join_push(jr, lr, 0 - 1)
            end
        end
        lr = lr + 1
    end

    _sql_idx_free(r_idx)
    return jr

fn sql_inner_join engine left_tid left_col right_tid right_col
    return _sql_hash_join_impl(engine, left_tid, left_col, right_tid, right_col, 0)

fn sql_left_join engine left_tid left_col right_tid right_col
    return _sql_hash_join_impl(engine, left_tid, left_col, right_tid, right_col, 1)

fn sql_join_count jr
    if jr == 0 return 0 end
    return mem_read(jr, 0)

fn sql_join_left_row jr idx
    if jr == 0 or idx < 0 or idx >= mem_read(jr, 0) return 0 - 1 end
    return mem_read_idx(mem_read(jr, 16), idx)

fn sql_join_right_row jr idx
    if jr == 0 or idx < 0 or idx >= mem_read(jr, 0) return 0 - 1 end
    return mem_read_idx(mem_read(jr, 24), idx)

fn sql_join_free jr
    if jr == 0 return 0 end
    sys_free(mem_read(jr, 16))
    sys_free(mem_read(jr, 24))
    sys_free(jr)
    return 0

// ── 7. GROUP BY Aggregations (COUNT, SUM, MIN, MAX, AVG) ──────────────────────
// GroupResult Descriptor (56 bytes):
//   +0:  count (i64)
//   +8:  cap (i64)
//   +16: keys_ptr (i64 array)
//   +24: counts_ptr (i64 array)
//   +32: sums_ptr (i64 array)
//   +40: mins_ptr (i64 array)
//   +48: maxs_ptr (i64 array)

fn sql_group_by_agg engine table_id group_col agg_col
    gr = sys_alloc(56)
    cap = 32
    mem_write(gr, 0, 0)
    mem_write(gr, 8, cap)
    mem_write(gr, 16, sys_alloc(cap * 8))
    mem_write(gr, 24, sys_alloc(cap * 8))
    mem_write(gr, 32, sys_alloc(cap * 8))
    mem_write(gr, 40, sys_alloc(cap * 8))
    mem_write(gr, 48, sys_alloc(cap * 8))

    tbl = sql_get_table(engine, table_id)
    if tbl == 0 return gr end

    rows = mem_read(tbl, 16)
    cols = mem_read(tbl, 8)
    dbuf = mem_read(tbl, 32)
    mbuf = mem_read(tbl, 40)

    // O(1) group key -> group index hash map
    gmap = _sql_idx_new(0, 1024)

    r = 0
    while r < rows
        if mem_byte_read(mbuf, r) == 1
            gkey = mem_read_idx(dbuf, (r * cols) + group_col)
            aval = mem_read_idx(dbuf, (r * cols) + agg_col)

            // Lookup gkey in gmap
            bcount = mem_read(gmap, 8)
            bptr = mem_read(gmap, 16)
            nptr = mem_read(gmap, 24)
            b = _sql_idx_hash(gkey, bcount - 1)
            cur = mem_read_idx(bptr, b)
            gidx = 0 - 1
            while cur >= 0
                noff = cur * 24
                if mem_read(nptr, noff + 0) == gkey
                    gidx = mem_read(nptr, noff + 8)
                    break
                end
                cur = mem_read(nptr, noff + 16)
            end

            if gidx < 0
                gcnt = mem_read(gr, 0)
                gcap = mem_read(gr, 8)
                if gcnt >= gcap
                    ncap = gcap * 2
                    nk = sys_alloc(ncap * 8)
                    nc = sys_alloc(ncap * 8)
                    ns = sys_alloc(ncap * 8)
                    nmn = sys_alloc(ncap * 8)
                    nmx = sys_alloc(ncap * 8)
                    mem_copy(nk, mem_read(gr, 16), gcnt * 8)
                    mem_copy(nc, mem_read(gr, 24), gcnt * 8)
                    mem_copy(ns, mem_read(gr, 32), gcnt * 8)
                    mem_copy(nmn, mem_read(gr, 40), gcnt * 8)
                    mem_copy(nmx, mem_read(gr, 48), gcnt * 8)
                    sys_free(mem_read(gr, 16))
                    sys_free(mem_read(gr, 24))
                    sys_free(mem_read(gr, 32))
                    sys_free(mem_read(gr, 40))
                    sys_free(mem_read(gr, 48))
                    mem_write(gr, 8, ncap)
                    mem_write(gr, 16, nk)
                    mem_write(gr, 24, nc)
                    mem_write(gr, 32, ns)
                    mem_write(gr, 40, nmn)
                    mem_write(gr, 48, nmx)
                end
                gidx = gcnt
                mem_write_idx(mem_read(gr, 16), gidx, gkey)
                mem_write_idx(mem_read(gr, 24), gidx, 1)
                mem_write_idx(mem_read(gr, 32), gidx, aval)
                mem_write_idx(mem_read(gr, 40), gidx, aval)
                mem_write_idx(mem_read(gr, 48), gidx, aval)
                mem_write(gr, 0, gcnt + 1)
                _sql_idx_insert(gmap, gkey, gidx)
            else
                cptr = mem_read(gr, 24)
                sptr = mem_read(gr, 32)
                mnptr = mem_read(gr, 40)
                mxptr = mem_read(gr, 48)
                mem_write_idx(cptr, gidx, mem_read_idx(cptr, gidx) + 1)
                mem_write_idx(sptr, gidx, mem_read_idx(sptr, gidx) + aval)
                if aval < mem_read_idx(mnptr, gidx)
                    mem_write_idx(mnptr, gidx, aval)
                end
                if aval > mem_read_idx(mxptr, gidx)
                    mem_write_idx(mxptr, gidx, aval)
                end
            end
        end
        r = r + 1
    end

    _sql_idx_free(gmap)
    return gr

fn sql_group_count gr
    if gr == 0 return 0 end
    return mem_read(gr, 0)

fn sql_group_find gr key
    if gr == 0 return 0 - 1 end
    cnt = mem_read(gr, 0)
    kptr = mem_read(gr, 16)
    i = 0
    while i < cnt
        if mem_read_idx(kptr, i) == key
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn sql_group_key gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    return mem_read_idx(mem_read(gr, 16), idx)

fn sql_group_row_count gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    return mem_read_idx(mem_read(gr, 24), idx)

fn sql_group_sum gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    return mem_read_idx(mem_read(gr, 32), idx)

fn sql_group_min gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    return mem_read_idx(mem_read(gr, 40), idx)

fn sql_group_max gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    return mem_read_idx(mem_read(gr, 48), idx)

fn sql_group_avg gr idx
    if gr == 0 or idx < 0 or idx >= mem_read(gr, 0) return 0 end
    c = mem_read_idx(mem_read(gr, 24), idx)
    if c <= 0 return 0 end
    return mem_read_idx(mem_read(gr, 32), idx) / c

fn sql_group_free gr
    if gr == 0 return 0 end
    sys_free(mem_read(gr, 16))
    sys_free(mem_read(gr, 24))
    sys_free(mem_read(gr, 32))
    sys_free(mem_read(gr, 40))
    sys_free(mem_read(gr, 48))
    sys_free(gr)
    return 0

fn sql_execute_query engine query_str
    toks = sql_tokenize_text(query_str)
    n = toks.len()
    if n < 1 return 0 - 1 end
    cmd = get(toks, 0)

    if cmd == "BEGIN"
        return sql_begin(engine)
    elif cmd == "COMMIT"
        return sql_commit(engine)
    elif cmd == "ROLLBACK"
        return sql_rollback(engine)
    end
    if n < 2 return 0 - 1 end

    if cmd == "CREATE" and n >= 4 and get(toks, 1) == "INDEX"
        tid = sql_parse_int_tok(get(toks, 2))
        col_idx = sql_parse_int_tok(get(toks, 3))
        return sql_create_index(engine, tid, col_idx)
    elif cmd == "CREATE" and n >= 5
        tid = sql_parse_int_tok(get(toks, 2))
        cols = sql_parse_int_tok(get(toks, 3))
        mrows = sql_parse_int_tok(get(toks, 4))
        return sql_create_table(engine, tid, cols, mrows)
    elif cmd == "INSERT" and n >= 5
        tid = sql_parse_int_tok(get(toks, 2))
        vcnt = n - 4
        vb = sys_alloc(vcnt * 8)
        vi = 0
        while vi < vcnt
            mem_write_idx(vb, vi, sql_parse_int_tok(get(toks, 4 + vi)))
            vi = vi + 1
        end
        ins_rc = sql_insert_row_slice(engine, tid, vb, vcnt)
        sys_free(vb)
        return ins_rc
    elif cmd == "SELECT" and n >= 8
        ret_col = sql_parse_int_tok(get(toks, 1))
        tid = sql_parse_int_tok(get(toks, 3))
        filter_col = sql_parse_int_tok(get(toks, 5))
        target_val = sql_parse_int_tok(get(toks, 7))
        return sql_select_first_where_eq(engine, tid, filter_col, target_val, ret_col)
    elif cmd == "UPDATE" and n >= 10
        tid = sql_parse_int_tok(get(toks, 1))
        ucol = sql_parse_int_tok(get(toks, 3))
        uval = sql_parse_int_tok(get(toks, 5))
        fcol = sql_parse_int_tok(get(toks, 7))
        fval = sql_parse_int_tok(get(toks, 9))
        return sql_update_where_eq(engine, tid, fcol, fval, ucol, uval)
    elif cmd == "DELETE" and n >= 7
        tid = sql_parse_int_tok(get(toks, 2))
        filter_col = sql_parse_int_tok(get(toks, 4))
        target_val = sql_parse_int_tok(get(toks, 6))
        return sql_delete_where_eq(engine, tid, filter_col, target_val)
    elif cmd == "COUNT" and n >= 3
        tid = sql_parse_int_tok(get(toks, 2))
        return sql_count_active(engine, tid)
    end
    return 0 - 1
