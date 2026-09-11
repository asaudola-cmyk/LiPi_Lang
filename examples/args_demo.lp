@fn main()
  argc = process_argc()
  println("Args count: " + int_to_str(argc))
  i = 0
  @while i < argc
    println("  argv[" + int_to_str(i) + "] = " + process_argv(i))
    i = i + 1
  @end
  println("Done!")
  return 0
@end
