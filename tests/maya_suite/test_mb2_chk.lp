import "universe/os/syscalls"
import "universe/core/string"

@fn main()
  chk = 0 - (3897741526 + 0 + 44)
  v = chk
  @if v < 0
    v = v + 4294967296
  @end
  b0 = (v % 256 + 256) % 256
  b1 = ((v / 256) % 256 + 256) % 256
  b2 = ((v / 65536) % 256 + 256) % 256
  b3 = ((v / 16777216) % 256 + 256) % 256
  println(str_concat("b0 = ", to_str(b0)))
  println(str_concat("b1 = ", to_str(b1)))
  println(str_concat("b2 = ", to_str(b2)))
  println(str_concat("b3 = ", to_str(b3)))
  return 0
@end
