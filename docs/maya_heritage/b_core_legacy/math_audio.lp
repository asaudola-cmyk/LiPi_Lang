@! ============================================================================
@! UNIVERSE B CORE: AUDIO MATH (Trigonometry)
@! ============================================================================

@fn float(int_part, frac_part, divisor)
  return fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
@end

@fn float_neg(int_part, frac_part, divisor)
  f_val = fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
  return fsub(int_to_float(0), f_val)
@end

@fn fmod(x, y)
  @! x - y * floor(x/y)
  @! We don't have floor(), but we can cast to int and back!
  div = fdiv(x, y)
  i_div = float_to_int(div)
  @if flt(x, int_to_float(0)) == 1
    @! If negative, floor is usually more negative, but float_to_int truncates towards zero.
    @! For audio phase, we can just ensure x is positive before modulo.
  @end
  
  f_i_div = int_to_float(i_div)
  return fsub(x, fmul(y, f_i_div))
@end

@! Taylor series sin(x) for x in [-pi, pi]
@fn fsin(x)
  @! wrap x to [-PI, PI]
  @! PI = 3.14159, 2PI = 6.28318
  pi = float(3, 14159, 100000)
  two_pi = float(6, 28318, 100000)
  
  @! Make x positive first
  @while flt(x, int_to_float(0)) == 1
    x = fadd(x, two_pi)
  @end
  x = fmod(x, two_pi)
  
  @! If x > PI, x = x - 2PI
  @if fgt(x, pi) == 1
    x = fsub(x, two_pi)
  @end
  
  @! Taylor: x - x^3/6 + x^5/120 - x^7/5040
  x2 = fmul(x, x)
  x3 = fmul(x2, x)
  x5 = fmul(x3, x2)
  x7 = fmul(x5, x2)
  
  term1 = x
  term2 = fdiv(x3, float(6, 0, 1))
  term3 = fdiv(x5, float(120, 0, 1))
  term4 = fdiv(x7, float(5040, 0, 1))
  
  res = fsub(term1, term2)
  res = fadd(res, term3)
  res = fsub(res, term4)
  
  return res
@end
