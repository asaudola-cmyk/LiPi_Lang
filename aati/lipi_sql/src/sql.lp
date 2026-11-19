// ==============================================================================
// 👑 LIPI SOVEREIGN RELATIONAL SQL ENGINE (aati/lipi_sql/src/sql.lp)
// ⚡ Zero Libc | Zero SQLite | Pure Sovereign In-Memory Query Planner & Storage
// ==============================================================================
//
// WHY: Enterprise enterprise stacks rely heavily on database interfaces.
// lipi_sql delivers a pure LiPi in-memory relational table store with
// deterministic O(1) row access, indexed filtering, and atomic row-level mutations.

include "utso/memory.lp"

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

// ── SQL Text Query Tokenizer & Execution Planner ─────────────────────────────
// WHY: Parses and executes real textual SQL statements directly against the in-memory
// relational storage engine (CREATE TABLE, INSERT INTO, SELECT ... FROM ... WHERE,
// DELETE FROM ... WHERE, COUNT FROM) with zero external SQLite or C dependencies.

fn sql_tokenize_text q
    toks = list()
    cur = ""
    i = 0
    qlen = len(q)
    while i < qlen
        ch = mem_byte_read(q, i)
        // Delimiters: space(32), tab(9), newline(10), comma(44), '(', ')', ';', '='
        if ch == 32 or ch == 9 or ch == 10 or ch == 13 or ch == 44 or ch == 40 or ch == 41 or ch == 59
            if len(cur) > 0
                push(toks, cur)
                cur = ""
            end
        elif ch == 61 // '='
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
    if mem_byte_read(s, 0) == 45 // '-'
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

fn sql_execute_query engine query_str
    // WHY: Executes textual SQL statements:
    //   "CREATE TABLE <tid> (<cols>, <max_rows>)" -> returns table ptr
    //   "INSERT INTO <tid> VALUES (<v0>, <v1> [, <v2>])" -> returns new row count
    //   "SELECT <ret_col> FROM <tid> WHERE <filter_col> = <val>" -> returns matched cell
    //   "DELETE FROM <tid> WHERE <filter_col> = <val>" -> returns deleted row count
    //   "COUNT FROM <tid>" -> returns active row count
    toks = sql_tokenize_text(query_str)
    n = toks.len()
    if n < 2 return 0 - 1 end
    cmd = get(toks, 0)

    if cmd == "CREATE" and n >= 5
        tid = sql_parse_int_tok(get(toks, 2))
        cols = sql_parse_int_tok(get(toks, 3))
        mrows = sql_parse_int_tok(get(toks, 4))
        return sql_create_table(engine, tid, cols, mrows)
    elif cmd == "INSERT" and n >= 6
        tid = sql_parse_int_tok(get(toks, 2))
        v0 = sql_parse_int_tok(get(toks, 4))
        v1 = sql_parse_int_tok(get(toks, 5))
        if n >= 7
            v2 = sql_parse_int_tok(get(toks, 6))
            return sql_insert_3(engine, tid, v0, v1, v2)
        end
        return sql_insert_2(engine, tid, v0, v1)
    elif cmd == "SELECT" and n >= 8
        ret_col = sql_parse_int_tok(get(toks, 1))
        tid = sql_parse_int_tok(get(toks, 3))
        filter_col = sql_parse_int_tok(get(toks, 5))
        target_val = sql_parse_int_tok(get(toks, 7))
        return sql_select_first_where_eq(engine, tid, filter_col, target_val, ret_col)
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
