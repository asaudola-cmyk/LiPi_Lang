@fn main()
  s = "ABCDE"
  
  a = s[0]
  @if a == 65
    println("[PASS] s[0] == 65 (A)")
  @else
    println("[FAIL] s[0]")
  @end

  c = s[2]
  @if c == 67
    println("[PASS] s[2] == 67 (C)")
  @else
    println("[FAIL] s[2]")
  @end

  e = s[4]
  @if e == 69
    println("[PASS] s[4] == 69 (E)")
  @else
    println("[FAIL] s[4]")
  @end

  @! Build string from char codes
  ch = str_from_char_code(a)
  println(ch)

  @! Loop over string chars
  total = 0
  i = 0
  len = str_len(s)
  @while i < len
    total = total + s[i]
    i = i + 1
  @end
  println(total)
  @if total == 335
    println("[PASS] sum of char codes A+B+C+D+E = 335")
  @else
    println("[FAIL] sum of chars")
  @end

  return 0
@end
