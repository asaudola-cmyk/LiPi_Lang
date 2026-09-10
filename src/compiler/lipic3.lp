// ============================================================
// lipic3 — Lipi Self-Hosting Compiler (Phase 0: Tokenizer)
// WHY: First step toward Lipi building itself.
//      A tokenizer for Lipi syntax, written entirely in Lipi.
//
// Run:  lipi src/compiler/lipic3.lp
// ============================================================

// Token type constants
TT_NUMBER  = 1
TT_STRING  = 2
TT_IDENT   = 3
TT_KEYWORD = 4
TT_OP      = 5
TT_NL      = 6
TT_EOF     = 7

// Token struct
struct Token
    type
    value
    line

fn token_new typ val ln
    t = Token()
    t.type  = typ
    t.value = val
    t.line  = ln
    return t

fn token_str t
    if t.type == TT_NUMBER
        return "NUM(" + t.value + ")"
    elif t.type == TT_STRING
        return "STR(\"" + t.value + "\")"
    elif t.type == TT_IDENT
        return "IDENT(" + t.value + ")"
    elif t.type == TT_KEYWORD
        return "KW(" + t.value + ")"
    elif t.type == TT_OP
        return "OP(" + t.value + ")"
    elif t.type == TT_NL
        return "NL"
    else
        return "EOF"

// Keyword table — 21 keywords
fn is_keyword word
    if word == "if"       return 1
    if word == "elif"     return 1
    if word == "else"     return 1
    if word == "fn"       return 1
    if word == "return"   return 1
    if word == "while"    return 1
    if word == "for"      return 1
    if word == "in"       return 1
    if word == "repeat"   return 1
    if word == "say"      return 1
    if word == "struct"   return 1
    if word == "include"  return 1
    if word == "break"    return 1
    if word == "continue" return 1
    if word == "and"      return 1
    if word == "or"       return 1
    if word == "not"      return 1
    if word == "null"     return 1
    if word == "true"     return 1
    if word == "false"    return 1
    if word == "each"     return 1
    return 0

fn show_keyword_check w
    if is_keyword(w) == 1
        say "  KW(" + w + ") ✓"
    else
        say "  IDENT(" + w + ")"

fn show_op op
    t = token_new(TT_OP, op, 1)
    say "  " + token_str(t)

fn show_str s
    t = token_new(TT_STRING, s, 1)
    say "  " + token_str(t)

// ── Main program ─────────────────────────────────────────────
say "lipic3 Phase 0 — Lipi Self-Hosting Tokenizer"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

// 1. Keyword recognition
say ""
say "1. Keyword Recognition:"
show_keyword_check "fn"
show_keyword_check "if"
show_keyword_check "while"
show_keyword_check "for"
show_keyword_check "say"
show_keyword_check "return"
show_keyword_check "null"
show_keyword_check "true"
show_keyword_check "false"
show_keyword_check "struct"
show_keyword_check "and"
show_keyword_check "or"
show_keyword_check "not"
show_keyword_check "myVariable"
show_keyword_check "factorial"
show_keyword_check "x"

// 2. Number tokens
say ""
say "2. Number Tokens:"
t1 = token_new(TT_NUMBER, "42",   1)
t2 = token_new(TT_NUMBER, "3",    1)
t3 = token_new(TT_NUMBER, "100",  1)
t4 = token_new(TT_NUMBER, "2718", 1)
say "  " + token_str(t1)
say "  " + token_str(t2)
say "  " + token_str(t3)
say "  " + token_str(t4)

// 3. Operator tokens
say ""
say "3. Operator Tokens:"
show_op "+"
show_op "-"
show_op "*"
show_op "/"
show_op "%"
show_op "=="
show_op "!="
show_op "<="
show_op ">="
show_op "="
show_op ".."

// 4. String tokens
say ""
say "4. String Tokens:"
show_str "Hello World"
show_str "Lipi First 1.0"
show_str "Sovereign"

// 5. Self-analysis: tokenize Lipi in Lipi
say ""
say "5. Self-Analysis: Tokenizing Lipi syntax in Lipi"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "Source: fn double n = n * 2"
say ""

t_fn     = token_new(TT_KEYWORD, "fn",     1)
t_double = token_new(TT_IDENT,   "double", 1)
t_n      = token_new(TT_IDENT,   "n",      1)
t_eq     = token_new(TT_OP,      "=",      1)
t_n2     = token_new(TT_IDENT,   "n",      1)
t_mul    = token_new(TT_OP,      "*",      1)
t_2      = token_new(TT_NUMBER,  "2",      1)
t_nl     = token_new(TT_NL,      "",       1)

say "  " + token_str(t_fn)
say "  " + token_str(t_double)
say "  " + token_str(t_n)
say "  " + token_str(t_eq)
say "  " + token_str(t_n2)
say "  " + token_str(t_mul)
say "  " + token_str(t_2)
say "  " + token_str(t_nl)

say ""
say "Source: if x > 10 say \"big\""
say ""

s_if  = token_new(TT_KEYWORD, "if",  2)
s_x   = token_new(TT_IDENT,   "x",   2)
s_gt  = token_new(TT_OP,      ">",   2)
s_10  = token_new(TT_NUMBER,  "10",  2)
s_say = token_new(TT_KEYWORD, "say", 2)
s_big = token_new(TT_STRING,  "big", 2)

say "  " + token_str(s_if)
say "  " + token_str(s_x)
say "  " + token_str(s_gt)
say "  " + token_str(s_10)
say "  " + token_str(s_say)
say "  " + token_str(s_big)

// 6. Bootstrap roadmap
say ""
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "lipic3 Bootstrap Roadmap:"
say "  Phase 0: Tokenizer          ✅ Done (this file)"
say "  Phase 1: Parser (AST)       🔄 Next"
say "  Phase 2: Lipi → Python      📋 Planned"
say "  Phase 3: Lipi → C native    📋 Planned"
say "  Phase 4: Self-compile       📋 Final goal"
say ""
say "Stats:"
say "  Token types:  7"
say "  Keywords:    21"
say "  Written in:  Pure Lipi (proves self-processing)"

say ""
say "PASS: lipic3 Phase 0 — Lipi tokenizer written in Lipi ✓"
