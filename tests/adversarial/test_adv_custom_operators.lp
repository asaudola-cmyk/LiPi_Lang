// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: PASS: custom operators
// @! EXPECT_EXIT: 0

@custom_op "**" "INFIX_RIGHT" 80 "maya_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "maya_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "maya_xor" ;

@fn maya_power(base, exp)
  @if exp <= 0
    return 1
  @end
  res = 1
  b = base
  e = exp
  @while e > 0
    @if (e % 2) == 1
      res = res * b
    @end
    b = b * b
    e = e / 2
  @end
  return res
@end

@fn maya_spaceship(a, b)
  @if a < b
    return 0 - 1
  @elif a > b
    return 1
  @else
    return 0
  @end
@end

@fn maya_xor(a, b)
  b_a = 0
  @if a != 0
    b_a = 1
  @end
  b_b = 0
  @if b != 0
    b_b = 1
  @end
  @if (b_a == 1 && b_b == 0) || (b_a == 0 && b_b == 1)
    return 1
  @else
    return 0
  @end
@end

@fn main()
  a = 2 ** 8
  b = 10 <=> 20
  c = 1 ^^ 0
  
  @if a == 256 && b == 0 - 1 && c == 1
    println("PASS: custom operators")
    return 0
  @else
    println("FAIL: custom operators")
    return 1
  @end
@end
