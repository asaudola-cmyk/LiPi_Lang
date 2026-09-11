import "src/compiler/middleend/maya_compiler_v2_bootstrap.lp"
import "universe/core/memory.lp"
import "universe/core/string.lp"
import "universe/core/fs.lp"
import "universe/core/net.lp"
import "universe/core/http.lp"

@fn maya_declare_universe()
  println("==================================================================")
  println("  MAYA UNIVERSE v2.0.0 — Phase 14 (File I/O & Dynamic HTTP)")
  println("==================================================================")
  return 0
@end

@fn main()
  maya_declare_universe()
  heap_init()
  println("Maya OS Booted. Global Heap active.")
  http_listen(8082)
  return 0
@end

@fn print_int(n)
  @if n == 0
    sys_write_byte(1, 48)
    sys_write_byte(1, 10)
    return 0
  @end
  
  buf = malloc(32)
  i = 30
  sys_poke8(buf + 31, 10)
  
  is_neg = 0
  @if n < 0
    is_neg = 1
    n = 0 - n
  @end
  
  @while n > 0
    rem = n - ((n / 10) * 10)
    sys_poke8(buf + i, 48 + rem)
    n = n / 10
    i = i - 1
  @end
  
  @if is_neg == 1
    sys_poke8(buf + i, 45)
    i = i - 1
  @end
  
  j = i + 1
  @while j <= 31
    sys_write_byte(1, sys_peek8(buf + j))
    j = j + 1
  @end
  
  free(buf)
  return 0
@end
