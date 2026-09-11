@! ============================================================================
@! UNIVERSE B CORE: STRING MANIPULATION (C-Style Null-Terminated Strings)
@! ============================================================================

@fn string_len(s)
  len = 0
  @while sys_peek8(s + len) != 0
    len = len + 1
  @end
  return len
@end

@fn string_print(s)
  len = string_len(s)
  sys_syscall(1, 1, s, len, 0, 0, 0)
  return 0
@end

@fn string_println(s)
  string_print(s)
  sys_write_byte(1, 10)
  return 0
@end

@fn string_concat(s1, s2)
  len1 = string_len(s1)
  len2 = string_len(s2)
  
  @! Allocate (len1 + len2 + 1) bytes
  total_len = len1 + len2 + 1
  pages = (total_len / 4096) + 1
  new_s = sys_mmap(0, pages * 4096, 3, 34, 0 - 1, 0)
  
  i = 0
  @while i < len1
    sys_poke8(new_s + i, sys_peek8(s1 + i))
    i = i + 1
  @end
  
  j = 0
  @while j < len2
    sys_poke8(new_s + i + j, sys_peek8(s2 + j))
    j = j + 1
  @end
  
  sys_poke8(new_s + i + j, 0)
  return new_s
@end

@fn string_eq(s1, s2)
  len1 = string_len(s1)
  len2 = string_len(s2)
  @if len1 != len2 return 0 @end
  
  i = 0
  @while i < len1
    c1 = sys_peek8(s1 + i)
    c2 = sys_peek8(s2 + i)
    @if c1 != c2 return 0 @end
    i = i + 1
  @end
  
  return 1
@end
