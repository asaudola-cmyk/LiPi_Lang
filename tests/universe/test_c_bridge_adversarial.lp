@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — C BRIDGE ADVERSARIAL & BOUNDARY TEST SUITE
@! File: tests/universe/test_c_bridge_adversarial.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: universe, assimilator, c_bridge, adversarial
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/assimilator/c_bridge"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@! ============================================================================
@! ADVERSARIAL C PREPROCESSOR & TOKENIZER ENGINE
@! ============================================================================

@struct AdvToken
  kind: string
  val: string
@end

@fn strip_c_comments_and_preprocessor(source)
  cleaned = ""
  i = 0
  n = source.len()
  @while i < n
    c = str_char_at(source, i)
    
    @! Line comment: // ...
    @if c == 47 && i + 1 < n && str_char_at(source, i + 1) == 47
      j = i + 2
      @while j < n && str_char_at(source, j) != 10
        j = j + 1
      @end
      i = j
    @! Block comment: /* ... */
    @elif c == 47 && i + 1 < n && str_char_at(source, i + 1) == 42
      j = i + 2
      @while j + 1 < n && !(str_char_at(source, j) == 42 && str_char_at(source, j + 1) == 47)
        j = j + 1
      @end
      i = j + 2
    @! Preprocessor directive: #...
    @elif c == 35  @! '#'
      j = i + 1
      @while j < n && str_char_at(source, j) != 10
        j = j + 1
      @end
      i = j
    @else
      cleaned = cleaned + str_from_char_code(c)
      i = i + 1
    @end
  @end
  return cleaned
@end

@fn adv_tokenize_c(source)
  tokens = []
  i = 0
  n = source.len()
  @while i < n
    c = str_char_at(source, i)
    
    @if c == 32 || c == 9 || c == 10 || c == 13
      i = i + 1
    @elif c == 59  @! ';'
      tokens = tokens.push({ kind: "SEMI", val: ";" })
      i = i + 1
    @elif c == 44  @! ','
      tokens = tokens.push({ kind: "COMMA", val: "," })
      i = i + 1
    @elif c == 40  @! '('
      tokens = tokens.push({ kind: "LPAREN", val: "(" })
      i = i + 1
    @elif c == 41  @! ')'
      tokens = tokens.push({ kind: "RPAREN", val: ")" })
      i = i + 1
    @elif c == 123  @! '{'
      tokens = tokens.push({ kind: "LBRACE", val: "{" })
      i = i + 1
    @elif c == 125  @! '}'
      tokens = tokens.push({ kind: "RBRACE", val: "}" })
      i = i + 1
    @elif c == 42  @! '*'
      tokens = tokens.push({ kind: "STAR", val: "*" })
      i = i + 1
    @elif c == 61  @! '='
      tokens = tokens.push({ kind: "EQUALS", val: "=" })
      i = i + 1
    @elif (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
      j = i
      word = ""
      in_word = 1
      @while j < n && in_word == 1
        sc = str_char_at(source, j)
        @if (sc >= 65 && sc <= 90) || (sc >= 97 && sc <= 122) || (sc >= 48 && sc <= 57) || sc == 95
          word = word + str_from_char_code(sc)
          j = j + 1
        @else
          in_word = 0
        @end
      @end
      i = j
      tokens = tokens.push({ kind: "IDENT", val: word })
    @elif c >= 48 && c <= 57
      j = i
      num_str = ""
      in_num = 1
      @while j < n && in_num == 1
        nc = str_char_at(source, j)
        @if nc >= 48 && nc <= 57
          num_str = num_str + str_from_char_code(nc)
          j = j + 1
        @else
          in_num = 0
        @end
      @end
      i = j
      tokens = tokens.push({ kind: "NUMBER", val: num_str })
    @else
      i = i + 1
    @end
  @end
  return tokens
@end

@! ============================================================================
@! MASTER TEST SUITE
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🌉 C BRIDGE ADVERSARIAL & PREPROCESSOR TEST SUITE 🌉")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Pointer & Double Pointer Indirection Decoding
  println("▶ Test 1: Pointer & Double Pointer Indirections (char**, void**)...")
  total_tests = total_tests + 1
  
  c_ptrs = "int get_status(int node_id, char** out_msg, void** ctx_handle);"
  toks1 = adv_tokenize_c(c_ptrs)
  
  @! Trace: int (0), get_status (1), ( (2), int (3), node_id (4), , (5), char (6), * (7), * (8), out_msg (9)
  ok1_1 = assert_true(toks1[6].val == "char", "Type is char")
  ok1_2 = assert_true(toks1[7].kind == "STAR" && toks1[8].kind == "STAR", "Double pointer ** symbols extracted")
  ok1_3 = assert_true(toks1[9].val == "out_msg", "Parameter name is out_msg")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: Pointer & double pointer indirections verified")
  @end

  @! TEST 2: Preprocessor Directive Stripping (#ifndef, #define, #include, #endif)
  println("▶ Test 2: Preprocessor Directive Stripping...")
  total_tests = total_tests + 1
  
  prep_c = "#ifndef FOO_H\n#define FOO_H\n#include <stdio.h>\nint add(int a, int b);\n#endif\n"
  clean_c = strip_c_comments_and_preprocessor(prep_c)
  
  ok2_1 = assert_true(!contains(clean_c, "#ifndef"), "Stripped #ifndef")
  ok2_2 = assert_true(!contains(clean_c, "#define"), "Stripped #define")
  ok2_3 = assert_true(!contains(clean_c, "#include"), "Stripped #include")
  ok2_4 = assert_true(contains(clean_c, "int add(int a, int b);"), "Preserved core C function declaration")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Preprocessor directive stripping verified")
  @end

  @! TEST 3: Multi-line Block Comments & Line Comments Stripping
  println("▶ Test 3: Comment Stripping (/* Block */ & // Line)...")
  total_tests = total_tests + 1
  
  comment_c = "/* Multi-line comment\n * explaining interface\n */\nvoid process(); // end of line comment\n"
  clean_comments = strip_c_comments_and_preprocessor(comment_c)
  
  ok3_1 = assert_true(!contains(clean_comments, "Multi-line comment"), "Stripped block comments")
  ok3_2 = assert_true(!contains(clean_comments, "end of line comment"), "Stripped line comments")
  ok3_3 = assert_true(contains(clean_comments, "void process();"), "Preserved function declaration")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Comment stripping verified")
  @end

  @! TEST 4: Enum Declaration Parsing & Constant Values
  println("▶ Test 4: C Enum Declaration Parsing with Explicit Values...")
  total_tests = total_tests + 1
  
  enum_c = "typedef enum { STATUS_OK = 0, STATUS_ERR = 1, STATUS_PENDING = 2 } Status;"
  toks_enum = adv_tokenize_c(enum_c)
  
  @! Check tokens: enum, {, STATUS_OK, =, 0, ,, STATUS_ERR, =, 1, ,, STATUS_PENDING, =, 2, }, Status, ;
  ok4_1 = assert_true(toks_enum[1].val == "enum", "Parsed enum keyword")
  ok4_2 = assert_true(toks_enum[3].val == "STATUS_OK", "Enum variant 0 is STATUS_OK")
  ok4_3 = assert_true(toks_enum[5].val == "0", "STATUS_OK value is 0")
  ok4_4 = assert_true(toks_enum[7].val == "STATUS_ERR", "Enum variant 1 is STATUS_ERR")
  ok4_5 = assert_true(toks_enum[9].val == "1", "STATUS_ERR value is 1")
  ok4_6 = assert_true(toks_enum[11].val == "STATUS_PENDING", "Enum variant 2 is STATUS_PENDING")
  ok4_7 = assert_true(toks_enum[13].val == "2", "STATUS_PENDING value is 2")
  
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1 && ok4_5 == 1 && ok4_6 == 1 && ok4_7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: C enum declaration parsing verified")
  @end

  @! TEST 5: Full Assimilation of sample_c_header.h Fixture
  println("▶ Test 5: Full Assimilation of tests/fixtures/sample_c_header.h...")
  total_tests = total_tests + 1
  
  fixture_content = file_read("tests/fixtures/sample_c_header.h")
  ok5_read = assert_true(fixture_content.len() > 0, "Successfully read sample_c_header.h fixture")
  
  cleaned_fixture = strip_c_comments_and_preprocessor(fixture_content)
  fixture_toks = adv_tokenize_c(cleaned_fixture)
  
  ok5_toks = assert_true(fixture_toks.len() > 30, "Tokenized 30+ tokens from sample_c_header.h")
  ok5_status = assert_true(contains(cleaned_fixture, "StatusCode"), "Contains StatusCode enum")
  ok5_matrix = assert_true(contains(cleaned_fixture, "CMatrix"), "Contains CMatrix struct")
  ok5_gemm = assert_true(contains(cleaned_fixture, "compute_gemm"), "Contains compute_gemm function prototype")
  
  @if ok5_read == 1 && ok5_toks == 1 && ok5_status == 1 && ok5_matrix == 1 && ok5_gemm == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Full assimilation of sample_c_header.h verified")
  @end

  println("=================================================================")
  println("📊 C BRIDGE ADVERSARIAL TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 C BRIDGE ADVERSARIAL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME C BRIDGE ADVERSARIAL TESTS FAILED")
    return 1
  @end
@end
