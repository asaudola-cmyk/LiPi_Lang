@fn main()
  println("Checking churn counters...")
  slots = []
  i = 0
  @while i < 64
    slots = slots.push(0)
    i = i + 1
  @end
  allocs = 0
  frees = 0
  c = 0
  @while c < 2000
    idx = c % 64
    old_p = slots[idx]
    @if old_p > 0
      frees = frees + 1
      slots[idx] = 0
    @end
    p = syscall(9, 0, 64, 3, 34, -1, 0)
    slots[idx] = p
    allocs = allocs + 1
    c = c + 1
  @end
  s = 0
  @while s < 64
    rem = slots[s]
    @if rem > 0
      frees = frees + 1
      syscall(11, rem, 64, 0, 0, 0, 0)
    @end
    s = s + 1
  @end
  println("allocs:")
  println(allocs)
  println("frees:")
  println(frees)
  return 0
@end
