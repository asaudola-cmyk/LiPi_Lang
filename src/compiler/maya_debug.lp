@fn TOKENS_OFFSET() return 0 @end
@fn STRPOOL_OFFSET() return 1048576 @end
@fn SYMTAB_OFFSET() return 2097152 @end
@fn AST_OFFSET() return 3145728 @end
@fn FIELDTAB_OFFSET() return 4194304 @end
@fn STR_PATCHES_OFFSET() return 5242880 @end
@fn FUNTAB_OFFSET() return 6291456 @end
@fn G_FUN_COUNT() return 56 @end
@fn G_FUN_PATCH_COUNT() return 64 @end
@fn FUN_PATCHES_OFFSET() return 7340032 @end

@fn CODE_OFFSET() return 16777216 @end
@fn GLOBALS_OFFSET() return 60000000 @end


@! ============================================================================
@! MAYA COMPILER V2 BOOTSTRAP (Pure V1 Maya)
@! ============================================================================






@fn AST_PROGRAM() return 1 @end
@fn AST_NUMBER() return 2 @end
@fn AST_IDENT() return 3 @end
@fn AST_BINOP() return 4 @end
@fn AST_CALL() return 5 @end
@fn AST_LET() return 6 @end
@fn AST_RETURN() return 7 @end
@fn AST_FN() return 8 @end
@fn AST_PRINTLN() return 9 @end
@fn AST_STRING() return 10 @end
@fn AST_IMPORT() return 11 @end
@fn AST_ASSIGN() return 12 @end
@fn AST_STRUCT() return 13 @end
@fn AST_MEMBER_ACCESS() return 14 @end
@fn AST_ARRAY_ACCESS() return 15 @end
@fn AST_MEMBER_ASSIGN() return 16 @end
@fn AST_ARRAY_ASSIGN() return 17 @end
@fn AST_IF() return 18 @end
@fn AST_WHILE() return 19 @end
@fn AST_BLOCK() return 20 @end

@fn TOK_EOF() return 0 @end
@fn TOK_AT_IMPORT() return 34 @end
@fn TOK_AT_STRUCT() return 35 @end
@fn TOK_ASSIGN() return 16 @end
@fn TOK_EQ() return 17 @end
@fn TOK_NEQ() return 18 @end
@fn TOK_LT() return 19 @end
@fn TOK_GT() return 20 @end
@fn TOK_LE() return 21 @end
@fn TOK_GE() return 22 @end
@fn TOK_PLUS() return 23 @end
@fn TOK_MINUS() return 24 @end
@fn TOK_STAR() return 25 @end
@fn TOK_SLASH() return 26 @end
@fn TOK_PERCENT() return 27 @end
@fn TOK_AND() return 28 @end
@fn TOK_OR() return 29 @end
@fn TOK_NEWLINE() return 30 @end
@fn TOK_COLON() return 31 @end
@fn TOK_DOT() return 32 @end
@fn TOK_COMMA() return 15 @end
@fn TOK_LBRACKET() return 38 @end
@fn TOK_RBRACKET() return 39 @end
@fn TOK_LBRACE() return 40 @end
@fn TOK_RBRACE() return 41 @end

@fn TOK_IDENT() return 1 @end
@fn TOK_NUMBER() return 2 @end
@fn TOK_STRING() return 3 @end
@fn TOK_AT_FN() return 4 @end
@fn TOK_AT_END() return 5 @end
@fn TOK_AT_IF() return 6 @end
@fn TOK_AT_ELIF() return 7 @end
@fn TOK_AT_ELSE() return 8 @end
@fn TOK_AT_WHILE() return 9 @end
@fn TOK_AT_LET() return 10 @end
@fn TOK_RETURN() return 11 @end
@fn TOK_PRINTLN() return 12 @end
@fn TOK_LPAREN() return 13 @end
@fn TOK_RPAREN() return 14 @end
@fn TOK_COMMA() return 15 @end
@fn TOK_ASSIGN() return 16 @end
@fn TOK_EQ() return 17 @end
@fn TOK_NEQ() return 18 @end
@fn TOK_LT() return 19 @end
@fn TOK_GT() return 20 @end
@fn TOK_LE() return 21 @end
@fn TOK_GE() return 22 @end
@fn TOK_PLUS() return 23 @end
@fn TOK_MINUS() return 24 @end
@fn TOK_STAR() return 25 @end
@fn TOK_SLASH() return 26 @end
@fn TOK_PERCENT() return 27 @end
@fn TOK_AND() return 28 @end
@fn TOK_OR() return 29 @end
@fn TOK_NEWLINE() return 30 @end
@fn TOK_COLON() return 31 @end
@fn TOK_DOT() return 32 @end
@fn TOK_BITAND() return 33 @end
@fn TOK_BITOR() return 34 @end
@fn TOK_LSHIFT() return 35 @end
@fn TOK_RSHIFT() return 36 @end
@fn TOK_AT_STRUCT() return 37 @end
@fn TOK_LBRACKET() return 38 @end
@fn TOK_RBRACKET() return 39 @end
@fn TOK_LBRACE() return 40 @end
@fn TOK_RBRACE() return 41 @end
@fn TOK_IMPORT() return 42 @end



@fn ARENA_SIZE() return 67108864 @end





@fn G_PARSER_POS() return 0 @end
@fn G_AST_HEAD() return 8 @end
@fn G_VAR_COUNT() return 16 @end
@fn G_CODE_LEN() return 24 @end
@fn G_STR_PATCH_COUNT() return 32 @end


@fn store_string(arena, str_pool_head, src_addr, len)
  dest = arena + STRPOOL_OFFSET() + str_pool_head
  i = 0
  @while i < len
    c = sys_peek8(src_addr + i)
    sys_poke8(dest + i, c)
    i = i + 1
  @end
  sys_poke8(dest + len, 0)
  return str_pool_head
@end

@fn is_keyword_import(addr, len)
  @if len != 6 return 0 @end
  @if sys_peek8(addr+0)!=105 return 0 @end
  @if sys_peek8(addr+1)!=109 return 0 @end
  @if sys_peek8(addr+2)!=112 return 0 @end
  @if sys_peek8(addr+3)!=111 return 0 @end
  @if sys_peek8(addr+4)!=114 return 0 @end
  @if sys_peek8(addr+5)!=116 return 0 @end
  return 1
@end

@fn is_keyword_return(addr, len)
  @if len != 6 return 0 @end
  @if sys_peek8(addr+0)!=114 return 0 @end
  @if sys_peek8(addr+1)!=101 return 0 @end
  @if sys_peek8(addr+2)!=116 return 0 @end
  @if sys_peek8(addr+3)!=117 return 0 @end
  @if sys_peek8(addr+4)!=114 return 0 @end
  @if sys_peek8(addr+5)!=110 return 0 @end
  return 1
@end

@fn is_keyword_println(addr, len)
  @if len != 7 return 0 @end
  @if sys_peek8(addr+0)!=112 return 0 @end
  @if sys_peek8(addr+1)!=114 return 0 @end
  @if sys_peek8(addr+2)!=105 return 0 @end
  @if sys_peek8(addr+3)!=110 return 0 @end
  @if sys_peek8(addr+4)!=116 return 0 @end
  @if sys_peek8(addr+5)!=108 return 0 @end
  @if sys_peek8(addr+6)!=110 return 0 @end
  return 1
@end

@fn is_at_fn(addr, len)
  @if len != 2 return 0 @end
  @if sys_peek8(addr+0)!=102 return 0 @end
  @if sys_peek8(addr+1)!=110 return 0 @end
  return 1
@end

@fn is_at_end(addr, len)
  @if len != 3 return 0 @end
  @if sys_peek8(addr+0)!=101 return 0 @end
  @if sys_peek8(addr+1)!=110 return 0 @end
  @if sys_peek8(addr+2)!=100 return 0 @end
  return 1
@end

@fn is_at_let(addr, len)
  @if len != 3 return 0 @end
  @if sys_peek8(addr+0)!=108 return 0 @end
  @if sys_peek8(addr+1)!=101 return 0 @end
  @if sys_peek8(addr+2)!=116 return 0 @end
  return 1
@end

@fn is_at_if(addr, len)
  @if len != 2 return 0 @end
  @if sys_peek8(addr+0)!=105 return 0 @end
  @if sys_peek8(addr+1)!=102 return 0 @end
  return 1
@end

@fn is_at_elif(addr, len)
  @if len != 4 return 0 @end
  @if sys_peek8(addr+0)!=101 return 0 @end
  @if sys_peek8(addr+1)!=108 return 0 @end
  @if sys_peek8(addr+2)!=105 return 0 @end
  @if sys_peek8(addr+3)!=102 return 0 @end
  return 1
@end

@fn is_at_else(addr, len)
  @if len != 4 return 0 @end
  @if sys_peek8(addr+0)!=101 return 0 @end
  @if sys_peek8(addr+1)!=108 return 0 @end
  @if sys_peek8(addr+2)!=115 return 0 @end
  @if sys_peek8(addr+3)!=101 return 0 @end
  return 1
@end

@fn is_at_while(addr, len)
  @if len != 5 return 0 @end
  @if sys_peek8(addr+0)!=119 return 0 @end
  @if sys_peek8(addr+1)!=104 return 0 @end
  @if sys_peek8(addr+2)!=105 return 0 @end
  @if sys_peek8(addr+3)!=108 return 0 @end
  @if sys_peek8(addr+4)!=101 return 0 @end
  return 1
@end

@fn is_at_import(addr, len)
  @if len != 6 return 0 @end
  @if sys_peek8(addr+0)!=105 return 0 @end
  @if sys_peek8(addr+1)!=109 return 0 @end
  @if sys_peek8(addr+2)!=112 return 0 @end
  @if sys_peek8(addr+3)!=111 return 0 @end
  @if sys_peek8(addr+4)!=114 return 0 @end
  @if sys_peek8(addr+5)!=116 return 0 @end
  return 1
@end

@fn is_at_struct(addr, len)
  @if len != 6 return 0 @end
  @if sys_peek8(addr+0)!=115 return 0 @end
  @if sys_peek8(addr+1)!=116 return 0 @end
  @if sys_peek8(addr+2)!=114 return 0 @end
  @if sys_peek8(addr+3)!=117 return 0 @end
  @if sys_peek8(addr+4)!=99  return 0 @end
  @if sys_peek8(addr+5)!=116 return 0 @end
  return 1
@end

@fn lexer_run(src_addr, src_len, arena)
  pos = 0
  tok_idx = 0
  str_head = 0
  
  running = 1
  @while running == 1
    @if pos >= src_len
      sys_poke(arena + tok_idx * 16, TOK_EOF())
      running = 0
      pos = pos + 99999999 
    @end
    
    @if running == 1
      c = sys_peek8(src_addr + pos)
      
      @if c == 32 || c == 9 || c == 13
        pos = pos + 1
      @elif c == 10
        sys_poke(arena + tok_idx * 16, TOK_NEWLINE())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 40
        sys_poke(arena + tok_idx * 16, TOK_LPAREN())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 41
        sys_poke(arena + tok_idx * 16, TOK_RPAREN())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 91
        sys_poke(arena + tok_idx * 16, TOK_LBRACKET())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 93
        sys_poke(arena + tok_idx * 16, TOK_RBRACKET())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 123
        sys_poke(arena + tok_idx * 16, TOK_LBRACE())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 125
        sys_poke(arena + tok_idx * 16, TOK_RBRACE())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 44
        sys_poke(arena + tok_idx * 16, TOK_COMMA())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 58
        sys_poke(arena + tok_idx * 16, TOK_COLON())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 46
        sys_poke(arena + tok_idx * 16, TOK_DOT())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 43
        sys_poke(arena + tok_idx * 16, TOK_PLUS())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 45
        sys_poke(arena + tok_idx * 16, TOK_MINUS())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 42
        sys_poke(arena + tok_idx * 16, TOK_STAR())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 47
        sys_poke(arena + tok_idx * 16, TOK_SLASH())
        tok_idx = tok_idx + 1
        pos = pos + 1
      @elif c == 61
        n = sys_peek8(src_addr + pos + 1)
        @if n == 61
          sys_poke(arena + tok_idx * 16, TOK_EQ())
          pos = pos + 2
        @else
          sys_poke(arena + tok_idx * 16, TOK_ASSIGN())
          pos = pos + 1
        @end
        tok_idx = tok_idx + 1
      @elif c == 33
        n = sys_peek8(src_addr + pos + 1)
        @if n == 61
          sys_poke(arena + tok_idx * 16, TOK_NEQ())
          pos = pos + 2
          tok_idx = tok_idx + 1
        @else
          println("Error: Unexpected '!'")
          sys_exit(1)
        @end
      @elif c == 60
        n = sys_peek8(src_addr + pos + 1)
        @if n == 61
          sys_poke(arena + tok_idx * 16, TOK_LE())
          pos = pos + 2
        @else
          sys_poke(arena + tok_idx * 16, TOK_LT())
          pos = pos + 1
        @end
        tok_idx = tok_idx + 1
      @elif c == 62
        n = sys_peek8(src_addr + pos + 1)
        @if n == 61
          sys_poke(arena + tok_idx * 16, TOK_GE())
          pos = pos + 2
        @else
          sys_poke(arena + tok_idx * 16, TOK_GT())
          pos = pos + 1
        @end
        tok_idx = tok_idx + 1
      @elif c == 38
        n = sys_peek8(src_addr + pos + 1)
        @if n == 38
          sys_poke(arena + tok_idx * 16, 28)
          pos = pos + 2
        @else
          println("Error: bitwise & not supported yet")
          sys_exit(1)
        @end
        tok_idx = tok_idx + 1
      @elif c == 124
        n = sys_peek8(src_addr + pos + 1)
        @if n == 124
          sys_poke(arena + tok_idx * 16, 29)
          pos = pos + 2
        @else
          println("Error: bitwise | not supported yet")
          sys_exit(1)
        @end
        tok_idx = tok_idx + 1
      @elif c == 64
        n = sys_peek8(src_addr + pos + 1)
        @if n == 33
          in_comment = 1
          pos = pos + 2
          @while in_comment == 1
            cc = sys_peek8(src_addr + pos)
            @if cc == 10 || cc == 0
              in_comment = 0
            @else
              pos = pos + 1
            @end
          @end
        @else
          pos = pos + 1
          k_start = pos
          in_kw = 1
          @while in_kw == 1
            kc = sys_peek8(src_addr + pos)
            @if (kc >= 97 && kc <= 122) || (kc >= 65 && kc <= 90) || kc == 95
              pos = pos + 1
            @else
              in_kw = 0
            @end
          @end
          k_len = pos - k_start
          k_addr = src_addr + k_start
          
          @if is_at_fn(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_FN())
          @elif is_at_end(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_END())
          @elif is_at_let(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_LET())
          @elif is_at_struct(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_STRUCT())
          @elif is_at_if(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_IF())
          @elif is_at_elif(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_ELIF())
          @elif is_at_else(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_ELSE())
          @elif is_at_while(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_WHILE())
          @elif is_at_import(k_addr, k_len) == 1
            sys_poke(arena + tok_idx * 16, TOK_AT_IMPORT())
          @else
            sys_poke(arena + tok_idx * 16, 999) 
          @end
          tok_idx = tok_idx + 1
        @end
      @elif (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 95
        id_start = pos
        in_id = 1
        @while in_id == 1
          ic = sys_peek8(src_addr + pos)
          @if (ic >= 97 && ic <= 122) || (ic >= 65 && ic <= 90) || ic == 95 || (ic >= 48 && ic <= 57)
            pos = pos + 1
          @else
            in_id = 0
          @end
        @end
        id_len = pos - id_start
        id_addr = src_addr + id_start
        
        @if is_keyword_return(id_addr, id_len) == 1
          sys_poke(arena + tok_idx * 16, TOK_RETURN())
        @elif is_keyword_println(id_addr, id_len) == 1
          sys_poke(arena + tok_idx * 16, TOK_PRINTLN())
        @elif is_keyword_import(id_addr, id_len) == 1
          sys_poke(arena + tok_idx * 16, TOK_IMPORT())
        @else
          sys_poke(arena + tok_idx * 16, TOK_IDENT())
          poff = store_string(arena, str_head, id_addr, id_len)
          sys_poke(arena + tok_idx * 16 + 8, poff)
          str_head = str_head + id_len + 1
        @end
        tok_idx = tok_idx + 1
      @elif c >= 48 && c <= 57
        val = 0
        in_num = 1
        @while in_num == 1
          nc = sys_peek8(src_addr + pos)
          @if nc >= 48 && nc <= 57
            val = val * 10 + (nc - 48)
            pos = pos + 1
          @else
            in_num = 0
          @end
        @end
        sys_poke(arena + tok_idx * 16, TOK_NUMBER())
        sys_poke(arena + tok_idx * 16 + 8, val)
        tok_idx = tok_idx + 1
      @elif c == 34
        pos = pos + 1
        str_start = pos
        in_str = 1
        @while in_str == 1
          sc = sys_peek8(src_addr + pos)
          @if sc == 34
            in_str = 0
          @elif sc == 0
            println("Error: unclosed string")
            sys_exit(1)
          @else
            pos = pos + 1
          @end
        @end
        str_len = pos - str_start
        str_addr = src_addr + str_start
        sys_poke(arena + tok_idx * 16, TOK_STRING())
        poff = store_string(arena, str_head, str_addr, str_len)
        sys_poke(arena + tok_idx * 16 + 8, poff)
        str_head = str_head + str_len + 1
        pos = pos + 1 
        tok_idx = tok_idx + 1
      @else
        println("Error: Unknown character: ")
        print_int(c)
        sys_exit(1)
      @end
    @end
  @end
  sys_poke(arena + GLOBALS_OFFSET() + 48, str_head)
  return tok_idx
@end

@fn alloc_ast_node(arena, type)
  head = sys_peek(arena + GLOBALS_OFFSET() + G_AST_HEAD())
  addr = arena + AST_OFFSET() + head
  sys_poke(addr + 0, type)
  sys_poke(addr + 8, 0)
  sys_poke(addr + 16, 0)
  sys_poke(addr + 24, 0)
  sys_poke(addr + 32, 0)
  sys_poke(arena + GLOBALS_OFFSET() + G_AST_HEAD(), head + 40)
  return head
@end
@fn set_ast_val1(arena, node_off, val1) sys_poke(arena + AST_OFFSET() + node_off + 8, val1) return 0 @end
@fn set_ast_val2(arena, node_off, val2) sys_poke(arena + AST_OFFSET() + node_off + 16, val2) return 0 @end
@fn set_ast_val3(arena, node_off, val3) sys_poke(arena + AST_OFFSET() + node_off + 24, val3) return 0 @end
@fn set_ast_val4(arena, node_off, val4) sys_poke(arena + AST_OFFSET() + node_off + 32, val4) return 0 @end
@fn parser_current_token(arena) pos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS()) return sys_peek(arena + TOKENS_OFFSET() + pos * 16) @end
@fn parser_current_val(arena) pos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS()) return sys_peek(arena + TOKENS_OFFSET() + pos * 16 + 8) @end
@fn parser_advance(arena) pos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS()) sys_poke(arena + GLOBALS_OFFSET() + G_PARSER_POS(), pos + 1) return 0 @end
@fn parser_expect(arena, expected_tok)
  tok = parser_current_token(arena)
  @if tok == expected_tok
    parser_advance(arena)
    return 1
  @else
    println("Parser error:")
    sys_exit(1)
  @end
@end

@fn print_int(n)
  @if n == 0
    sys_write_byte(1, 48)
    sys_write_byte(1, 10)
    return 0
  @end
  
  buf = sys_mmap(0, 32, 3, 34, -1, 0)
  i = 30
  sys_poke8(buf + 31, 10)
  
  @while n > 0
    rem = n - ((n / 10) * 10)
    sys_poke8(buf + i, 48 + rem)
    n = n / 10
    i = i - 1
  @end
  
  j = i + 1
  @while j <= 30
    sys_write_byte(1, sys_peek8(buf + j))
    j = j + 1
  @end
  return 0
@end



@fn define_field(arena, name_str_off, offset)
  fc = sys_peek(arena + GLOBALS_OFFSET() + G_VAR_COUNT() + 8)
  base = arena + FIELDTAB_OFFSET() + fc * 16
  sys_poke(base + 0, name_str_off)
  sys_poke(base + 8, offset)
  sys_poke(arena + GLOBALS_OFFSET() + G_VAR_COUNT() + 8, fc + 1)
  return 0
@end

@fn find_field(arena, name_str_off)
  fc = sys_peek(arena + GLOBALS_OFFSET() + G_VAR_COUNT() + 8)
  i = 0
  @while i < fc
    base = arena + FIELDTAB_OFFSET() + i * 16
    n = sys_peek(base + 0)
    @if streq(arena, n, name_str_off) == 1
      return sys_peek(base + 8)
    @end
    i = i + 1
  @end
  println("Codegen error: undefined field")
  sys_exit(1)
  return 0
@end

@fn parser_skip_newlines(arena)
  skipping = 1
  @while skipping == 1
    tok = parser_current_token(arena)
    @if tok == 30
      parser_advance(arena)
    @end
    @if tok != 30
      skipping = 0
    @end
  @end
  return 0
@end

@fn streq(arena, s1_off, s2_off)
  p1 = arena + STRPOOL_OFFSET() + s1_off
  p2 = arena + STRPOOL_OFFSET() + s2_off
  i = 0
  @while 1 == 1
    c1 = sys_peek8(p1 + i)
    c2 = sys_peek8(p2 + i)
    @if c1 == 0
      @if c2 == 0 return 1 @end
      @if c2 == 10 return 1 @end
      return 0
    @end
    @if c1 != c2 return 0 @end
    i = i + 1
  @end
  return 0
@end

@fn find_var(arena, name_str_off)
  vc = sys_peek(arena + GLOBALS_OFFSET() + G_VAR_COUNT())
  
  i = 0
  @while i < vc
    base = arena + SYMTAB_OFFSET() + i * 16
    n = sys_peek(base + 0)
    
    @if streq(arena, n, name_str_off) == 1
      return sys_peek(base + 8)
    @end
    i = i + 1
  @end
  println("Error: undefined variable: ")
  vj = 0
  @while sys_peek8(name_str_off + vj) != 0
    sys_write_byte(1, sys_peek8(name_str_off + vj))
    vj = vj + 1
  @end
  sys_write_byte(1, 10)
  sys_exit(1)
  return 0
@end

@fn streq_raw(arena, off, raw_ptr)
  p1 = arena + STRPOOL_OFFSET() + off
  i = 0
  @while 1 == 1
    c1 = sys_peek8(p1 + i)
    c2 = sys_peek8(raw_ptr + i)
    @if c1 == 0
      @if c2 == 0 return 1 @end
      @if c2 == 10 return 1 @end
      return 0
    @end
    @if c1 != c2 return 0 @end
    i = i + 1
  @end
  return 0
@end

@fn parse_primary(arena)
  tok = parser_current_token(arena)
  node = 0
  
  @if tok == TOK_NUMBER()
    val = parser_current_val(arena)
    node = alloc_ast_node(arena, AST_NUMBER())
    set_ast_val1(arena, node, val)
    parser_advance(arena)
  @elif tok == TOK_STRING()
    val = parser_current_val(arena)
    node = alloc_ast_node(arena, AST_STRING())
    set_ast_val1(arena, node, val)
    parser_advance(arena)
  @elif tok == TOK_IDENT()
    name = parser_current_val(arena)
    parser_advance(arena)
    next_tok = parser_current_token(arena)
    @if next_tok == TOK_LPAREN()
      parser_advance(arena)
      call_node = alloc_ast_node(arena, AST_CALL())
      set_ast_val1(arena, call_node, name)
      last_arg = 0
      parsing_args = 1
      @while parsing_args == 1
        ctok = parser_current_token(arena)
        @if ctok == TOK_RPAREN()
          parsing_args = 0
        @end
        @if ctok != TOK_RPAREN()
          arg_expr = parse_expr(arena)
          @if last_arg == 0 set_ast_val2(arena, call_node, arg_expr) @end
          @if last_arg != 0 set_ast_val4(arena, last_arg, arg_expr) @end
          last_arg = arg_expr
          ntok = parser_current_token(arena)
          @if ntok == TOK_COMMA() parser_advance(arena) @end
        @end
      @end
      tok = parser_current_token(arena) @if tok == TOK_RPAREN() parser_advance(arena) @else sys_exit(103) @end
      node = call_node
    @end
    @if next_tok != TOK_LPAREN()
      id_node = alloc_ast_node(arena, AST_IDENT())
      set_ast_val1(arena, id_node, name)
      node = id_node
    @end
  @elif tok == TOK_MINUS()
    parser_advance(arena)
    expr = parse_primary(arena)
    node = alloc_ast_node(arena, AST_BINOP())
    
    zero_node = alloc_ast_node(arena, AST_NUMBER())
    set_ast_val1(arena, zero_node, 0)
    
    set_ast_val1(arena, node, zero_node)
    set_ast_val2(arena, node, expr)
    set_ast_val3(arena, node, TOK_MINUS())
  @elif tok == TOK_LPAREN()
    parser_advance(arena)
    node = parse_expr(arena)
    tok = parser_current_token(arena) @if tok == TOK_RPAREN() parser_advance(arena) @else sys_exit(103) @end
  @end

  @if node == 0
    println("Error: unexpected token in expression: ")
    print_int(tok)
    println("At parser pos: ")
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    print_int(ppos)
    
    i = ppos - 5
    @while i < ppos + 5
      println("Token: ")
      print_int(sys_peek(arena + TOKENS_OFFSET() + i * 16))
      i = i + 1
    @end
    sys_exit(1)
  @end

  parsing_postfix = 1
  @while parsing_postfix == 1
    ptok = parser_current_token(arena)
    @if ptok == TOK_DOT()
      parser_advance(arena)
      field_name = parser_current_val(arena)
      tok = parser_current_token(arena) @if tok == TOK_IDENT() parser_advance(arena) @else sys_exit(104) @end
      mem_node = alloc_ast_node(arena, AST_MEMBER_ACCESS())
      set_ast_val1(arena, mem_node, node)
      set_ast_val2(arena, mem_node, field_name)
      node = mem_node
    @elif ptok == TOK_LBRACKET()
      parser_advance(arena)
      index_expr = parse_expr(arena)
      tok = parser_current_token(arena) @if tok == TOK_RBRACKET() parser_advance(arena) @else sys_exit(105) @end
      arr_node = alloc_ast_node(arena, AST_ARRAY_ACCESS())
      set_ast_val1(arena, arr_node, node)
      set_ast_val2(arena, arr_node, index_expr)
      node = arr_node
    @end
    @if ptok != TOK_DOT() && ptok != TOK_LBRACKET()
      parsing_postfix = 0
    @end
  @end
  
  return node
@end

@fn parse_factor(arena)
  left = parse_primary(arena)
  parsing = 1
  @while parsing == 1
    tok = parser_current_token(arena)
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    @if ppos > 4660 && ppos < 4675
      sys_write_byte(1, 80) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(ppos)
      sys_write_byte(1, 10)
      sys_write_byte(1, 84) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(tok)
      sys_write_byte(1, 10)
      sys_write_byte(1, 78) sys_write_byte(1, 10)
      print_int(TOK_NEWLINE())
      sys_write_byte(1, 10)
    @end
    @if tok == TOK_STAR() || tok == TOK_SLASH() || tok == TOK_PERCENT()
      parser_advance(arena)
      right = parse_primary(arena)
      new_node = alloc_ast_node(arena, AST_BINOP())
      set_ast_val1(arena, new_node, left)
      set_ast_val2(arena, new_node, right)
      set_ast_val3(arena, new_node, tok)
      left = new_node
    @end
    @if tok != TOK_STAR() && tok != TOK_SLASH() && tok != TOK_PERCENT()
      parsing = 0
    @end
  @end
  return left
@end

@fn parse_term(arena)
  left = parse_factor(arena)
  parsing = 1
  @while parsing == 1
    tok = parser_current_token(arena)
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    @if ppos > 4660 && ppos < 4675
      sys_write_byte(1, 80) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(ppos)
      sys_write_byte(1, 10)
      sys_write_byte(1, 84) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(tok)
      sys_write_byte(1, 10)
      sys_write_byte(1, 78) sys_write_byte(1, 10)
      print_int(TOK_NEWLINE())
      sys_write_byte(1, 10)
    @end
    @if tok == TOK_PLUS() || tok == TOK_MINUS()
      parser_advance(arena)
      right = parse_factor(arena)
      new_node = alloc_ast_node(arena, AST_BINOP())
      set_ast_val1(arena, new_node, left)
      set_ast_val2(arena, new_node, right)
      set_ast_val3(arena, new_node, tok)
      left = new_node
    @end
    @if tok != TOK_PLUS() && tok != TOK_MINUS()
      parsing = 0
    @end
  @end
  return left
@end

@fn parse_cmp(arena)
  left = parse_term(arena)
  parsing = 1
  @while parsing == 1
    tok = parser_current_token(arena)
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    @if ppos > 4660 && ppos < 4675
      sys_write_byte(1, 80) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(ppos)
      sys_write_byte(1, 10)
      sys_write_byte(1, 84) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(tok)
      sys_write_byte(1, 10)
      sys_write_byte(1, 78) sys_write_byte(1, 10)
      print_int(TOK_NEWLINE())
      sys_write_byte(1, 10)
    @end
    @if tok == TOK_EQ() || tok == TOK_NEQ() || tok == TOK_LT() || tok == TOK_GT() || tok == TOK_LE() || tok == TOK_GE()
      parser_advance(arena)
      right = parse_term(arena)
      new_node = alloc_ast_node(arena, AST_BINOP())
      set_ast_val1(arena, new_node, left)
      set_ast_val2(arena, new_node, right)
      set_ast_val3(arena, new_node, tok)
      left = new_node
    @end
    @if tok != TOK_EQ() && tok != TOK_NEQ() && tok != TOK_LT() && tok != TOK_GT() && tok != TOK_LE() && tok != TOK_GE()
      parsing = 0
    @end
  @end
  return left
@end

@fn parse_logic(arena)
  left = parse_cmp(arena)
  parsing = 1
  @while parsing == 1
    tok = parser_current_token(arena)
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    @if ppos > 4660 && ppos < 4675
      sys_write_byte(1, 80) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(ppos)
      sys_write_byte(1, 10)
      sys_write_byte(1, 84) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(tok)
      sys_write_byte(1, 10)
      sys_write_byte(1, 78) sys_write_byte(1, 10)
      print_int(TOK_NEWLINE())
      sys_write_byte(1, 10)
    @end
    @if tok == TOK_AND() || tok == TOK_OR()
      parser_advance(arena)
      right = parse_cmp(arena)
      new_node = alloc_ast_node(arena, AST_BINOP())
      set_ast_val1(arena, new_node, left)
      set_ast_val2(arena, new_node, right)
      set_ast_val3(arena, new_node, tok)
      left = new_node
    @end
    @if tok != TOK_AND() && tok != TOK_OR()
      parsing = 0
    @end
  @end
  return left
@end

@fn parse_expr(arena)
  return parse_logic(arena)
@end

@fn parse_assign_or_expr_stmt(arena)
  expr = parse_expr(arena)
  tok = parser_current_token(arena)
  @if tok == TOK_ASSIGN()
    parser_advance(arena)
    rhs = parse_expr(arena)
    type = sys_peek(arena + AST_OFFSET() + expr + 0)
    
    @if type == AST_IDENT()
      name = sys_peek(arena + AST_OFFSET() + expr + 8)
      node = alloc_ast_node(arena, AST_ASSIGN())
      set_ast_val1(arena, node, name)
      set_ast_val2(arena, node, rhs)
      return node
    @end
    @if type == AST_MEMBER_ACCESS()
      obj_expr = sys_peek(arena + AST_OFFSET() + expr + 8)
      field_name = sys_peek(arena + AST_OFFSET() + expr + 16)
      node = alloc_ast_node(arena, AST_MEMBER_ASSIGN())
      set_ast_val1(arena, node, obj_expr)
      set_ast_val2(arena, node, field_name)
      set_ast_val3(arena, node, rhs)
      return node
    @end
    @if type == AST_ARRAY_ACCESS()
      arr_expr = sys_peek(arena + AST_OFFSET() + expr + 8)
      idx_expr = sys_peek(arena + AST_OFFSET() + expr + 16)
      node = alloc_ast_node(arena, AST_ARRAY_ASSIGN())
      set_ast_val1(arena, node, arr_expr)
      set_ast_val2(arena, node, idx_expr)
      set_ast_val3(arena, node, rhs)
      return node
    @end
    
    println("Error: invalid assignment target")
    sys_exit(1)
  @end
  
  @if tok != TOK_ASSIGN()
    return expr
  @end
  return 0
@end

@fn parse_import(arena)
  node = alloc_ast_node(arena, AST_IMPORT())
  tok = parser_current_token(arena)
  @if tok != TOK_STRING() println("Error: import requires string literal") sys_exit(1) @end
  path = parser_current_val(arena)
  set_ast_val1(arena, node, path)
  parser_advance(arena)
  return node
@end

@fn parse_let_stmt(arena)
  node = alloc_ast_node(arena, AST_LET())
  tok = parser_current_token(arena)
  @if tok != TOK_IDENT() println("Error: @let requires identifier") sys_exit(1) @end
  name = parser_current_val(arena)
  set_ast_val1(arena, node, name)
  parser_advance(arena)
  tok = parser_current_token(arena)
  @if tok != TOK_ASSIGN() println("Error: @let requires =") sys_exit(1) @end
  parser_advance(arena)
  expr = parse_expr(arena)
  set_ast_val2(arena, node, expr)
  return node
@end

@fn parse_function(arena)
  node = alloc_ast_node(arena, AST_FN())
  tok = parser_current_token(arena)
  @if tok != TOK_IDENT() println("Error: @fn requires identifier") sys_exit(1) @end
  name = parser_current_val(arena)
  set_ast_val1(arena, node, name)
  parser_advance(arena)
  
  tok = parser_current_token(arena) @if tok != TOK_LPAREN() sys_exit(102) @end
  parser_advance(arena)
  
  last_param = 0
  parsing_params = 1
  @while parsing_params == 1
    tok = parser_current_token(arena)
    @if tok == TOK_RPAREN()
      parsing_params = 0
    @end
    @if tok != TOK_RPAREN()
      @if tok != TOK_IDENT() println("Error: Expected identifier in param list") sys_exit(1) @end
      pname = parser_current_val(arena)
      pnode = alloc_ast_node(arena, AST_IDENT())
      set_ast_val1(arena, pnode, pname)
      
      @if last_param == 0 set_ast_val2(arena, node, pnode) @end
      @if last_param != 0 set_ast_val3(arena, last_param, pnode) @end
      last_param = pnode
      
      parser_advance(arena)
      tok = parser_current_token(arena)
      @if tok == TOK_COMMA() parser_advance(arena) @end
    @end
  @end
  parser_advance(arena)
  
  parser_skip_newlines(arena)
  body = parse_block(arena)
  set_ast_val3(arena, node, body)
  
  tok = parser_current_token(arena)
  @if tok != TOK_AT_END() println("Error: Expected @end for function") sys_exit(1) @end
  parser_advance(arena)
  
  return node
@end

@fn parse_struct(arena)
  node = alloc_ast_node(arena, AST_STRUCT())
  tok = parser_current_token(arena)
  @if tok != TOK_IDENT() println("Error: @struct requires identifier") sys_exit(1) @end
  name = parser_current_val(arena)
  set_ast_val1(arena, node, name)
  parser_advance(arena)
  parser_skip_newlines(arena)
  
  last_field = 0
  parsing_body = 1
  @while parsing_body == 1
    tok = parser_current_token(arena)
    @if tok == TOK_AT_END()
      parsing_body = 0
    @end
    @if tok != TOK_AT_END()
      @if tok != TOK_IDENT() println("Error: Expected identifier in struct body") sys_exit(1) @end
      fname = parser_current_val(arena)
      fnode = alloc_ast_node(arena, AST_IDENT())
      set_ast_val1(arena, fnode, fname)
      
      @if last_field == 0 set_ast_val2(arena, node, fnode) @end
      @if last_field != 0 set_ast_val2(arena, last_field, fnode) @end
      last_field = fnode
      
      parser_advance(arena)
      parser_skip_newlines(arena)
    @end
  @end
  parser_advance(arena)
  return node
@end

@fn parse_block(arena)
  node = alloc_ast_node(arena, AST_BLOCK())
  last_stmt = 0
  parsing_body = 1
  @while parsing_body == 1
    tok = parser_current_token(arena)
    @if tok == TOK_AT_END() || tok == TOK_AT_ELIF() || tok == TOK_AT_ELSE()
      parsing_body = 0
    @end
    @if tok != TOK_AT_END() && tok != TOK_AT_ELIF() && tok != TOK_AT_ELSE()
      stmt = parse_statement(arena)
      @if stmt != 0
        @if last_stmt == 0 set_ast_val1(arena, node, stmt) @end
        @if last_stmt != 0 set_ast_val4(arena, last_stmt, stmt) @end
        last_stmt = stmt
      @end
      
      tok = parser_current_token(arena)
      @if tok == 30
        parser_skip_newlines(arena)
      @end
    @end
  @end
  return node
@end

@fn parse_if_stmt(arena)
  node = alloc_ast_node(arena, AST_IF())
  
  cond = parse_expr(arena)
  set_ast_val1(arena, node, cond)
  
  parser_skip_newlines(arena)
  if_body = parse_block(arena)
  set_ast_val2(arena, node, if_body)
  
  tok = parser_current_token(arena)
  @if tok == TOK_AT_ELIF()
    parser_advance(arena)
    elif_node = parse_if_stmt(arena)
    set_ast_val3(arena, node, elif_node)
  @elif tok == TOK_AT_ELSE()
    parser_advance(arena)
    parser_skip_newlines(arena)
    else_body = parse_block(arena)
    set_ast_val3(arena, node, else_body)
    
    tok = parser_current_token(arena)
    @if tok != TOK_AT_END() println("Error: Expected @end for if/else") sys_exit(1) @end
    parser_advance(arena)
  @elif tok == TOK_AT_END()
    parser_advance(arena)
  @else
    println("Error: Expected @elif, @else or @end")
    sys_exit(1)
  @end
  
  return node
@end

@fn parse_while_stmt(arena)
  node = alloc_ast_node(arena, AST_WHILE())
  cond = parse_expr(arena)
  set_ast_val1(arena, node, cond)
  parser_skip_newlines(arena)
  body = parse_block(arena)
  set_ast_val2(arena, node, body)
  tok = parser_current_token(arena)
  @if tok != TOK_AT_END() println("Error: Expected @end for while") sys_exit(1) @end
  parser_advance(arena)
  return node
@end

@fn parse_statement(arena)
  tok = parser_current_token(arena)
  @if tok == 30
    return 0
  @elif tok == TOK_AT_FN()
    parser_advance(arena)
    return parse_function(arena)
  @elif tok == TOK_AT_STRUCT()
    parser_advance(arena)
    return parse_struct(arena)
  @elif tok == TOK_AT_LET()
    parser_advance(arena)
    return parse_let_stmt(arena)
  @elif tok == TOK_AT_IMPORT()
    parser_advance(arena)
    return parse_import(arena)
  @elif tok == TOK_AT_IF()
    parser_advance(arena)
    return parse_if_stmt(arena)
  @elif tok == TOK_AT_WHILE()
    parser_advance(arena)
    return parse_while_stmt(arena)
  @elif tok == TOK_RETURN()
    parser_advance(arena)
    expr = parse_expr(arena)
    node = alloc_ast_node(arena, AST_RETURN())
    set_ast_val1(arena, node, expr)
    return node
  @elif tok == TOK_PRINTLN()
    parser_advance(arena)
    tok = parser_current_token(arena) @if tok == TOK_LPAREN() parser_advance(arena) @else sys_exit(102) @end
    expr = parse_expr(arena)
    tok = parser_current_token(arena) @if tok == TOK_RPAREN() parser_advance(arena) @else sys_exit(103) @end
    node = alloc_ast_node(arena, AST_PRINTLN())
    set_ast_val1(arena, node, expr)
    return node
  @else
    return parse_assign_or_expr_stmt(arena)
  @end
@end

@fn parser_run(arena)
  sys_poke(arena + GLOBALS_OFFSET() + G_PARSER_POS(), 0)
  sys_poke(arena + GLOBALS_OFFSET() + G_AST_HEAD(), 32)
  prog = alloc_ast_node(arena, AST_PROGRAM())
  last_stmt = 0
  parsing = 1
  @while parsing == 1
    tok = parser_current_token(arena)
    ppos = sys_peek(arena + GLOBALS_OFFSET() + G_PARSER_POS())
    @if ppos > 4660 && ppos < 4675
      sys_write_byte(1, 80) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(ppos)
      sys_write_byte(1, 10)
      sys_write_byte(1, 84) sys_write_byte(1, 58) sys_write_byte(1, 32)
      print_int(tok)
      sys_write_byte(1, 10)
      sys_write_byte(1, 78) sys_write_byte(1, 10)
      print_int(TOK_NEWLINE())
      sys_write_byte(1, 10)
    @end
    @if tok == TOK_EOF()
      parsing = 0
    @end
    @if tok != TOK_EOF()
      @if tok == 30
        sys_write_byte(1, 65) sys_write_byte(1, 10)
        parser_advance(arena)
      @end
      @if tok != 30
        stmt = parse_statement(arena)
        @if stmt != 0
          @if last_stmt == 0 set_ast_val1(arena, prog, stmt) @end
          @if last_stmt != 0 set_ast_val4(arena, last_stmt, stmt) @end
          last_stmt = stmt
        @end
        tok = parser_current_token(arena)
        @if tok == 30
          parser_advance(arena)
        @end
      @end
    @end
  @end
  return prog
@end




@fn patch_u32(arena, off, val)
  @if val < 0
    val = val + 4294967296
  @end
  
  b0 = val - ((val / 256) * 256)
  val = val / 256
  b1 = val - ((val / 256) * 256)
  val = val / 256
  b2 = val - ((val / 256) * 256)
  val = val / 256
  b3 = val - ((val / 256) * 256)
  
  sys_poke8(arena + CODE_OFFSET() + off + 0, b0)
  sys_poke8(arena + CODE_OFFSET() + off + 1, b1)
  sys_poke8(arena + CODE_OFFSET() + off + 2, b2)
  sys_poke8(arena + CODE_OFFSET() + off + 3, b3)
  return 0
@end

@fn current_len(arena)
  return sys_peek(arena + GLOBALS_OFFSET() + G_CODE_LEN())
@end

@fn emit_byte(arena, b)
  len = sys_peek(arena + GLOBALS_OFFSET() + G_CODE_LEN())
  sys_poke8(arena + CODE_OFFSET() + len, b)
  sys_poke(arena + GLOBALS_OFFSET() + G_CODE_LEN(), len + 1)
  return 0
@end

@fn emit_u32(arena, val)
  len = sys_peek(arena + GLOBALS_OFFSET() + G_CODE_LEN())
  sys_poke(arena + CODE_OFFSET() + len, val)
  sys_poke(arena + GLOBALS_OFFSET() + G_CODE_LEN(), len + 4)
  return 0
@end

@fn emit_u64(arena, val)
  len = sys_peek(arena + GLOBALS_OFFSET() + G_CODE_LEN())
  sys_poke(arena + CODE_OFFSET() + len, val)
  sys_poke(arena + GLOBALS_OFFSET() + G_CODE_LEN(), len + 8)
  return 0
@end

@fn alloc_var(arena)
  vc = sys_peek(arena + GLOBALS_OFFSET() + G_VAR_COUNT())
  sys_poke(arena + GLOBALS_OFFSET() + G_VAR_COUNT(), vc + 1)
  return (vc + 1) * 8
@end

@fn define_var(arena, name_str_off, stack_off)
  vc = sys_peek(arena + GLOBALS_OFFSET() + G_VAR_COUNT())
  base = arena + SYMTAB_OFFSET() + (vc - 1) * 16
  sys_poke(base + 0, name_str_off)
  sys_poke(base + 8, stack_off)
  return 0
@end

@fn codegen_expr(arena, node)
  @if node == 0 return 0 @end
  addr = arena + AST_OFFSET() + node
  type = sys_peek(addr + 0)
  
  @if type == AST_NUMBER()
    val = sys_peek(addr + 8)
    emit_byte(arena, 72)
    emit_byte(arena, 184)
    emit_u64(arena, val)
  @elif type == AST_IDENT()
    name = sys_peek(addr + 8)
    off = find_var(arena, name)
    emit_byte(arena, 72)
    emit_byte(arena, 139)
    emit_byte(arena, 133)
    emit_u32(arena, 4294967296 - off)
  @elif type == AST_BINOP()
    left = sys_peek(addr + 8)
    right = sys_peek(addr + 16)
    op = sys_peek(addr + 24)
    
    codegen_expr(arena, right)
    emit_byte(arena, 80)
    
    codegen_expr(arena, left)
    emit_byte(arena, 89)
    
    @if op == TOK_PLUS()
      emit_byte(arena, 72) emit_byte(arena, 1) emit_byte(arena, 200)
    @elif op == TOK_MINUS()
      emit_byte(arena, 72) emit_byte(arena, 41) emit_byte(arena, 200)
    @elif op == TOK_STAR()
      emit_byte(arena, 72) emit_byte(arena, 15) emit_byte(arena, 175) emit_byte(arena, 193)
    @elif op == TOK_SLASH()
      emit_byte(arena, 72) emit_byte(arena, 153)
      emit_byte(arena, 72) emit_byte(arena, 247) emit_byte(arena, 249)
    @elif op == TOK_PERCENT()
      emit_byte(arena, 72) emit_byte(arena, 153)
      emit_byte(arena, 72) emit_byte(arena, 247) emit_byte(arena, 249)
      emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 208)
    @elif op == TOK_AND()
      emit_byte(arena, 72) emit_byte(arena, 133) emit_byte(arena, 192)
      emit_byte(arena, 15) emit_byte(arena, 149) emit_byte(arena, 192)
      emit_byte(arena, 72) emit_byte(arena, 133) emit_byte(arena, 201)
      emit_byte(arena, 15) emit_byte(arena, 149) emit_byte(arena, 193)
      emit_byte(arena, 32) emit_byte(arena, 200)
      emit_byte(arena, 72) emit_byte(arena, 15) emit_byte(arena, 182) emit_byte(arena, 192)
    @elif op == TOK_OR()
      emit_byte(arena, 72) emit_byte(arena, 9) emit_byte(arena, 200)
      emit_byte(arena, 72) emit_byte(arena, 133) emit_byte(arena, 192)
      emit_byte(arena, 15) emit_byte(arena, 149) emit_byte(arena, 192)
      emit_byte(arena, 72) emit_byte(arena, 15) emit_byte(arena, 182) emit_byte(arena, 192)
    @elif op == TOK_EQ() || op == TOK_NEQ() || op == TOK_LT() || op == TOK_GT() || op == TOK_LE() || op == TOK_GE()
      emit_byte(arena, 72) emit_byte(arena, 57) emit_byte(arena, 200)
      emit_byte(arena, 15)
      @if op == TOK_EQ() emit_byte(arena, 148) @end
      @if op == TOK_NEQ() emit_byte(arena, 149) @end
      @if op == TOK_LT() emit_byte(arena, 156) @end
      @if op == TOK_GT() emit_byte(arena, 159) @end
      @if op == TOK_LE() emit_byte(arena, 158) @end
      @if op == TOK_GE() emit_byte(arena, 157) @end
      emit_byte(arena, 192)
      emit_byte(arena, 72) emit_byte(arena, 15) emit_byte(arena, 182) emit_byte(arena, 192)
    @else
      println("Codegen error: unhandled binop")
      sys_exit(1)
    @end
  @elif type == AST_CALL()
    name = sys_peek(addr + 8)
    argc = 0
    arg = sys_peek(addr + 16)
    @while arg != 0
      argc = argc + 1
      arg = sys_peek(arena + AST_OFFSET() + arg + 32)
    @end
    
    arg = sys_peek(addr + 16)
    @while arg != 0
      codegen_expr(arena, arg)
      emit_byte(arena, 80)
      arg = sys_peek(arena + AST_OFFSET() + arg + 32)
    @end
    
    i = 0
    @while i < argc
      idx = argc - 1 - i
      @if idx == 0 emit_byte(arena, 95) @end
      @if idx == 1 emit_byte(arena, 94) @end
      @if idx == 2 emit_byte(arena, 90) @end
      @if idx == 3 emit_byte(arena, 89) @end
      @if idx == 4 emit_byte(arena, 65) emit_byte(arena, 88) @end
      @if idx == 5 emit_byte(arena, 65) emit_byte(arena, 89) @end
      i = i + 1
    @end
    
    @if streq_raw(arena, name, "sys_mmap") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 9)
      emit_byte(arena, 73) emit_byte(arena, 137) emit_byte(arena, 202)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_read") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 0)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_open_read") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 2)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_open_write") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 2)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_write_byte") == 1
      emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 240)
      emit_byte(arena, 80)
      emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 230)
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 1)
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 194) emit_u32(arena, 1)
      emit_byte(arena, 15) emit_byte(arena, 5)
      emit_byte(arena, 88)
    @elif streq_raw(arena, name, "sys_close") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 3)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_chmod") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 90)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_exit") == 1
      emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 60)
      emit_byte(arena, 15) emit_byte(arena, 5)
    @elif streq_raw(arena, name, "sys_poke") == 1
      emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 55)
    @elif streq_raw(arena, name, "sys_poke8") == 1
      emit_byte(arena, 136) emit_byte(arena, 55)
    @elif streq_raw(arena, name, "sys_peek") == 1
      emit_byte(arena, 72) emit_byte(arena, 139) emit_byte(arena, 7)
    @elif streq_raw(arena, name, "sys_peek8") == 1
      emit_byte(arena, 72) emit_byte(arena, 49) emit_byte(arena, 192)
      emit_byte(arena, 138) emit_byte(arena, 7)
    @elif streq_raw(arena, name, "sys_argc") == 1
      emit_byte(arena, 72) emit_byte(arena, 139) emit_byte(arena, 4) emit_byte(arena, 37) emit_u32(arena, 5242880)
    @elif streq_raw(arena, name, "sys_argv") == 1
      emit_byte(arena, 72) emit_byte(arena, 139) emit_byte(arena, 12) emit_byte(arena, 37) emit_u32(arena, 5242888)
      emit_byte(arena, 72) emit_byte(arena, 139) emit_byte(arena, 4) emit_byte(arena, 248)
    @else
      emit_byte(arena, 232)
      patch_off = current_len(arena)
      emit_u32(arena, 0)
      pc = sys_peek(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT())
      base = arena + FUN_PATCHES_OFFSET() + pc * 16
      sys_poke(base + 0, patch_off)
      sys_poke(base + 8, name)
      sys_poke(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT(), pc + 1)
    @end
  @elif type == AST_MEMBER_ACCESS()
    obj_expr = sys_peek(addr + 8)
    field_name = sys_peek(addr + 16)
    codegen_expr(arena, obj_expr)
    off = find_field(arena, field_name)
    emit_byte(arena, 72)
    emit_byte(arena, 139)
    emit_byte(arena, 128)
    emit_u32(arena, off)
  @elif type == AST_STRING()
    str_off = sys_peek(addr + 8)
    emit_byte(arena, 72) emit_byte(arena, 184)
    patch_off = current_len(arena)
    emit_u64(arena, 0)
    
    pc = sys_peek(arena + GLOBALS_OFFSET() + G_STR_PATCH_COUNT())
    base = arena + STR_PATCHES_OFFSET() + pc * 16
    sys_poke(base + 0, patch_off)
    sys_poke(base + 8, str_off)
    sys_poke(arena + GLOBALS_OFFSET() + G_STR_PATCH_COUNT(), pc + 1)
  @elif type == AST_ARRAY_ACCESS()
    arr_expr = sys_peek(addr + 8)
    idx_expr = sys_peek(addr + 16)
    codegen_expr(arena, arr_expr)
    emit_byte(arena, 80)
    codegen_expr(arena, idx_expr)
    emit_byte(arena, 89)
    emit_byte(arena, 72)
    emit_byte(arena, 139)
    emit_byte(arena, 4)
    emit_byte(arena, 193)
  @else
    println("Codegen error: unhandled expr: ")
    print_int(type)
    sys_exit(1)
  @end
  return 0
@end

@fn codegen_stmt(arena, node)
  @if node == 0 return 0 @end
  addr = arena + AST_OFFSET() + node
  type = sys_peek(addr + 0)
  
  
  @if type == AST_LET()
    name = sys_peek(addr + 8)
    expr = sys_peek(addr + 16)
    codegen_expr(arena, expr)
    off = alloc_var(arena)
    define_var(arena, name, off)
    
    emit_byte(arena, 72)
    emit_byte(arena, 137)
    emit_byte(arena, 133)
    emit_u32(arena, 4294967296 - off)
    
  @elif type == AST_ASSIGN()
    name = sys_peek(addr + 8)
    rhs = sys_peek(addr + 16)
    codegen_expr(arena, rhs)
    off = find_var(arena, name)
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 133)
    emit_u32(arena, 4294967296 - off)
  @elif type == AST_CALL()
    codegen_expr(arena, node)
  @elif type == AST_PRINTLN()
    expr = sys_peek(addr + 8)
    codegen_expr(arena, expr)
    
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 198)
    emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 199) emit_u32(arena, 1)
    
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 243)
    emit_byte(arena, 72) emit_byte(arena, 49) emit_byte(arena, 210)
    patch_strlen_loop = current_len(arena)
    emit_byte(arena, 128) emit_byte(arena, 59) emit_byte(arena, 0)
    emit_byte(arena, 116) emit_byte(arena, 8)
    emit_byte(arena, 72) emit_byte(arena, 255) emit_byte(arena, 195)
    emit_byte(arena, 72) emit_byte(arena, 255) emit_byte(arena, 194)
    emit_byte(arena, 235) emit_byte(arena, 243)
    
    emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 1)
    emit_byte(arena, 15) emit_byte(arena, 5)
  @elif type == AST_RETURN()
    expr = sys_peek(addr + 8)
    @if expr != 0
      codegen_expr(arena, expr)
    @end
    emit_byte(arena, 201)
    emit_byte(arena, 195)
  @elif type == AST_MEMBER_ASSIGN()
    obj_expr = sys_peek(addr + 8)
    field_name = sys_peek(addr + 16)
    rhs_expr = sys_peek(addr + 24)
    codegen_expr(arena, rhs_expr)
    emit_byte(arena, 80)
    codegen_expr(arena, obj_expr)
    emit_byte(arena, 89)
    off = find_field(arena, field_name)
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 136)
    emit_u32(arena, off)
  @elif type == AST_BLOCK()
    stmt = sys_peek(addr + 8)
    @while stmt != 0
      codegen_stmt(arena, stmt)
      stmt = sys_peek(arena + AST_OFFSET() + stmt + 32)
    @end
  @elif type == AST_IF()
    cond = sys_peek(addr + 8)
    if_body = sys_peek(addr + 16)
    else_body = sys_peek(addr + 24)
    
    codegen_expr(arena, cond)
    emit_byte(arena, 72) emit_byte(arena, 133) emit_byte(arena, 192)
    
    emit_byte(arena, 15) emit_byte(arena, 132)
    jz_off = current_len(arena)
    emit_u32(arena, 0)
    
    codegen_stmt(arena, if_body)
    
    emit_byte(arena, 233)
    jmp_off = current_len(arena)
    emit_u32(arena, 0)
    
    patch_u32(arena, jz_off, current_len(arena) - (jz_off + 4))
    
    @if else_body != 0
      codegen_stmt(arena, else_body)
    @end
    
    patch_u32(arena, jmp_off, current_len(arena) - (jmp_off + 4))
  @elif type == AST_WHILE()
    cond = sys_peek(addr + 8)
    body = sys_peek(addr + 16)
    
    loop_start = current_len(arena)
    
    codegen_expr(arena, cond)
    emit_byte(arena, 72) emit_byte(arena, 133) emit_byte(arena, 192)
    
    emit_byte(arena, 15) emit_byte(arena, 132)
    jz_off = current_len(arena)
    emit_u32(arena, 0)
    
    codegen_stmt(arena, body)
    
    emit_byte(arena, 233)
    emit_u32(arena, 0)
    patch_u32(arena, current_len(arena) - 4, loop_start - current_len(arena))
    
    patch_u32(arena, jz_off, current_len(arena) - (jz_off + 4))
  @elif type == AST_ARRAY_ASSIGN()
    arr_expr = sys_peek(addr + 8)
    idx_expr = sys_peek(addr + 16)
    rhs_expr = sys_peek(addr + 24)
    codegen_expr(arena, arr_expr)
    emit_byte(arena, 80)
    codegen_expr(arena, idx_expr)
    emit_byte(arena, 80)
    codegen_expr(arena, rhs_expr)
    emit_byte(arena, 90)
    emit_byte(arena, 89)
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 4) emit_byte(arena, 209)
  @end
  return 0
@end

@fn codegen_run(arena, node)
  @if node == 0 return 0 @end
  addr = arena + AST_OFFSET() + node
  type = sys_peek(addr + 0)
  
  @if type == AST_PROGRAM()
    stmt = sys_peek(addr + 8)
    @while stmt != 0
      codegen_run(arena, stmt)
      stmt = sys_peek(arena + AST_OFFSET() + stmt + 32)
    @end
  @elif type == AST_FN()
    name = sys_peek(addr + 8)
    fc = sys_peek(arena + GLOBALS_OFFSET() + G_FUN_COUNT())
    fbase = arena + FUNTAB_OFFSET() + fc * 16
    sys_poke(fbase + 0, name)
    sys_poke(fbase + 8, current_len(arena))
    sys_poke(arena + GLOBALS_OFFSET() + G_FUN_COUNT(), fc + 1)

    emit_byte(arena, 85)
    emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 229)
    emit_byte(arena, 72) emit_byte(arena, 129) emit_byte(arena, 236)
    emit_u32(arena, 1024)
    sys_poke(arena + GLOBALS_OFFSET() + G_VAR_COUNT(), 0)
    
    param = sys_peek(addr + 16)
    idx = 0
    @while param != 0
      pname = sys_peek(arena + AST_OFFSET() + param + 8)
      off = alloc_var(arena)
      define_var(arena, pname, off)
      
      @if idx == 0 emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 189) @end
      @if idx == 1 emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 181) @end
      @if idx == 2 emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 149) @end
      @if idx == 3 emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 141) @end
      @if idx == 4 emit_byte(arena, 76) emit_byte(arena, 137) emit_byte(arena, 133) @end
      @if idx == 5 emit_byte(arena, 76) emit_byte(arena, 137) emit_byte(arena, 141) @end
      
      emit_u32(arena, 4294967296 - off)
      
      param = sys_peek(arena + AST_OFFSET() + param + 24)
      idx = idx + 1
    @end
    
    body = sys_peek(addr + 24)
    
    @while body != 0
      codegen_stmt(arena, body)
      body = sys_peek(arena + AST_OFFSET() + body + 32)
    @end
  @end
  return 0
@end

@fn generate_elf_header(arena)
  emit_byte(arena, 127) emit_byte(arena, 69) emit_byte(arena, 76) emit_byte(arena, 70)
  emit_byte(arena, 2) emit_byte(arena, 1) emit_byte(arena, 1) emit_byte(arena, 0)
  emit_byte(arena, 0)
  i = 0 @while i < 7 emit_byte(arena, 0) i = i + 1 @end
  emit_byte(arena, 2) emit_byte(arena, 0)
  emit_byte(arena, 62) emit_byte(arena, 0)
  emit_u32(arena, 1)
  emit_u64(arena, 4194424)
  emit_u64(arena, 64)
  emit_u64(arena, 0)
  emit_u32(arena, 0)
  emit_byte(arena, 64) emit_byte(arena, 0)
  emit_byte(arena, 56) emit_byte(arena, 0)
  emit_byte(arena, 1) emit_byte(arena, 0)
  emit_byte(arena, 64) emit_byte(arena, 0)
  emit_byte(arena, 0) emit_byte(arena, 0)
  emit_byte(arena, 0) emit_byte(arena, 0)
  emit_u32(arena, 1)
  emit_u32(arena, 7)
  emit_u64(arena, 0)
  emit_u64(arena, 4194304)
  emit_u64(arena, 4194304)
  emit_u64(arena, 0)
  emit_u64(arena, 0)
  emit_u64(arena, 4096)
  
  emit_byte(arena, 72) emit_byte(arena, 139) emit_byte(arena, 60) emit_byte(arena, 36)
  emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 60) emit_byte(arena, 37) emit_u32(arena, 5242880)
  emit_byte(arena, 72) emit_byte(arena, 141) emit_byte(arena, 116) emit_byte(arena, 36) emit_byte(arena, 8)
  emit_byte(arena, 72) emit_byte(arena, 137) emit_byte(arena, 52) emit_byte(arena, 37) emit_u32(arena, 5242888)
  
  emit_byte(arena, 232)
  patch_off = current_len(arena)
  emit_u32(arena, 0)
  
  pc = sys_peek(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT())
  base = arena + FUN_PATCHES_OFFSET() + pc * 16
  sys_poke(base + 0, patch_off)
  
  @! Inject "main" into string pool and get its offset!
  str_base = arena + STRPOOL_OFFSET()
  str_len = sys_peek(arena + GLOBALS_OFFSET() + 48)
  sys_poke8(str_base + str_len + 0, 109)
  sys_poke8(str_base + str_len + 1, 97)
  sys_poke8(str_base + str_len + 2, 105)
  sys_poke8(str_base + str_len + 3, 110)
  sys_poke8(str_base + str_len + 4, 0)
  sys_poke(base + 8, str_len)
  sys_poke(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT(), pc + 1)
  sys_poke(arena + GLOBALS_OFFSET() + 48, str_len + 5)
  
  emit_byte(arena, 72) emit_byte(arena, 199) emit_byte(arena, 192) emit_u32(arena, 60)
  emit_byte(arena, 15) emit_byte(arena, 5)
  return 0
@end

@fn patch_functions(arena)
  pc = sys_peek(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT())
  fc = sys_peek(arena + GLOBALS_OFFSET() + G_FUN_COUNT())
  
  i = 0
  @while i < pc
    base = arena + FUN_PATCHES_OFFSET() + i * 16
    patch_off = sys_peek(base + 0)
    name_str_off = sys_peek(base + 8)
    
    j = 0
    fn_code_off = 0
    found = 0
    @while j < fc
      fbase = arena + FUNTAB_OFFSET() + j * 16
      fname = sys_peek(fbase + 0)
      @if streq(arena, name_str_off, fname) == 1
        fn_code_off = sys_peek(fbase + 8)
        found = 1
      @end
      j = j + 1
    @end
    
    @if found == 0
      println("Error: undefined function called")
      p = arena + STRPOOL_OFFSET() + name_str_off
      @while sys_peek8(p) != 0
        sys_write_byte(1, sys_peek8(p))
        p = p + 1
      @end
      println("")
      sys_exit(1)
    @end
    
    patch_u32(arena, patch_off, fn_code_off - (patch_off + 4))
    i = i + 1
  @end
  return 0
@end

@fn patch_strings(arena)
  code_len = current_len(arena)
  str_base = 4194304 + code_len
  
  pc = sys_peek(arena + GLOBALS_OFFSET() + G_STR_PATCH_COUNT())
  i = 0
  @while i < pc
    base = arena + STR_PATCHES_OFFSET() + i * 16
    patch_off = sys_peek(base + 0)
    str_off = sys_peek(base + 8)
    
    abs_addr = str_base + str_off
    sys_poke(arena + CODE_OFFSET() + patch_off, abs_addr)
    i = i + 1
  @end
  return 0
@end

@fn write_elf(arena, out_file)
  len = sys_peek(arena + GLOBALS_OFFSET() + G_CODE_LEN())
  str_len = sys_peek(arena + GLOBALS_OFFSET() + 48)
  sys_poke(arena + CODE_OFFSET() + 96, len + str_len)
  sys_poke(arena + CODE_OFFSET() + 104, 20000000)
  
  fd = sys_open_write(out_file)
  @if fd < 0
    println("Error opening output file")
    sys_exit(1)
  @end
  
  i = 0
  @while i < len
    b = sys_peek8(arena + CODE_OFFSET() + i)
    sys_write_byte(fd, b)
    i = i + 1
  @end
  i = 0
  @while i < str_len
    b = sys_peek8(arena + STRPOOL_OFFSET() + i)
    sys_write_byte(fd, b)
    i = i + 1
  @end
  sys_close(fd)
  sys_chmod(out_file, 493)
  return 0
@end

@fn main()
  println("Initializing V2 Bootstrap Engine...")
  
  argc = sys_argc()
  @if argc < 2
    println("Usage: maya <source_file> -o <out_file>")
    sys_exit(1)
  @end
  
  source_file = sys_argv(1)
  out_file = 0
  
  i = 2
  @while i < argc
    arg = sys_argv(i)
    c0 = sys_peek8(arg + 0)
    c1 = sys_peek8(arg + 1)
    c2 = sys_peek8(arg + 2)
    @if c0 == 45 && c1 == 111 && c2 == 0
      out_file = sys_argv(i + 1)
      i = i + 1
    @end
    i = i + 1
  @end
  
  @if out_file == 0
    println("Error: -o <out_file> is required in V2")
    sys_exit(1)
  @end
  
  arena = sys_mmap(0, ARENA_SIZE(), 3, 34, -1, 0)
  
  fd = sys_open_read(source_file)
  @if fd < 0
    println("Error: could not open source file")
    sys_exit(1)
  @end
  
  src = sys_mmap(0, 1048576, 3, 34, -1, 0)
  src_len = sys_read(fd, src, 1048576)
  sys_close(fd)
  
  println("Lexing...")
  tok_count = lexer_run(src, src_len, arena)
  
  println("Parsing...")
  prog_ast = parser_run(arena)
  
  println("Codegen (ELF64)...")
  sys_poke(arena + GLOBALS_OFFSET() + G_CODE_LEN(), 0)
  sys_poke(arena + GLOBALS_OFFSET() + G_STR_PATCH_COUNT(), 0)
  sys_poke(arena + GLOBALS_OFFSET() + G_FUN_COUNT(), 0)
  sys_poke(arena + GLOBALS_OFFSET() + G_FUN_PATCH_COUNT(), 0)
  generate_elf_header(arena)
  codegen_run(arena, prog_ast)
  patch_functions(arena)
  patch_strings(arena)
  
  write_elf(arena, out_file)
  
  println("V2 Bootstrap Complete! Output binary generated.")
  return 0
@end
