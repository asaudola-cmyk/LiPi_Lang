import "universe/b_core/string"
import "universe/b_core/net"

@! Finds the index of a substring `sub` in `s`, starting at `start_idx`. Returns -1 if not found.
@fn string_find(s, sub, start_idx)
  slen = string_len(s)
  sublen = string_len(sub)
  @if sublen == 0 return start_idx @end
  
  i = start_idx
  @while i <= slen - sublen
    match = 1
    j = 0
    @while j < sublen
      c1 = sys_peek8(s + i + j)
      c2 = sys_peek8(sub + j)
      @if c1 != c2
        match = 0
      @end
      j = j + 1
    @end
    @if match == 1 return i @end
    i = i + 1
  @end
  
  return 0 - 1
@end

@! Extracts a substring from `s` starting at `start` and ending before `end`
@fn string_substring(s, start, end)
  len = end - start
  @if len <= 0 return "" @end
  
  pages = (len / 4096) + 1
  new_s = sys_mmap(0, pages * 4096, 3, 34, 0 - 1, 0)
  
  i = 0
  @while i < len
    sys_poke8(new_s + i, sys_peek8(s + start + i))
    i = i + 1
  @end
  sys_poke8(new_s + len, 0)
  
  return new_s
@end
