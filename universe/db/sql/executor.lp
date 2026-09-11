@! ============================================================================
@! LIPI UNIVERSE DB - SQL EXECUTOR (universe/db/sql/executor.maya)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct ExecutorContext
  catalog: {},
  stats: {}
@end

@fn new_executor_context()
  return {
    catalog: {},
    stats: {}
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
    @if filter_col == "" || filter_val == 0
      res = res.push(row)
    @elif row.contains(filter_col) && row[filter_col] == filter_val
      res = res.push(row)
    @end
    i = i + 1
  @end
  return res
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
    new_row = {}
    c = 0
    @while c < column_names.len()
      col = column_names[c]
      @if row.contains(col)
        new_row[col] = row[col]
      @end
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

  @! 1. Build hash table on left table
  hash_table = {}
  i = 0
  @while i < left_rows.len()
    l_row = left_rows[i]
    @if l_row.contains(left_col)
      k = l_row[left_col].to_str()
      @if !hash_table.contains(k)
        hash_table[k] = []
      @end
      hash_table[k] = hash_table[k].push(l_row)
    @end
    i = i + 1
  @end

  @! 2. Probe hash table with right table
  joined = []
  j = 0
  @while j < right_rows.len()
    r_row = right_rows[j]
    @if r_row.contains(right_col)
      rk = r_row[right_col].to_str()
      @if hash_table.contains(rk)
        matches = hash_table[rk]
        m = 0
        @while m < matches.len()
          combined = {}
          @for pair in matches[m]
            combined[pair.key] = pair.value
          @end
          __pair_idx = 0
          __pair_len = r_row.len()
          @while __pair_idx < __pair_len
            pair = r_row[__pair_idx]
            combined[pair.key] = pair.value
            __pair_idx = __pair_idx + 1
          @end
          joined = joined.push(combined)
          m = m + 1
        @end
      @end
    @end
    j = j + 1
  @end

  return joined
@end