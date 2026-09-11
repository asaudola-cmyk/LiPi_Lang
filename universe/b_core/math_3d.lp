@! ============================================================================
@! UNIVERSE B CORE: 3D GRAPHICS MATH
@! ============================================================================

@fn fsqrt(val)
  f_zero = int_to_float(0)
  @if fle(val, f_zero) == 1 return f_zero @end
  
  f_two = int_to_float(2)
  guess = fdiv(val, f_two)
  
  i = 0
  @while i < 15
    term = fdiv(val, guess)
    sum = fadd(guess, term)
    guess = fdiv(sum, f_two)
    i = i + 1
  @end
  return guess
@end

@! Vec3 memory layout: [0]=x, [8]=y, [16]=z (24 bytes)
@fn vec3_new(x, y, z)
  v = sys_mmap(0, 24, 3, 34, 0 - 1, 0)
  sys_poke(v + 0, x)
  sys_poke(v + 8, y)
  sys_poke(v + 16, z)
  return v
@end

@fn vec3_add(v1, v2)
  x = fadd(sys_peek(v1 + 0), sys_peek(v2 + 0))
  y = fadd(sys_peek(v1 + 8), sys_peek(v2 + 8))
  z = fadd(sys_peek(v1 + 16), sys_peek(v2 + 16))
  return vec3_new(x, y, z)
@end

@fn vec3_sub(v1, v2)
  x = fsub(sys_peek(v1 + 0), sys_peek(v2 + 0))
  y = fsub(sys_peek(v1 + 8), sys_peek(v2 + 8))
  z = fsub(sys_peek(v1 + 16), sys_peek(v2 + 16))
  return vec3_new(x, y, z)
@end

@fn vec3_scale(v, scalar)
  x = fmul(sys_peek(v + 0), scalar)
  y = fmul(sys_peek(v + 8), scalar)
  z = fmul(sys_peek(v + 16), scalar)
  return vec3_new(x, y, z)
@end

@fn vec3_dot(v1, v2)
  x = fmul(sys_peek(v1 + 0), sys_peek(v2 + 0))
  y = fmul(sys_peek(v1 + 8), sys_peek(v2 + 8))
  z = fmul(sys_peek(v1 + 16), sys_peek(v2 + 16))
  return fadd(fadd(x, y), z)
@end

@fn vec3_length(v)
  return fsqrt(vec3_dot(v, v))
@end

@fn vec3_normalize(v)
  len = vec3_length(v)
  @if feq(len, int_to_float(0)) == 1 return vec3_new(int_to_float(0), int_to_float(0), int_to_float(0)) @end
  inv_len = fdiv(int_to_float(1), len)
  return vec3_scale(v, inv_len)
@end
