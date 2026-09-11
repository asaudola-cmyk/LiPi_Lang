@! Maya Query Language — Simple SQL-like DSL

@struct Query
  q_table: string
  q_select: array
  q_where: string
  q_limit: i64
  q_order_by: string
  q_order_asc: i64
@end

@fn query_new(table_name)
  return {
    q_table: table_name,
    q_select: ["*"],
    q_where: "",
    q_limit: -1,
    q_order_by: "",
    q_order_asc: 1
  }
@end

@fn query_select(q, fields)
  q.q_select = fields
  return q
@end

@fn query_where(q, condition)
  q.q_where = condition
  return q
@end

@fn query_limit(q, n)
  q.q_limit = n
  return q
@end

@fn query_order_by(q, field, ascending)
  q.q_order_by = field
  q.q_order_asc = ascending
  return q
@end

@fn query_to_sql(q)
  sql = "SELECT "
  @if q.q_select.len() == 0
    sql = str_concat(sql, "*")
  @else
    i = 0
    @while i < q.q_select.len()
      @if i > 0
        sql = str_concat(sql, ", ")
      @end
      sql = str_concat(sql, q.q_select[i])
      i = i + 1
    @end
  @end
  sql = str_concat(sql, " FROM ")
  sql = str_concat(sql, q.q_table)
  @if q.q_where.len() > 0
    sql = str_concat(sql, " WHERE ")
    sql = str_concat(sql, q.q_where)
  @end
  @if q.q_order_by.len() > 0
    sql = str_concat(sql, " ORDER BY ")
    sql = str_concat(sql, q.q_order_by)
    @if q.q_order_asc == 0
      sql = str_concat(sql, " DESC")
    @end
  @end
  @if q.q_limit > 0
    sql = str_concat(sql, " LIMIT ")
    sql = str_concat(sql, int_to_str(q.q_limit))
  @end
  return sql
@end

@fn query_count_sql(q)
  where_part = ""
  @if q.q_where.len() > 0
    where_part = str_concat(" WHERE ", q.q_where)
  @end
  return str_concat(str_concat("SELECT COUNT(*) FROM ", q.q_table), where_part)
@end
