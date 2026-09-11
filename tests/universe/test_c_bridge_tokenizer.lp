@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — C HEADER TOKENIZER & BRIDGE TEST SUITE
@! File: tests/universe/test_c_bridge_tokenizer.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: universe, assimilator, c_bridge
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
@! 1. PURE MAYA C HEADER TOKENIZER & PARSER
@! ============================================================================

@struct CToken
  kind: string
  val: string
@end

@struct CFieldSpec
  type_name: string
  field_name: string
@end

@struct CParsedStruct
  name: string
  fields: array
@end

@struct CParsedFunc
  ret_type: string
  name: string
  params: array
@end

@struct CParsedEnum
  name: string
  variants: array
@end

@fn c_tokenize_header(source)
  tokens = []
  i = 0
  n = source.len()
  @while i < n
    c = str_char_at(source, i)
    
    @! Skip whitespace
    @if c == 32 || c == 9 || c == 10 || c == 13
      i = i + 1
    @! Single char symbols
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
    @! Identifiers / Keywords
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
      
      @if word == "int" || word == "void" || word == "float" || word == "double" || word == "char" || word == "typedef" || word == "struct" || word == "enum" || word == "const"
        tokens = tokens.push({ kind: "KEYWORD", val: word })
      @else
        tokens = tokens.push({ kind: "IDENT", val: word })
      @end
    @else
      i = i + 1
    @end
  @end
  return tokens
@end

@fn parse_c_function(tokens, start_idx)
  @if start_idx + 3 >= tokens.len()
    return { ret_type: "", name: "", params: [] }
  @end
  ret_t = tokens[start_idx].val
  idx = start_idx + 1
  @if tokens[idx].kind == "STAR"
    ret_t = ret_t + "*"
    idx = idx + 1
  @end
  fn_name = tokens[idx].val
  idx = idx + 1
  params = []
  @if tokens[idx].kind == "LPAREN"
    idx = idx + 1
    @while idx < tokens.len() && tokens[idx].kind != "RPAREN"
      @if tokens[idx].kind == "KEYWORD" || tokens[idx].kind == "IDENT"
        p_type = tokens[idx].val
        idx = idx + 1
        @if idx < tokens.len() && tokens[idx].kind == "STAR"
          p_type = p_type + "*"
          idx = idx + 1
        @end
        p_name = ""
        @if idx < tokens.len() && tokens[idx].kind == "IDENT"
          p_name = tokens[idx].val
          idx = idx + 1
        @end
        params = params.push({ type_name: p_type, field_name: p_name })
      @elif tokens[idx].kind == "COMMA"
        idx = idx + 1
      @else
        idx = idx + 1
      @end
    @end
  @end
  return { ret_type: ret_t, name: fn_name, params: params }
@end

@fn emit_maya_c_bridge_binding(fn_spec)
  code = "@fn c_" + fn_spec.name + "("
  i = 0
  @while i < fn_spec.params.len()
    code = code + fn_spec.params[i].field_name
    @if i + 1 < fn_spec.params.len()
      code = code + ", "
    @end
    i = i + 1
  @end
  code = code + ") return 0 @end"
  return code
@end

@! ============================================================================
@! 2. MASTER TEST SUITE
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🌉 MAYA ASSIMILATOR — C HEADER TOKENIZER & BRIDGE TEST SUITE 🌉")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: C Header Tokenizer Keyword & Symbol Extraction
  println("▶ Test 1: C Header Tokenizer & Keyword Extraction...")
  total_tests = total_tests + 1
  
  c_snippet = "int compute_gemm(int a, float* b); void free_buf(void* ptr);"
  toks = c_tokenize_header(c_snippet)
  
  ok1_1 = assert_true(toks.len() >= 12, "Tokenized 12+ tokens from C declarations")
  ok1_2 = assert_true(toks[0].kind == "KEYWORD" && toks[0].val == "int", "Token 0 is KEYWORD 'int'")
  ok1_3 = assert_true(toks[1].kind == "IDENT" && toks[1].val == "compute_gemm", "Token 1 is IDENT 'compute_gemm'")
  ok1_4 = assert_true(toks[2].kind == "LPAREN", "Token 2 is LPAREN '('")
  ok1_5 = assert_true(toks[6].kind == "KEYWORD" && toks[6].val == "float", "Token 6 is KEYWORD 'float'")
  ok1_6 = assert_true(toks[7].kind == "STAR", "Token 7 is STAR '*' pointer symbol")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1 && ok1_6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: C header tokenizer verified")
  @end

  @! TEST 2: Function Prototype Parser (Return Type, Name, Arguments)
  println("▶ Test 2: Function Prototype Parsing...")
  total_tests = total_tests + 1
  
  fn_source = "double calculate_loss(float* y_pred, float* y_true, int n);"
  fn_toks = c_tokenize_header(fn_source)
  fn_parsed = parse_c_function(fn_toks, 0)
  
  ok2_1 = assert_true(fn_parsed.ret_type == "double", "Parsed return type 'double'")
  ok2_2 = assert_true(fn_parsed.name == "calculate_loss", "Parsed function name 'calculate_loss'")
  ok2_3 = assert_eq_int(fn_parsed.params.len(), 3, "Parsed 3 function parameters")
  ok2_4 = assert_true(fn_parsed.params[0].type_name == "float*", "Param 0 type is 'float*'")
  ok2_5 = assert_true(fn_parsed.params[0].field_name == "y_pred", "Param 0 name is 'y_pred'")
  ok2_6 = assert_true(fn_parsed.params[2].type_name == "int", "Param 2 type is 'int'")
  ok2_7 = assert_true(fn_parsed.params[2].field_name == "n", "Param 2 name is 'n'")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1 && ok2_6 == 1 && ok2_7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Function prototype parsing verified")
  @end

  @! TEST 3: C Struct Declaration Parsing
  println("▶ Test 3: C Struct Declaration Parsing...")
  total_tests = total_tests + 1
  
  struct_src = "struct { int width; int height; char* pixels; };"
  st_toks = c_tokenize_header(struct_src)
  
  @! Verify struct tokens: struct, Image, {, int, width, ;, int, height, ;, char, *, pixels, ;, }
  st_ok1 = assert_true(st_toks[0].val == "struct", "Parsed struct keyword")
  st_ok2 = assert_true(st_toks[1].val == "Image", "Parsed struct name 'Image'")
  st_ok3 = assert_true(st_toks[2].kind == "LBRACE", "Parsed LBRACE '{'")
  st_ok4 = assert_true(st_toks[3].val == "int" && st_toks[4].val == "width", "Field 0 is 'int width'")
  st_ok5 = assert_true(st_toks[6].val == "int" && st_toks[7].val == "height", "Field 1 is 'int height'")
  st_ok6 = assert_true(st_toks[9].val == "char" && st_toks[10].val == "*" && st_toks[11].val == "pixels", "Field 2 is 'char* pixels'")
  
  @if st_ok1 == 1 && st_ok2 == 1 && st_ok3 == 1 && st_ok4 == 1 && st_ok5 == 1 && st_ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: C struct declaration parsing verified")
  @end

  @! TEST 4: Maya Bridge Binding Generation
  println("▶ Test 4: Maya FFI Bridge Wrapper Generation...")
  total_tests = total_tests + 1
  
  bridge_code = emit_maya_c_bridge_binding(fn_parsed)
  b_ok1 = assert_true(contains(bridge_code, "@fn c_calculate_loss(y_pred, y_true, n)"), "Emitted canonical Maya bridge signature")
  b_ok2 = assert_true(contains(bridge_code, "return 0 @end"), "Emitted return 0 @end body")
  
  @if b_ok1 == 1 && b_ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Maya bridge wrapper generation verified")
  @end

  @! TEST 5: Assimilator Multi-Function Registration & Header Assimilation
  println("▶ Test 5: C Assimilator Module Integration...")
  total_tests = total_tests + 1
  
  ca = c_assimilator_new()
  ca = c_register_func(ca, "malloc", "libc.so", "void*")
  ca = c_register_func(ca, "free", "libc.so", "void")
  ca = c_register_func(ca, "sin", "libm.so", "double")
  
  ca_ok1 = assert_eq_int(ca.ca_funcs.len(), 3, "Registered 3 C foreign functions")
  ca_ok2 = assert_true(ca.ca_funcs[0].cf_name == "malloc", "Func 0 is malloc")
  ca_ok3 = assert_true(ca.ca_funcs[1].cf_name == "free", "Func 1 is free")
  ca_ok4 = assert_true(ca.ca_funcs[2].cf_name == "sin", "Func 2 is sin")
  
  @if ca_ok1 == 1 && ca_ok2 == 1 && ca_ok3 == 1 && ca_ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: C Assimilator module integration verified")
  @end

  println("=================================================================")
  println("📊 C BRIDGE TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 C BRIDGE TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME C BRIDGE TESTS FAILED")
    return 1
  @end
@end
