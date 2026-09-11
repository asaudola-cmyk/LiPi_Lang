import "compiler/backend/compiler"

@fn main()
  println("Starting empirical compiler test...")
  test_src = "@fn main() println(\"Hello from Maya Sovereign ELF!\") return 42 @end"
  out_path = "/tmp/test_sovereign_elf"
  
  res = compile_source_to_elf(test_src, out_path)
  println("compile_source_to_elf result: " + int_to_str(res))
  return 0
@end
