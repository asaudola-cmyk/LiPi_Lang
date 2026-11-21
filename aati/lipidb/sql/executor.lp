@! ============================================================================
@! LIPI UNIVERSE DB - SQL EXECUTOR (aati/lipidb/sql/executor.lp)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "utso/collections"
import "utso/string"
import "aati/lipidb/sql/parser"

@struct ExecutorContext
  exec_tables: array
  exec_stats: array
@end

@struct KvIndexEntry
  kv_key: i64
  kv_val: i64
@end

@struct SqlCell
  scell_col: string
  scell_val: any
  scell_kind: string
@end

@struct SqlTable
  stbl_name: string
  stbl_cols: array
  stbl_rows: array
  stbl_active: i64
@end

@struct SqlExecResult
  sres_ok: i64
  sres_rows: array
  sres_affected: i64
  sres_error: string
@end

@fn new_executor_context() -> ExecutorContext
  return {
    exec_tables: [],
    exec_stats: []
  }
@end

@fn executor_seq_scan(table_rows, filter_col, filter_val)
  @if table_rows == 0
    return []
  @end

  res = []
  i = 0
  n = table_rows.len()
  @while i < n
    row = table_rows[i]
    @if filter_col < 0
      res = res.push(row)
    @elif filter_col < row.len() && row[filter_col] == filter_val
      res = res.push(row)
    @end
    i = i + 1
  @end
  return res
@end

@fn sql_row_get_cell(row, col_name) -> SqlCell
  @if row != 0
    i = 0
    n = row.len()
    @while i < n
      cell: SqlCell = row[i]
      @if cell.scell_col == col_name
        return cell
      @end
      i = i + 1
    @end
  @end
  return { scell_col: col_name, scell_val: 0, scell_kind: "i64" }
@end

@fn sql_row_get(row, col_name)
  cell: SqlCell = sql_row_get_cell(row, col_name)
  return cell.scell_val
@end

@fn sql_row_set(row, col_name, val, kind_tag)
  i = 0
  n = row.len()
  @while i < n
    cell: SqlCell = row[i]
    @if cell.scell_col == col_name
      upd: SqlCell = { scell_col: col_name, scell_val: val, scell_kind: kind_tag }
      return list_set(row, i, upd)
    @end
    i = i + 1
  @end
  nc: SqlCell = { scell_col: col_name, scell_val: val, scell_kind: kind_tag }
  return row.push(nc)
@end

@fn executor_project(rows, column_names)
  @if rows == 0
    return []
  @end
  @if column_names == 0 || column_names.len() == 0
    return rows
  @end

  out = []
  i = 0
  n = rows.len()
  @while i < n
    row = rows[i]
    new_row = []
    c = 0
    @while c < column_names.len()
      col = column_names[c]
      new_row = new_row.push(sql_row_get_cell(row, col))
      c = c + 1
    @end
    out = out.push(new_row)
    i = i + 1
  @end
  return out
@end

@fn executor_hash_join(left_rows, right_rows, left_col, right_col)
  @if left_rows == 0 || right_rows == 0
    return []
  @end
  joined = []
  i = 0
  @while i < left_rows.len()
    l_row = left_rows[i]
    lv = sql_row_get(l_row, left_col)
    j = 0
    @while j < right_rows.len()
      r_row = right_rows[j]
      rv = sql_row_get(r_row, right_col)
      @if lv == rv
        combined = []
        k = 0
        @while k < l_row.len()
          combined = combined.push(l_row[k])
          k = k + 1
        @end
        k = 0
        @while k < r_row.len()
          rc: SqlCell = r_row[k]
          combined = sql_row_set(combined, rc.scell_col, rc.scell_val, rc.scell_kind)
          k = k + 1
        @end
        joined = joined.push(combined)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return joined
@end

@fn kv_index_entry_new(k, v)
  e = KvIndexEntry()
  e.kv_key = k
  e.kv_val = v
  return e
@end

@fn executor_kv_index_lookup(index_entries, target_key)
  // WHY: Connects relational SQL execution directly to B+Tree / KV storage scan entries (KvIndexEntry).
  @if index_entries == 0
    return []
  @end
  matches = []
  i = 0
  n = index_entries.len()
  @while i < n
    entry = index_entries[i]
    @if entry.kv_key == target_key
      matches = matches.push(entry.kv_val)
    @end
    i = i + 1
  @end
  return matches
@end

@fn executor_aggregate_sum(rows, col_idx)
  // WHY: Executes vectorized SUM(col) aggregation over scanned table rows.
  @if rows == 0 || col_idx < 0
    return 0
  @end
  total = 0
  i = 0
  n = rows.len()
  @while i < n
    row = rows[i]
    @if col_idx < row.len()
      total = total + row[col_idx]
    @end
    i = i + 1
  @end
  return total
@end

@! ----------------------------------------------------------------------------
@! End-to-End SQL Execution Engine (CREATE, INSERT, SELECT, UPDATE, DELETE)
@! ----------------------------------------------------------------------------

@fn _sql_i2f(x: i64) -> f64 return x * 1.0 @end
@fn _sql_fadd(a: f64, b: f64) -> f64 return a + b @end
@fn _sql_fsub(a: f64, b: f64) -> f64 return a - b @end
@fn _sql_fmul(a: f64, b: f64) -> f64 return a * b @end
@fn _sql_fdiv(a: f64, b: f64) -> f64 return a / b @end
@fn _sql_flt(a: f64, b: f64) -> i64 @if a < b return 1 @end return 0 @end
@fn _sql_fgt(a: f64, b: f64) -> i64 @if a > b return 1 @end return 0 @end
@fn _sql_feq(a: f64, b: f64) -> i64 @if a == b return 1 @end return 0 @end

@fn _sql_cell(v, kind_tag) -> SqlCell
  return { scell_col: "", scell_val: v, scell_kind: kind_tag }
@end

@fn _sql_to_num(tv: SqlCell) -> f64
  @if tv.scell_kind == "f64"
    return tv.scell_val
  @elif tv.scell_kind == "i64"
    return _sql_i2f(tv.scell_val)
  @elif tv.scell_kind == "str"
    @if str_contains(tv.scell_val, ".") == 1
      return str_to_float(tv.scell_val)
    @end
    return _sql_i2f(str_to_int(tv.scell_val))
  @end
  return _sql_i2f(0)
@end

@fn _sql_is_truthy(tv: SqlCell) -> i64
  @if tv.scell_kind == "i64"
    @if tv.scell_val != 0 return 1 @end
    return 0
  @elif tv.scell_kind == "f64"
    @if _sql_feq(tv.scell_val, _sql_i2f(0)) == 0 return 1 @end
    return 0
  @elif tv.scell_kind == "str"
    @if str_len(tv.scell_val) > 0 return 1 @end
    return 0
  @end
  return 0
@end

@fn _sql_cmp_vals(lv: SqlCell, rv: SqlCell) -> i64
  @if lv.scell_kind == "str" && rv.scell_kind == "str"
    @if lv.scell_val == rv.scell_val return 0 @end
    na = str_len(lv.scell_val)
    nb = str_len(rv.scell_val)
    min_n = na
    @if nb < min_n min_n = nb @end
    i = 0
    @while i < min_n
      ca = str_char_at(lv.scell_val, i) & 255
      cb = str_char_at(rv.scell_val, i) & 255
      @if ca < cb return -1 @end
      @if ca > cb return 1 @end
      i = i + 1
    @end
    @if na < nb return -1 @end
    return 1
  @end
  @if lv.scell_kind == "i64" && rv.scell_kind == "i64"
    @if lv.scell_val < rv.scell_val return -1 @end
    @if lv.scell_val > rv.scell_val return 1 @end
    return 0
  @end
  lf = _sql_to_num(lv)
  rf = _sql_to_num(rv)
  @if _sql_flt(lf, rf) == 1 return -1 @end
  @if _sql_fgt(lf, rf) == 1 return 1 @end
  return 0
@end

@fn sql_eval_typed(expr: SqlExpr, row) -> SqlCell
  @if expr == 0
    return _sql_cell(1, "i64")
  @end
  et = expr.expr_type
  @if et == "Literal"
    @if expr.expr_lit_type == "STRING"
      return _sql_cell(expr.expr_val, "str")
    @end
    s_v = expr.expr_val
    @if str_contains(s_v, ".") == 1
      return _sql_cell(str_to_float(s_v), "f64")
    @end
    return _sql_cell(str_to_int(s_v), "i64")
  @elif et == "Identifier"
    return sql_row_get_cell(row, expr.expr_name)
  @elif et == "UnaryOp"
    sub = sql_eval_typed(expr.expr_left, row)
    op_u = string_to_upper(expr.expr_op)
    @if op_u == "NOT"
      @if _sql_is_truthy(sub) == 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == "-"
      @if sub.scell_kind == "f64"
        return _sql_cell(_sql_fsub(_sql_i2f(0), sub.scell_val), "f64")
      @end
      return _sql_cell(0 - sub.scell_val, "i64")
    @end
    return sub
  @elif et == "BinaryOp"
    op_up = string_to_upper(expr.expr_op)
    @if op_up == "AND"
      lv = sql_eval_typed(expr.expr_left, row)
      @if _sql_is_truthy(lv) == 0 return _sql_cell(0, "i64") @end
      rv = sql_eval_typed(expr.expr_right, row)
      @if _sql_is_truthy(rv) == 1 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif op_up == "OR"
      lv = sql_eval_typed(expr.expr_left, row)
      @if _sql_is_truthy(lv) == 1 return _sql_cell(1, "i64") @end
      rv = sql_eval_typed(expr.expr_right, row)
      @if _sql_is_truthy(rv) == 1 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @end

    lv = sql_eval_typed(expr.expr_left, row)
    rv = sql_eval_typed(expr.expr_right, row)
    @if expr.expr_op == "="
      @if _sql_cmp_vals(lv, rv) == 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == "!=" || expr.expr_op == "<>"
      @if _sql_cmp_vals(lv, rv) != 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == "<"
      @if _sql_cmp_vals(lv, rv) < 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == "<="
      @if _sql_cmp_vals(lv, rv) <= 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == ">"
      @if _sql_cmp_vals(lv, rv) > 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == ">="
      @if _sql_cmp_vals(lv, rv) >= 0 return _sql_cell(1, "i64") @end
      return _sql_cell(0, "i64")
    @elif expr.expr_op == "+"
      @if lv.scell_kind == "i64" && rv.scell_kind == "i64"
        return _sql_cell(lv.scell_val + rv.scell_val, "i64")
      @end
      return _sql_cell(_sql_fadd(_sql_to_num(lv), _sql_to_num(rv)), "f64")
    @elif expr.expr_op == "-"
      @if lv.scell_kind == "i64" && rv.scell_kind == "i64"
        return _sql_cell(lv.scell_val - rv.scell_val, "i64")
      @end
      return _sql_cell(_sql_fsub(_sql_to_num(lv), _sql_to_num(rv)), "f64")
    @elif expr.expr_op == "*"
      @if lv.scell_kind == "i64" && rv.scell_kind == "i64"
        return _sql_cell(lv.scell_val * rv.scell_val, "i64")
      @end
      return _sql_cell(_sql_fmul(_sql_to_num(lv), _sql_to_num(rv)), "f64")
    @elif expr.expr_op == "/"
      @if lv.scell_kind == "i64" && rv.scell_kind == "i64"
        @if rv.scell_val == 0 return _sql_cell(0, "i64") @end
        return _sql_cell(lv.scell_val / rv.scell_val, "i64")
      @end
      rf = _sql_to_num(rv)
      @if _sql_feq(rf, _sql_i2f(0)) == 1 return _sql_cell(_sql_i2f(0), "f64") @end
      return _sql_cell(_sql_fdiv(_sql_to_num(lv), rf), "f64")
    @end
  @end
  return _sql_cell(0, "i64")
@end

@fn sql_eval_expr(expr: SqlExpr, row)
  tv = sql_eval_typed(expr, row)
  return tv.scell_val
@end

@fn _sql_find_table_idx(ctx: ExecutorContext, tbl_name)
  i = 0
  n = ctx.exec_tables.len()
  @while i < n
    t: SqlTable = ctx.exec_tables[i]
    @if t.stbl_name == tbl_name && t.stbl_active == 1
      return i
    @end
    i = i + 1
  @end
  return -1
@end

@fn sql_execute(ctx: ExecutorContext, sql_str) -> SqlExecResult
  stmt: SqlStmt = parse_sql(sql_str)
  st = stmt.stmt_type

  @if st == "CreateTableStmt"
    cols = []
    i = 0
    @while i < stmt.stmt_columns.len()
      cs: SqlColSpec = stmt.stmt_columns[i]
      cols = cols.push(cs.scs_name)
      i = i + 1
    @end
    new_tbl: SqlTable = { stbl_name: stmt.stmt_table, stbl_cols: cols, stbl_rows: [], stbl_active: 1 }
    ctx.exec_tables = ctx.exec_tables.push(new_tbl)
    return { sres_ok: 1, sres_rows: [], sres_affected: 0, sres_error: "" }
  @end

  @if st == "DropTableStmt"
    tidx = _sql_find_table_idx(ctx, stmt.stmt_table)
    @if tidx >= 0
      t: SqlTable = ctx.exec_tables[tidx]
      t.stbl_active = 0
      ctx.exec_tables = list_set(ctx.exec_tables, tidx, t)
    @end
    return { sres_ok: 1, sres_rows: [], sres_affected: 0, sres_error: "" }
  @end

  @if st == "InsertStmt"
    tidx = _sql_find_table_idx(ctx, stmt.stmt_table)
    @if tidx < 0
      return { sres_ok: 0, sres_rows: [], sres_affected: 0, sres_error: "Table not found" }
    @end
    tbl: SqlTable = ctx.exec_tables[tidx]
    col_names = stmt.stmt_columns
    @if col_names.len() == 0
      col_names = tbl.stbl_cols
    @end
    added = 0
    ri = 0
    @while ri < stmt.stmt_values.len()
      val_list = stmt.stmt_values[ri]
      new_row = []
      ci = 0
      @while ci < col_names.len() && ci < val_list.len()
        ev: SqlCell = sql_eval_typed(val_list[ci], [])
        new_row = sql_row_set(new_row, col_names[ci], ev.scell_val, ev.scell_kind)
        ci = ci + 1
      @end
      tbl.stbl_rows = tbl.stbl_rows.push(new_row)
      added = added + 1
      ri = ri + 1
    @end
    ctx.exec_tables = list_set(ctx.exec_tables, tidx, tbl)
    return { sres_ok: 1, sres_rows: [], sres_affected: added, sres_error: "" }
  @end

  @if st == "UpdateStmt"
    tidx = _sql_find_table_idx(ctx, stmt.stmt_table)
    @if tidx < 0
      return { sres_ok: 0, sres_rows: [], sres_affected: 0, sres_error: "Table not found" }
    @end
    tbl: SqlTable = ctx.exec_tables[tidx]
    updated = 0
    ri = 0
    @while ri < tbl.stbl_rows.len()
      row = tbl.stbl_rows[ri]
      match = 1
      @if stmt.stmt_where != 0
        match = _sql_is_truthy(sql_eval_typed(stmt.stmt_where, row))
      @end
      @if match == 1
        ai = 0
        @while ai < stmt.stmt_assignments.len()
          asg: SqlAssignSpec = stmt.stmt_assignments[ai]
          ev: SqlCell = sql_eval_typed(asg.sas_value, row)
          row = sql_row_set(row, asg.sas_column, ev.scell_val, ev.scell_kind)
          ai = ai + 1
        @end
        tbl.stbl_rows = list_set(tbl.stbl_rows, ri, row)
        updated = updated + 1
      @end
      ri = ri + 1
    @end
    ctx.exec_tables = list_set(ctx.exec_tables, tidx, tbl)
    return { sres_ok: 1, sres_rows: [], sres_affected: updated, sres_error: "" }
  @end

  @if st == "DeleteStmt"
    tidx = _sql_find_table_idx(ctx, stmt.stmt_table)
    @if tidx < 0
      return { sres_ok: 0, sres_rows: [], sres_affected: 0, sres_error: "Table not found" }
    @end
    tbl: SqlTable = ctx.exec_tables[tidx]
    kept = []
    deleted = 0
    ri = 0
    @while ri < tbl.stbl_rows.len()
      row = tbl.stbl_rows[ri]
      match = 1
      @if stmt.stmt_where != 0
        match = _sql_is_truthy(sql_eval_typed(stmt.stmt_where, row))
      @end
      @if match == 1
        deleted = deleted + 1
      @else
        kept = kept.push(row)
      @end
      ri = ri + 1
    @end
    tbl.stbl_rows = kept
    ctx.exec_tables = list_set(ctx.exec_tables, tidx, tbl)
    return { sres_ok: 1, sres_rows: [], sres_affected: deleted, sres_error: "" }
  @end

  @if st == "SelectStmt"
    tidx = _sql_find_table_idx(ctx, stmt.stmt_table)
    @if tidx < 0
      return { sres_ok: 0, sres_rows: [], sres_affected: 0, sres_error: "Table not found" }
    @end
    tbl: SqlTable = ctx.exec_tables[tidx]
    matched = []
    ri = 0
    @while ri < tbl.stbl_rows.len()
      row = tbl.stbl_rows[ri]
      keep = 1
      @if stmt.stmt_where != 0
        keep = _sql_is_truthy(sql_eval_typed(stmt.stmt_where, row))
      @end
      @if keep == 1
        matched = matched.push(row)
      @end
      ri = ri + 1
    @end

    @if stmt.stmt_order_by.len() > 0
      ob: SqlOrderSpec = stmt.stmt_order_by[0]
      mn = matched.len()
      si = 0
      @while si < mn
        sj = si + 1
        @while sj < mn
          ra = matched[si]
          rb = matched[sj]
          va = sql_row_get_cell(ra, ob.sos_column)
          vb = sql_row_get_cell(rb, ob.sos_column)
          c_res = _sql_cmp_vals(va, vb)
          should_swap = 0
          @if ob.sos_ascending == 1 && c_res > 0 should_swap = 1 @end
          @if ob.sos_ascending == 0 && c_res < 0 should_swap = 1 @end
          @if should_swap == 1
            matched = list_set(matched, si, rb)
            matched = list_set(matched, sj, ra)
          @end
          sj = sj + 1
        @end
        si = si + 1
      @end
    @end

    out_rows = []
    start_idx = stmt.stmt_offset
    @if start_idx < 0 start_idx = 0 @end
    end_idx = matched.len()
    @if stmt.stmt_limit >= 0 && (start_idx + stmt.stmt_limit) < end_idx
      end_idx = start_idx + stmt.stmt_limit
    @end

    is_star = 0
    @if stmt.stmt_columns.len() == 1
      c0: SqlColSpec = stmt.stmt_columns[0]
      @if c0.scs_name == "*"
        is_star = 1
      @end
    @end

    ri = start_idx
    @while ri < end_idx
      raw_r = matched[ri]
      proj_r = []
      @if is_star == 1
        ci = 0
        @while ci < tbl.stbl_cols.len()
          cname = tbl.stbl_cols[ci]
          proj_r = proj_r.push(sql_row_get_cell(raw_r, cname))
          ci = ci + 1
        @end
      @else
        ci = 0
        @while ci < stmt.stmt_columns.len()
          col_item: SqlColSpec = stmt.stmt_columns[ci]
          key_name = col_item.scs_alias
          @if key_name == ""
            @if col_item.scs_name != ""
              key_name = col_item.scs_name
            @else
              key_name = "col_" + to_str(ci)
            @end
          @end
          ev: SqlCell = sql_eval_typed(col_item.scs_expr, raw_r)
          proj_r = sql_row_set(proj_r, key_name, ev.scell_val, ev.scell_kind)
          ci = ci + 1
        @end
      @end
      out_rows = out_rows.push(proj_r)
      ri = ri + 1
    @end
    return { sres_ok: 1, sres_rows: out_rows, sres_affected: out_rows.len(), sres_error: "" }
  @end

  return { sres_ok: 0, sres_rows: [], sres_affected: 0, sres_error: "Unsupported statement: " + st }
@end
