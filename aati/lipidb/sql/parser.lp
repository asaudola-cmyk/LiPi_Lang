@! ============================================================================
@! LIPI UNIVERSE DB - SQL RECURSIVE-DESCENT PARSER (aati/lipidb/sql/parser.lp)
@! Standard: 100% Pure LiPi SQL AST Parser (Collision-Safe Typed Structs)
@! ============================================================================

import "aati/lipidb/sql/lexer"
import "utso/string"
import "utso/collections"

@struct SqlParser
  par_lexer: SqlLexer
  par_current: SqlToken
  par_peek: SqlToken
@end

@struct SqlExpr
  expr_type: string
  expr_op: string
  expr_val: string
  expr_lit_type: string
  expr_name: string
  expr_left: any
  expr_right: any
@end

@struct SqlColSpec
  scs_expr: any
  scs_alias: string
  scs_name: string
  scs_dtype: string
  scs_is_pk: i64
  scs_not_null: i64
@end

@struct SqlOrderSpec
  sos_column: string
  sos_ascending: i64
@end

@struct SqlAssignSpec
  sas_column: string
  sas_value: any
@end

@struct SqlStmt
  stmt_type: string
  stmt_table: string
  stmt_columns: array
  stmt_values: array
  stmt_where: any
  stmt_assignments: array
  stmt_order_by: array
  stmt_limit: i64
  stmt_offset: i64
  stmt_distinct: i64
@end

@fn _sql_expr_lit(val, lit_type) -> SqlExpr
  return { expr_type: "Literal", expr_op: "", expr_val: val, expr_lit_type: lit_type, expr_name: "", expr_left: 0, expr_right: 0 }
@end

@fn _sql_expr_ident(name) -> SqlExpr
  return { expr_type: "Identifier", expr_op: "", expr_val: "", expr_lit_type: "", expr_name: name, expr_left: 0, expr_right: 0 }
@end

@fn _sql_expr_unary(op, sub) -> SqlExpr
  return { expr_type: "UnaryOp", expr_op: op, expr_val: "", expr_lit_type: "", expr_name: "", expr_left: sub, expr_right: 0 }
@end

@fn _sql_expr_binary(op, left, right) -> SqlExpr
  return { expr_type: "BinaryOp", expr_op: op, expr_val: "", expr_lit_type: "", expr_name: "", expr_left: left, expr_right: right }
@end

@fn _sql_stmt_empty(stype) -> SqlStmt
  return {
    stmt_type: stype,
    stmt_table: "",
    stmt_columns: [],
    stmt_values: [],
    stmt_where: 0,
    stmt_assignments: [],
    stmt_order_by: [],
    stmt_limit: -1,
    stmt_offset: 0,
    stmt_distinct: 0
  }
@end

@fn parser_advance(p: SqlParser)
  p.par_current = p.par_peek
  p.par_peek = lexer_next_token(p.par_lexer)
@end

@fn parser_new(lexer: SqlLexer) -> SqlParser
  t0 = _sql_tok("EOF", "", 1, 1)
  p: SqlParser = { par_lexer: lexer, par_current: t0, par_peek: t0 }
  parser_advance(p)
  parser_advance(p)
  return p
@end

@fn parser_expect(p: SqlParser, kind)
  @if p.par_current.tok_kind == kind
    parser_advance(p)
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! Expression Parsing: Operator Precedence & Recursive Descent
@! ----------------------------------------------------------------------------

@fn parse_primary(p: SqlParser) -> SqlExpr
  cur: SqlToken = p.par_current
  @if cur.tok_kind == "NUMBER"
    parser_advance(p)
    return _sql_expr_lit(cur.tok_value, "NUMBER")
  @elif cur.tok_kind == "STRING"
    parser_advance(p)
    return _sql_expr_lit(cur.tok_value, "STRING")
  @elif cur.tok_kind == "IDENT"
    parser_advance(p)
    return _sql_expr_ident(cur.tok_value)
  @elif cur.tok_kind == "STAR"
    parser_advance(p)
    return _sql_expr_ident("*")
  @elif cur.tok_kind == "LPAREN"
    parser_advance(p)
    expr = parse_expr(p)
    parser_expect(p, "RPAREN")
    return expr
  @end
  parser_advance(p)
  return _sql_expr_lit("0", "NUMBER")
@end

@fn parse_unary(p: SqlParser) -> SqlExpr
  cur: SqlToken = p.par_current
  @if cur.tok_kind == "NOT" || (cur.tok_kind == "CHAR" && cur.tok_value == "-") || (cur.tok_kind == "CHAR" && cur.tok_value == "+")
    op = cur.tok_value
    parser_advance(p)
    operand = parse_unary(p)
    return _sql_expr_unary(op, operand)
  @end
  return parse_primary(p)
@end

@fn get_token_precedence(p: SqlParser)
  cur: SqlToken = p.par_current
  k = cur.tok_kind
  v = cur.tok_value
  @if k == "OR" return 1 @end
  @if k == "AND" return 2 @end
  @if k == "EQ" || k == "NEQ" || k == "GT" || k == "GTE" || k == "LT" || k == "LTE" return 3 @end
  @if k == "CHAR" && (v == "+" || v == "-") return 4 @end
  @if k == "STAR" || (k == "CHAR" && (v == "/" || v == "%")) return 5 @end
  return 0
@end

@fn parse_expr_prec(p: SqlParser, min_prec) -> SqlExpr
  left = parse_unary(p)
  @while 1
    prec = get_token_precedence(p)
    @if prec < min_prec || prec == 0
      break
    @end
    op_token: SqlToken = p.par_current
    op_str = op_token.tok_value
    parser_advance(p)
    right = parse_expr_prec(p, prec + 1)
    left = _sql_expr_binary(op_str, left, right)
  @end
  return left
@end

@fn parse_expr(p: SqlParser) -> SqlExpr
  return parse_expr_prec(p, 1)
@end

@fn parse_binary_op(p: SqlParser, precedence) -> SqlExpr
  return parse_expr_prec(p, precedence)
@end

@! ----------------------------------------------------------------------------
@! Statement Parsers
@! ----------------------------------------------------------------------------

@fn parse_select_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("SelectStmt")
  @if p.par_current.tok_kind == "SELECT" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT" && string_to_upper(p.par_current.tok_value) == "DISTINCT"
    st.stmt_distinct = 1
    parser_advance(p)
  @end

  columns = []
  @if p.par_current.tok_kind == "STAR"
    col_star: SqlColSpec = { scs_expr: _sql_expr_ident("*"), scs_alias: "", scs_name: "*", scs_dtype: "", scs_is_pk: 0, scs_not_null: 0 }
    columns = columns.push(col_star)
    parser_advance(p)
  @else
    @while 1
      col_expr = parse_expr(p)
      alias = ""
      @if p.par_current.tok_kind == "IDENT" && string_to_upper(p.par_current.tok_value) == "AS"
        parser_advance(p)
        @if p.par_current.tok_kind == "IDENT"
          alias = p.par_current.tok_value
          parser_advance(p)
        @end
      @end
      cspec: SqlColSpec = { scs_expr: col_expr, scs_alias: alias, scs_name: col_expr.expr_name, scs_dtype: "", scs_is_pk: 0, scs_not_null: 0 }
      columns = columns.push(cspec)
      @if p.par_current.tok_kind == "COMMA"
        parser_advance(p)
      @else
        break
      @end
    @end
  @end
  st.stmt_columns = columns

  @if p.par_current.tok_kind == "FROM"
    parser_advance(p)
    @if p.par_current.tok_kind == "IDENT"
      st.stmt_table = p.par_current.tok_value
      parser_advance(p)
    @end
  @end

  @if p.par_current.tok_kind == "WHERE"
    parser_advance(p)
    st.stmt_where = parse_expr(p)
  @end

  order_by = []
  @if p.par_current.tok_kind == "ORDER"
    parser_advance(p)
    @if p.par_current.tok_kind == "BY" parser_advance(p) @end
    @while 1
      @if p.par_current.tok_kind == "IDENT"
        col_name = p.par_current.tok_value
        parser_advance(p)
        asc = 1
        @if p.par_current.tok_kind == "IDENT" && string_to_upper(p.par_current.tok_value) == "DESC"
          asc = 0
          parser_advance(p)
        @elif p.par_current.tok_kind == "IDENT" && string_to_upper(p.par_current.tok_value) == "ASC"
          asc = 1
          parser_advance(p)
        @end
        ospec: SqlOrderSpec = { sos_column: col_name, sos_ascending: asc }
        order_by = order_by.push(ospec)
      @end
      @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end
  st.stmt_order_by = order_by

  @if p.par_current.tok_kind == "LIMIT"
    parser_advance(p)
    @if p.par_current.tok_kind == "NUMBER"
      st.stmt_limit = str_to_int(p.par_current.tok_value)
      parser_advance(p)
    @end
    @if p.par_current.tok_kind == "IDENT" && string_to_upper(p.par_current.tok_value) == "OFFSET"
      parser_advance(p)
      @if p.par_current.tok_kind == "NUMBER"
        st.stmt_offset = str_to_int(p.par_current.tok_value)
        parser_advance(p)
      @end
    @end
  @end

  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  return st
@end

@fn parse_insert_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("InsertStmt")
  @if p.par_current.tok_kind == "INSERT" parser_advance(p) @end
  @if p.par_current.tok_kind == "INTO" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT"
    st.stmt_table = p.par_current.tok_value
    parser_advance(p)
  @end

  columns = []
  @if p.par_current.tok_kind == "LPAREN"
    parser_advance(p)
    @while 1
      @if p.par_current.tok_kind == "IDENT"
        columns = columns.push(p.par_current.tok_value)
        parser_advance(p)
      @end
      @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
    @end
    parser_expect(p, "RPAREN")
  @end
  st.stmt_columns = columns

  rows = []
  @if p.par_current.tok_kind == "VALUES"
    parser_advance(p)
    @while 1
      parser_expect(p, "LPAREN")
      row_vals = []
      @while 1
        val_expr = parse_expr(p)
        row_vals = row_vals.push(val_expr)
        @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
      @end
      parser_expect(p, "RPAREN")
      rows = rows.push(row_vals)
      @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end
  st.stmt_values = rows

  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  return st
@end

@fn parse_update_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("UpdateStmt")
  @if p.par_current.tok_kind == "UPDATE" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT"
    st.stmt_table = p.par_current.tok_value
    parser_advance(p)
  @end

  assignments = []
  @if p.par_current.tok_kind == "SET"
    parser_advance(p)
    @while 1
      col = ""
      @if p.par_current.tok_kind == "IDENT"
        col = p.par_current.tok_value
        parser_advance(p)
      @end
      parser_expect(p, "EQ")
      val_expr = parse_expr(p)
      aspec: SqlAssignSpec = { sas_column: col, sas_value: val_expr }
      assignments = assignments.push(aspec)
      @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
    @end
  @end
  st.stmt_assignments = assignments

  @if p.par_current.tok_kind == "WHERE"
    parser_advance(p)
    st.stmt_where = parse_expr(p)
  @end

  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  return st
@end

@fn parse_delete_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("DeleteStmt")
  @if p.par_current.tok_kind == "DELETE" parser_advance(p) @end
  @if p.par_current.tok_kind == "FROM" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT"
    st.stmt_table = p.par_current.tok_value
    parser_advance(p)
  @end

  @if p.par_current.tok_kind == "WHERE"
    parser_advance(p)
    st.stmt_where = parse_expr(p)
  @end

  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  return st
@end

@fn parse_createtable_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("CreateTableStmt")
  @if p.par_current.tok_kind == "CREATE" parser_advance(p) @end
  @if p.par_current.tok_kind == "TABLE" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT"
    st.stmt_table = p.par_current.tok_value
    parser_advance(p)
  @end

  columns = []
  parser_expect(p, "LPAREN")
  @while 1
    col_name = ""
    col_type = ""
    is_pk = 0
    not_null = 0
    @if p.par_current.tok_kind == "IDENT"
      col_name = p.par_current.tok_value
      parser_advance(p)
      @if p.par_current.tok_kind == "IDENT"
        col_type = p.par_current.tok_value
        parser_advance(p)
      @end
      @while p.par_current.tok_kind == "IDENT"
        val_u = string_to_upper(p.par_current.tok_value)
        @if val_u == "PRIMARY"
          parser_advance(p)
          @if p.par_current.tok_kind == "IDENT" parser_advance(p) @end
          is_pk = 1
        @elif val_u == "NOT"
          parser_advance(p)
          @if p.par_current.tok_kind == "IDENT" parser_advance(p) @end
          not_null = 1
        @else
          break
        @end
      @end
      cspec: SqlColSpec = { scs_expr: 0, scs_alias: "", scs_name: col_name, scs_dtype: col_type, scs_is_pk: is_pk, scs_not_null: not_null }
      columns = columns.push(cspec)
    @end
    @if p.par_current.tok_kind == "COMMA" parser_advance(p) @else break @end
  @end
  parser_expect(p, "RPAREN")
  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  st.stmt_columns = columns
  return st
@end

@fn parse_droptable_stmt(p: SqlParser) -> SqlStmt
  st: SqlStmt = _sql_stmt_empty("DropTableStmt")
  @if p.par_current.tok_kind == "DROP" parser_advance(p) @end
  @if p.par_current.tok_kind == "TABLE" parser_advance(p) @end
  @if p.par_current.tok_kind == "IDENT"
    st.stmt_table = p.par_current.tok_value
    parser_advance(p)
  @end
  @if p.par_current.tok_kind == "SEMICOLON" parser_advance(p) @end
  return st
@end

@fn parse_statement(p: SqlParser) -> SqlStmt
  k = p.par_current.tok_kind
  @if k == "SELECT" return parse_select_stmt(p) @end
  @if k == "INSERT" return parse_insert_stmt(p) @end
  @if k == "UPDATE" return parse_update_stmt(p) @end
  @if k == "DELETE" return parse_delete_stmt(p) @end
  @if k == "CREATE" return parse_createtable_stmt(p) @end
  @if k == "DROP" return parse_droptable_stmt(p) @end
  parser_advance(p)
  return _sql_stmt_empty("UnknownStmt")
@end

@fn parse_sql(sql_str) -> SqlStmt
  lex = lexer_new(sql_str)
  p = parser_new(lex)
  return parse_statement(p)
@end
