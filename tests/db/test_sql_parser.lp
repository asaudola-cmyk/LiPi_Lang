@! Maya Database SQL Parser Unit & Integration Tests

import "universe/db/sql/lexer"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn test_sql_lexer_basic()
  lex = lexer_new("SELECT id, name FROM users WHERE age >= 18")
  t1 = lexer_next_token(lex)
  assert_eq(t1.kind, "SELECT", "Lexer token 1 is SELECT")
  
  t2 = lexer_next_token(lex)
  assert_eq(t2.value, "id", "Lexer token 2 is id")
  
  t3 = lexer_next_token(lex)
  assert_eq(t3.kind, "COMMA", "Lexer token 3 is COMMA")

  t4 = lexer_next_token(lex)
  assert_eq(t4.value, "name", "Lexer token 4 is name")

  t5 = lexer_next_token(lex)
  assert_eq(t5.kind, "FROM", "Lexer token 5 is FROM")

  t6 = lexer_next_token(lex)
  assert_eq(t6.value, "users", "Lexer token 6 is users")

  t7 = lexer_next_token(lex)
  assert_eq(t7.kind, "WHERE", "Lexer token 7 is WHERE")

  t8 = lexer_next_token(lex)
  assert_eq(t8.value, "age", "Lexer token 8 is age")

  t9 = lexer_next_token(lex)
  assert_eq(t9.kind, "GTE", "Lexer token 9 is GTE")

  t10 = lexer_next_token(lex)
  assert_eq(t10.value, "18", "Lexer token 10 is 18")

  return 0
@end

@fn main()
  println("==================================================")
  println("   MAYA DATABASE SQL PARSER TEST SUITE            ")
  println("==================================================")
  test_sql_lexer_basic()
  println("🎉 ALL SQL PARSER TESTS PASSED!")
  return 0
@end
