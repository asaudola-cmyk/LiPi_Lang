@fn mem_alloc(size)
  return syscall(9, 0, size, 3, 34, -1, 0)
@end

@fn mem_free(ptr, size)
  return syscall(11, ptr, size, 0, 0, 0, 0)
@end

@fn main()
  println("Testing direct churn...")
  c = 0
  allocs = 0
  frees = 0
  @while c < 1000
    p1 = mem_alloc(64)
    p2 = mem_alloc(128)
    p3 = mem_alloc(512)
    p4 = mem_alloc(2048)
    allocs = allocs + 4
    
    @if p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0
      return 1
    @end
    
    mem_free(p1, 64)
    mem_free(p2, 128)
    mem_free(p3, 512)
    mem_free(p4, 2048)
    frees = frees + 4
    
    c = c + 1
  @end
  println("Completed churn cycles:")
  println(c)
  println("Total allocs:")
  println(allocs)
  println("Total frees:")
  println(frees)
  return 0
@end
