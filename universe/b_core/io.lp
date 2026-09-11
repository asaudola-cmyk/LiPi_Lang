@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
  return 0
@end

@fn print_int(n)
  @if n == 0
    sys_write_byte(1, 48)
    sys_write_byte(1, 10)
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
  sys_write_byte(1, 10)
  return 0
@end

@fn print_float(f, prec)
  int_part = float_to_int(f)
  print_int_no_nl(int_part)
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
  sys_write_byte(1, 10)
  return 0
@end

@fn print_int_no_nl(n)
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
