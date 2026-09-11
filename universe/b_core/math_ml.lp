@! ============================================================================
@! UNIVERSE B CORE: MACHINE LEARNING MATH
@! ============================================================================

@fn float(int_part, frac_part, divisor)
  return fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
@end

@fn float_neg(int_part, frac_part, divisor)
  f_val = fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
  return fsub(int_to_float(0), f_val)
@end

@! exp(x) via Taylor Series (accurate for small x, enough for sigmoid)
@fn fexp(x)
  term = int_to_float(1)
  sum = term
  
  @! i = 1 to 12
  f1 = int_to_float(1)
  f2 = int_to_float(2)
  f3 = int_to_float(3)
  f4 = int_to_float(4)
  f5 = int_to_float(5)
  f6 = int_to_float(6)
  f7 = int_to_float(7)
  f8 = int_to_float(8)
  
  term = fmul(term, x) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f2) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f3) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f4) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f5) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f6) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f7) sum = fadd(sum, term)
  term = fdiv(fmul(term, x), f8) sum = fadd(sum, term)
  
  return sum
@end

@fn sigmoid(x)
  @! 1 / (1 + exp(-x))
  @! Clip x to avoid overflow/underflow in Taylor series
  @if fgt(x, int_to_float(5)) == 1 return int_to_float(1) @end
  @if flt(x, float_neg(5, 0, 1)) == 1 return int_to_float(0) @end
  
  neg_x = fsub(int_to_float(0), x)
  exp_nx = fexp(neg_x)
  den = fadd(int_to_float(1), exp_nx)
  return fdiv(int_to_float(1), den)
@end

@fn sigmoid_deriv(out)
  @! out * (1 - out)
  return fmul(out, fsub(int_to_float(1), out))
@end
