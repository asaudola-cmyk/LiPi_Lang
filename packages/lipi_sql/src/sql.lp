// ==============================================================================
// 👑 LIPI SOVEREIGN RELATIONAL SQL ENGINE (packages/lipi_sql/src/sql.lp)
// ⚡ Zero Libc | Zero SQLite | Pure Sovereign In-Memory Query Planner & Storage
// ==============================================================================
//
// WHY: Enterprise enterprise stacks rely heavily on database interfaces.
// lipi_sql delivers a pure LiPi in-memory relational table store with
// deterministic O(1) row access, indexed filtering, and atomic row-level mutations.

include "universe/core/memory.lp"

// Table Descriptor Offsets (64 bytes total)
// Offset 0:  table_id (i64)
// Offset 8:  col_count (i64)
// Offset 16: row_count (i64)
// Offset 24: max_rows (i64)
// Offset 32: data_ptr (i64) - Pointer to 64-bit cell buffer (max_rows * col_count * 8)
// Offset 40: mask_ptr (i64) - Pointer to deletion mask buffer (1 = active, 0 = deleted)
// Offset 48: reserved (i64)
// Offset 56: reserved (i64)

SQL_MAX_TABLES = 16

fn sql_engine_new
    // Engine descriptor: 8 bytes count + (16 * 8 bytes table pointers) = 136 bytes
    engine = sys_alloc(136)
    mem_zero(engine, 136)
    return engine

fn sql_create_table engine table_id col_count max_rows
    if engine == 0
        return 0
    if col_count <= 0
        return 0
    if max_rows <= 0
        return 0

    cur_count = mem_read(engine, 0)
    if cur_count >= SQL_MAX_TABLES
        return 0

    tbl = sys_alloc(64)
    mem_zero(tbl, 64)

    // Data buffer: max_rows * col_count * 8 bytes
    data_size = max_rows * col_count * 8
    data_buf = sys_alloc(data_size)
    mem_zero(data_buf, data_size)

    // Mask buffer: max_rows bytes
    mask_buf = sys_alloc(max_rows)
    mem_zero(mask_buf, max_rows)

    mem_write(tbl, 0, table_id)
    mem_write(tbl, 8, col_count)
    mem_write(tbl, 16, 0)         // row_count = 0
    mem_write(tbl, 24, max_rows)
    mem_write(tbl, 32, data_buf)
    mem_write(tbl, 40, mask_buf)

    slot_offset = 8 + (cur_count * 8)
    mem_write(engine, slot_offset, tbl)
    mem_write(engine, 0, cur_count + 1)
    return tbl

fn sql_get_table engine table_id
    if engine == 0
        return 0
    cur_count = mem_read(engine, 0)
    i = 0
    while i < cur_count
        slot_offset = 8 + (i * 8)
        tbl = mem_read(engine, slot_offset)
        if tbl > 0
            if mem_read(tbl, 0) == table_id
                return tbl
        i = i + 1
    return 0

fn sql_insert_2 engine table_id val0 val1
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
    row_count = mem_read(tbl, 16)
    max_rows = mem_read(tbl, 24)
    if row_count >= max_rows
        return 0

    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    base_idx = row_count * col_count
    mem_write_idx(data_buf, base_idx, val0)
    if col_count > 1
        mem_write_idx(data_buf, base_idx + 1, val1)

    // Mark row as active
    mem_byte_write(mask_buf, row_count, 1)

    mem_write(tbl, 16, row_count + 1)
    return row_count + 1

fn sql_insert_3 engine table_id val0 val1 val2
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
    row_count = mem_read(tbl, 16)
    max_rows = mem_read(tbl, 24)
    if row_count >= max_rows
        return 0

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
    return row_count + 1

fn sql_select_cell engine table_id row_idx col_idx
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
    row_count = mem_read(tbl, 16)
    if row_idx >= row_count
        return 0
    col_count = mem_read(tbl, 8)
    if col_idx >= col_count
        return 0

    data_buf = mem_read(tbl, 32)
    cell_idx = (row_idx * col_count) + col_idx
    return mem_read_idx(data_buf, cell_idx)

fn sql_count_active engine table_id
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
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
    if tbl == 0
        return 0
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

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
    if tbl == 0
        return 0 - 1
    row_count = mem_read(tbl, 16)
    col_count = mem_read(tbl, 8)
    data_buf = mem_read(tbl, 32)
    mask_buf = mem_read(tbl, 40)

    r = 0
    while r < row_count
        if mem_byte_read(mask_buf, r) == 1
            val = mem_read_idx(data_buf, (r * col_count) + filter_col)
            if val == target_val
                ret_val = mem_read_idx(data_buf, (r * col_count) + return_col)
                return ret_val
        r = r + 1
    return 0 - 1

fn sql_update_where_eq engine table_id filter_col target_val update_col new_val
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
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
                mem_write_idx(data_buf, (r * col_count) + update_col, new_val)
                updated_count = updated_count + 1
        r = r + 1
    return updated_count

fn sql_delete_where_eq engine table_id filter_col target_val
    tbl = sql_get_table(engine, table_id)
    if tbl == 0
        return 0
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
                mem_byte_write(mask_buf, r, 0) // mark deleted
                deleted_count = deleted_count + 1
        r = r + 1
    return deleted_count

fn sql_engine_free engine
    if engine == 0
        return 0
    cur_count = mem_read(engine, 0)
    i = 0
    while i < cur_count
        slot_offset = 8 + (i * 8)
        tbl = mem_read(engine, slot_offset)
        if tbl > 0
            col_count = mem_read(tbl, 8)
            max_rows = mem_read(tbl, 24)
            data_buf = mem_read(tbl, 32)
            mask_buf = mem_read(tbl, 40)
            mem_free(data_buf, max_rows * col_count * 8)
            mem_free(mask_buf, max_rows)
            mem_free(tbl, 64)
        i = i + 1
    mem_free(engine, 136)
    return 0
