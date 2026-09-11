// @! ADVERSARIAL STRESS: NON-ENGLISH DSL & STRING LITERAL IMMUTABILITY
@infinity_rule "si" => "@if" ;
@infinity_rule "sino" => "@else" ;
@infinity_rule "mientras" => "@while" ;
@infinity_rule "fin" => "@end" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "forever" => "@while 1" ;
@infinity_rule "done" => "@end" ;
@infinity_rule "UNLESS" => "@if 0 ==" ;

@fn dsl_gcd(a, b)
  x = a
  y = b
  mientras y != 0
    rem = x % y
    x = y
    y = rem
  fin
  retornar x
fin

@fn dsl_forever_find(target)
  val = 1
  forever
    si val >= target
      retornar val
    fin
    val = val * 3
  done
  retornar val
fin

@fn dsl_unless_test(val)
  res = 0
  UNLESS (val > 10)
    res = 100
  fin
  retornar res
fin

@fn str_eq(s1, s2)
  @if s1 == s2
    return 1
  @end
  @if s1 == 0 || s2 == 0
    return 0
  @end
  i = 0
  @while 1
    c1 = str_char_at(s1, i)
    c2 = str_char_at(s2, i)
    @if c1 != c2
      return 0
    @end
    @if c1 == 0
      return 1
    @end
    i = i + 1
  @end
  return 1
@end
