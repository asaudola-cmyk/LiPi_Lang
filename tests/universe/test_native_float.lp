@! PURE NATIVE MAYA FLOAT MATH (UNIVERSE B)

@! --- ENTRY POINT ---
main()
sys_exit(0)

@! --- FUNCTIONS ---
@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end

@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
  return 0
@end

@fn print_int(n)
  @if n == 0
    sys_write_byte(1, 48)
    return 0
  @end
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  i = 30
  sys_poke8(buf + 31, 0)
  @while n > 0
    rem = n - ((n / 10) * 10)
    sys_poke8(buf + i, 48 + rem)
    n = n / 10
    i = i - 1
  @end
  sys_syscall(1, 1, buf + i + 1, 30 - i, 0, 0, 0)
  return 0
@end

@fn print_float(f, prec)
  int_part = float_to_int(f)
  print_int(int_part)
  sys_write_byte(1, 46) @! '.'
  
  f_frac = fsub(f, int_to_float(int_part))
  
  i = 0
  @while i < prec
    f_frac = fmul(f_frac, int_to_float(10))
    digit = float_to_int(f_frac)
    sys_write_byte(1, 48 + digit)
    f_frac = fsub(f_frac, int_to_float(digit))
    i = i + 1
  @end
  sys_write_byte(1, 10) @! newline
  return 0
@end

@fn parse_float_simple(int_part, frac_part, divisor)
  f_int = int_to_float(int_part)
  f_frac = int_to_float(frac_part)
  f_div = int_to_float(divisor)
  return fadd(f_int, fdiv(f_frac, f_div))
@end

@fn main()
  sys_syscall(1, 1, "=== NATIVE MAYA FLOAT CORE ===
", 31, 0, 0, 0)
  
  @! a = 3.14 (3, 14, 100)
  a = parse_float_simple(3, 14, 100)
  @! b = 2.5 (2, 5, 10)
  b = parse_float_simple(2, 5, 10)
  
  sys_syscall(1, 1, "a = ", 4, 0, 0, 0)
  print_float(a, 2)
  
  sys_syscall(1, 1, "b = ", 4, 0, 0, 0)
  print_float(b, 2)
  
  sys_syscall(1, 1, "a + b = ", 8, 0, 0, 0)
  print_float(fadd(a, b), 4)
  
  sys_syscall(1, 1, "a - b = ", 8, 0, 0, 0)
  print_float(fsub(a, b), 4)
  
  sys_syscall(1, 1, "a * b = ", 8, 0, 0, 0)
  print_float(fmul(a, b), 4)
  
  sys_syscall(1, 1, "a / b = ", 8, 0, 0, 0)
  print_float(fdiv(a, b), 4)
  
  sys_syscall(1, 1, "a > b = ", 8, 0, 0, 0)
  print_int(fgt(a, b))
  sys_write_byte(1, 10)
  
  return 0
@end
