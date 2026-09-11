import "cmd/repl"

@fn main()
  env = repl_env_new()
  
  @! 1. Variable assignments
  r1 = repl_process_line("x = 10 + 5 * 2", env)
  env = r1.env
  println("r1: " + r1.output)
  
  r2 = repl_process_line("y = (x + 10) * 3", env)
  env = r2.env
  println("r2: " + r2.output)
  
  @! 2. Evaluation using variables
  r3 = repl_process_line("y - x * 4", env)
  println("r3: " + r3.output)
  
  return 0
@end
