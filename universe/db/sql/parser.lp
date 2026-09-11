@! ============================================================================
@! MAYA UNIVERSE DB - SQL RECURSIVE-DESCENT PARSER (universe/db/sql/parser.maya)
@! Standard: 100% Pure Maya SQL AST Parser
@! ============================================================================

import "universe/db/sql/lexer"
import "universe/core/string"
import "universe/core/collections"

@struct Parser
  lexer: 0
  current: 0
  peek: 0
@end

@fn parser_new(lexer)
  p = { lexer: lexer, current: 0, peek: 0 }
  parser_advance(p)
  parser_advance(p)
  return p
@end

@fn parser_advance(p)
  p.current = p.peek
  p.peek = lexer_next_token(p.lexer)
@end

@fn parser_expect(p, kind)
  @if p.current.kind == kind
    parser_advance(p)
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! Expression Parsing: Operator Precedence & Recursive Descent
@! ----------------------------------------------------------------------------

@fn parse_primary(p)
  cur = p.current
  @if cur.kind == "NUMBER"
    parser_advance(p)
    return { type: "Literal", val: cur.value, lit_type: "NUMBER" }
  @elif cur.kind == "STRING"
    parser_advance(p)
    return { type: "Literal", val: cur.value, lit_type: "STRING" }
  @elif cur.kind == "IDENT"
    parser_advance(p)
    return { type: "Identifier", name: cur.value }
  @elif cur.kind == "STAR"
    parser_advance(p)
    return { type: "Identifier", name: "*" }
  @elif cur.kind == "LPAREN"
    parser_advance(p)
    expr = parse_expr(p)
    parser_expect(p, "RPAREN")
    return expr
  @end
  parser_advance(p)
  return { type: "Literal", val: "0", lit_type: "NUMBER" }
@end

@fn parse_unary(p)
  cur = p.current
  @if cur.kind == "NOT" || (cur.kind == "CHAR" && cur.value == "-") || (cur.kind == "CHAR" && cur.value == "+")
    op = cur.value
    parser_advance(p)
    operand = parse_unary(p)
    return { type: "UnaryOp", op: op, expr: operand }
  @end
  return parse_primary(p)
@end

@fn get_token_precedence(p)
  k = p.current.kind
  v = p.current.value
  @if k == "OR" return 1 @end
  @if k == "AND" return 2 @end
  @if k == "EQ" || k == "GT" || k == "GTE" || k == "LT" || k == "LTE" return 3 @end
  @if k == "CHAR" && (v == "+" || v == "-") return 4 @end
  @if k == "STAR" || (k == "CHAR" && (v == "/" || v == "%")) return 5 @end
  return 0
@end

@fn parse_expr_prec(p, min_prec)
  left = parse_unary(p)
  @while 1
    prec = get_token_precedence(p)
    @if prec < min_prec || prec == 0
      break
    @end
    op_token = p.current
    op_str = op_token.value
    parser_advance(p)
    right = parse_expr_prec(p, prec + 1)
    left = { type: "BinaryOp", op: op_str, left: left, right: right }
  @end
  return left
@end

@fn parse_expr(p)
  return parse_expr_prec(p, 1)
@end

@fn parse_binary_op(p, precedence)
  return parse_expr_prec(p, precedence)
@end

@! ----------------------------------------------------------------------------
@! 12 SQL Statement Parsers
@! ----------------------------------------------------------------------------

@! 1. SELECT Statement
@fn parse_select_stmt(p)
  @if p.current.kind == "SELECT" parser_advance(p) @end
  distinct = 0
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "DISTINCT"
    distinct = 1
    parser_advance(p)
  @end

  columns = []
  @if p.current.kind == "STAR"
    columns = columns.push({ expr: { type: "Identifier", name: "*" }, alias: "" })
    parser_advance(p)
  @else
    @while 1
      col_expr = parse_expr(p)
      alias = ""
      @if p.current.kind == "IDENT" && (string_to_upper(p.current.value) == "AS")
        parser_advance(p)
        @if p.current.kind == "IDENT"
          alias = p.current.value
          parser_advance(p)
        @end
      @end
      columns = columns.push({ expr: col_expr, alias: alias })
      @if p.current.kind == "COMMA"
        parser_advance(p)
      @else
        break
      @end
    @end
  @end

  from_table = ""
  from_alias = ""
  @if p.current.kind == "FROM"
    parser_advance(p)
    @if p.current.kind == "IDENT"
      from_table = p.current.value
      parser_advance(p)
      @if p.current.kind == "IDENT" && p.current.value != "WHERE" && p.current.value != "JOIN" && p.current.value != "ORDER" && p.current.value != "GROUP" && p.current.value != "LIMIT" && p.current.value != "INNER" && p.current.value != "LEFT"
        from_alias = p.current.value
        parser_advance(p)
      @end
    @end
  @end

  joins = []
  @while 1
    j_type = "INNER"
    @if p.current.kind == "IDENT" && (string_to_upper(p.current.value) == "INNER" || string_to_upper(p.current.value) == "LEFT" || string_to_upper(p.current.value) == "RIGHT")
      j_type = string_to_upper(p.current.value)
      parser_advance(p)
    @end
    @if p.current.kind == "JOIN"
      parser_advance(p)
      join_tbl = ""
      @if p.current.kind == "IDENT"
        join_tbl = p.current.value
        parser_advance(p)
      @end
      cond = 0
      @if p.current.kind == "IDENT" && (string_to_upper(p.current.value) == "ON")
        parser_advance(p)
        cond = parse_expr(p)
      @end
      joins = joins.push({ join_type: j_type, table: join_tbl, alias: "", condition: cond })
    @else
      break
    @end
  @end

  where_clause = 0
  @if p.current.kind == "WHERE"
    parser_advance(p)
    where_clause = parse_expr(p)
  @end

  group_by = []
  @if p.current.kind == "GROUP"
    parser_advance(p)
    @if p.current.kind == "BY" parser_advance(p) @end
    @while 1
      @if p.current.kind == "IDENT"
        group_by = group_by.push(p.current.value)
        parser_advance(p)
      @end
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end

  order_by = []
  @if p.current.kind == "ORDER"
    parser_advance(p)
    @if p.current.kind == "BY" parser_advance(p) @end
    @while 1
      @if p.current.kind == "IDENT"
        col_name = p.current.value
        parser_advance(p)
        asc = 1
        @if p.current.kind == "IDENT" && (string_to_upper(p.current.value) == "DESC")
          asc = 0
          parser_advance(p)
        @elif p.current.kind == "IDENT" && (string_to_upper(p.current.value) == "ASC")
          asc = 1
          parser_advance(p)
        @end
        order_by = order_by.push({ column: col_name, ascending: asc })
      @end
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end

  limit_val = -1
  offset_val = 0
  @if p.current.kind == "LIMIT"
    parser_advance(p)
    @if p.current.kind == "NUMBER"
      limit_val = str_to_int(p.current.value)
      parser_advance(p)
    @end
    @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "OFFSET"
      parser_advance(p)
      @if p.current.kind == "NUMBER"
        offset_val = str_to_int(p.current.value)
        parser_advance(p)
      @end
    @end
  @end

  @if p.current.kind == "SEMICOLON" parser_advance(p) @end

  return {
    type: "SelectStmt",
    distinct: distinct,
    columns: columns,
    from_table: from_table,
    from_alias: from_alias,
    joins: joins,
    where_clause: where_clause,
    group_by: group_by,
    order_by: order_by,
    limit: limit_val,
    offset: offset_val
  }
@end

@! 2. INSERT Statement
@fn parse_insert_stmt(p)
  @if p.current.kind == "INSERT" parser_advance(p) @end
  @if p.current.kind == "INTO" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end

  columns = []
  @if p.current.kind == "LPAREN"
    parser_advance(p)
    @while 1
      @if p.current.kind == "IDENT"
        columns = columns.push(p.current.value)
        parser_advance(p)
      @end
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
    parser_expect(p, "RPAREN")
  @end

  rows = []
  @if p.current.kind == "VALUES"
    parser_advance(p)
    @while 1
      parser_expect(p, "LPAREN")
      row_vals = []
      @while 1
        val_expr = parse_expr(p)
        row_vals = row_vals.push(val_expr)
        @if p.current.kind == "COMMA" parser_advance(p) @else break @end
      @end
      parser_expect(p, "RPAREN")
      rows = rows.push(row_vals)
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end

  @if p.current.kind == "SEMICOLON" parser_advance(p) @end

  return {
    type: "InsertStmt",
    table: table_name,
    columns: columns,
    values: rows
  }
@end

@! 3. UPDATE Statement
@fn parse_update_stmt(p)
  @if p.current.kind == "UPDATE" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end

  assignments = []
  @if p.current.kind == "SET"
    parser_advance(p)
    @while 1
      col = ""
      @if p.current.kind == "IDENT"
        col = p.current.value
        parser_advance(p)
      @end
      parser_expect(p, "EQ")
      val_expr = parse_expr(p)
      assignments = assignments.push({ column: col, value: val_expr })
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end

  where_clause = 0
  @if p.current.kind == "WHERE"
    parser_advance(p)
    where_clause = parse_expr(p)
  @end

  @if p.current.kind == "SEMICOLON" parser_advance(p) @end

  return {
    type: "UpdateStmt",
    table: table_name,
    assignments: assignments,
    where_clause: where_clause
  }
@end

@! 4. DELETE Statement
@fn parse_delete_stmt(p)
  @if p.current.kind == "DELETE" parser_advance(p) @end
  @if p.current.kind == "FROM" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end

  where_clause = 0
  @if p.current.kind == "WHERE"
    parser_advance(p)
    where_clause = parse_expr(p)
  @end

  @if p.current.kind == "SEMICOLON" parser_advance(p) @end

  return {
    type: "DeleteStmt",
    table: table_name,
    where_clause: where_clause
  }
@end

@! 5. CREATE TABLE Statement
@fn parse_createtable_stmt(p)
  @if p.current.kind == "CREATE" parser_advance(p) @end
  @if p.current.kind == "TABLE" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end

  columns = []
  parser_expect(p, "LPAREN")
  @while 1
    col_name = ""
    col_type = ""
    is_pk = 0
    not_null = 0
    @if p.current.kind == "IDENT"
      col_name = p.current.value
      parser_advance(p)
      @if p.current.kind == "IDENT"
        col_type = p.current.value
        parser_advance(p)
      @end
      @while p.current.kind == "IDENT"
        val_u = string_to_upper(p.current.value)
        @if val_u == "PRIMARY"
          parser_advance(p)
          @if p.current.kind == "IDENT" parser_advance(p) @end
          is_pk = 1
        @elif val_u == "NOT"
          parser_advance(p)
          @if p.current.kind == "IDENT" parser_advance(p) @end
          not_null = 1
        @else
          break
        @end
      @end
      columns = columns.push({ name: col_name, data_type: col_type, is_pk: is_pk, not_null: not_null })
    @end
    @if p.current.kind == "COMMA" parser_advance(p) @else break @end
  @end
  parser_expect(p, "RPAREN")
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end

  return { type: "CreateTableStmt", table: table_name, columns: columns }
@end

@! 6. DROP TABLE Statement
@fn parse_droptable_stmt(p)
  @if p.current.kind == "DROP" parser_advance(p) @end
  @if p.current.kind == "TABLE" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "DropTableStmt", table: table_name }
@end

@! 7. CREATE INDEX Statement
@fn parse_createindex_stmt(p)
  @if p.current.kind == "CREATE" parser_advance(p) @end
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "INDEX" parser_advance(p) @end
  index_name = ""
  @if p.current.kind == "IDENT"
    index_name = p.current.value
    parser_advance(p)
  @end
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "ON" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end
  columns = []
  @if p.current.kind == "LPAREN"
    parser_advance(p)
    @while 1
      @if p.current.kind == "IDENT"
        columns = columns.push(p.current.value)
        parser_advance(p)
      @end
      @if p.current.kind == "COMMA" parser_advance(p) @else break @end
    @end
    parser_expect(p, "RPAREN")
  @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "CreateIndexStmt", index: index_name, table: table_name, columns: columns }
@end

@! 8. ALTER TABLE Statement
@fn parse_altertable_stmt(p)
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "ALTER" parser_advance(p) @end
  @if p.current.kind == "TABLE" parser_advance(p) @end
  table_name = ""
  @if p.current.kind == "IDENT"
    table_name = p.current.value
    parser_advance(p)
  @end
  action = ""
  col_name = ""
  col_type = ""
  @if p.current.kind == "IDENT"
    action = string_to_upper(p.current.value)
    parser_advance(p)
    @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "COLUMN" parser_advance(p) @end
    @if p.current.kind == "IDENT"
      col_name = p.current.value
      parser_advance(p)
    @end
    @if p.current.kind == "IDENT"
      col_type = p.current.value
      parser_advance(p)
    @end
  @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "AlterTableStmt", table: table_name, action: action, column: col_name, data_type: col_type }
@end

@! 9. BEGIN Statement
@fn parse_begin_stmt(p)
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "BEGIN" parser_advance(p) @end
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "TRANSACTION" parser_advance(p) @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "BeginStmt" }
@end

@! 10. COMMIT Statement
@fn parse_commit_stmt(p)
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "COMMIT" parser_advance(p) @end
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "TRANSACTION" parser_advance(p) @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "CommitStmt" }
@end

@! 11. ROLLBACK Statement
@fn parse_rollback_stmt(p)
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "ROLLBACK" parser_advance(p) @end
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "TRANSACTION" parser_advance(p) @end
  @if p.current.kind == "SEMICOLON" parser_advance(p) @end
  return { type: "RollbackStmt" }
@end

@! 12. EXPLAIN Statement
@fn parse_explain_stmt(p)
  @if p.current.kind == "IDENT" && string_to_upper(p.current.value) == "EXPLAIN" parser_advance(p) @end
  inner_stmt = parse_statement(p)
  return { type: "ExplainStmt", statement: inner_stmt }
@end

@! ----------------------------------------------------------------------------
@! Unified Statement Dispatcher
@! ----------------------------------------------------------------------------

@fn parse_statement(p)
  k = p.current.kind
  v_upper = ""
  @if p.current.value != 0
    v_upper = string_to_upper(p.current.value)
  @end

  @if k == "SELECT" return parse_select_stmt(p) @end
  @if k == "INSERT" return parse_insert_stmt(p) @end
  @if k == "UPDATE" return parse_update_stmt(p) @end
  @if k == "DELETE" return parse_delete_stmt(p) @end
  @if k == "CREATE"
    @if p.peek.kind == "TABLE" return parse_createtable_stmt(p) @end
    @if p.peek.kind == "IDENT" && string_to_upper(p.peek.value) == "INDEX" return parse_createindex_stmt(p) @end
    return parse_createtable_stmt(p)
  @end
  @if k == "DROP" return parse_droptable_stmt(p) @end
  @if v_upper == "ALTER" return parse_altertable_stmt(p) @end
  @if v_upper == "BEGIN" return parse_begin_stmt(p) @end
  @if v_upper == "COMMIT" return parse_commit_stmt(p) @end
  @if v_upper == "ROLLBACK" return parse_rollback_stmt(p) @end
  @if v_upper == "EXPLAIN" return parse_explain_stmt(p) @end

  @! Fallback: advance past unknown token
  parser_advance(p)
  return { type: "UnknownStmt", kind: k, value: p.current.value }
@end

@fn parse_sql(sql_str)
  lex = lexer_new(sql_str)
  p = parser_new(lex)
  return parse_statement(p)
@end