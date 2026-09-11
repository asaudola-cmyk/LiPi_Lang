@! ============================================================================
@! TEST SUITE: INFINITY SYNTAX & DYNAMIC GRAMMAR ENGINE (test_infinity_syntax.maya)
@! Architecture: Pure Maya Dynamic Grammar & Metaprogramming Validation
@! Standard: Zero Foreign Toolchain, Zero C/C++ dependencies
@!
@! RUN: %maya %file -o %out && %out
@! EXPECT_CONTAINS: ALL INFINITY SYNTAX & DYNAMIC GRAMMAR TESTS PASSED
@! EXPECT_EXIT: 0
@! ============================================================================

@! Dynamic Syntax Directives
@infinity_rule "mientras" => "@while" ;
@infinity_rule "si" => "@if" ;
@infinity_rule "sino" => "@else" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "fin" => "@end" ;
@infinity_rule "forever" => "@while 1" ;
@infinity_rule "done" => "@end
