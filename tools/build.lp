@! Pure Maya Build Orchestrator using raw syscalls

@struct ProcessStatus
  val: 0
@end

@fn build_module(name, source_path, out_path)
  println("Building " + name + " (" + source_path + " -> " + out_path + ")...")
  
  pid = syscall(57, 0, 0, 0, 0, 0, 0)
  
  @if pid == 0
    syscall(59, "./bin/mayac_v2", source_path, "-o", out_path, 0, 0)
    syscall(60, 1, 0, 0, 0, 0, 0)
  @end
  
  @if pid > 0
    ps = ProcessStatus { val: 0 }
    syscall(61, pid, ps, 0, 0, 0, 0)
    status = ps.val
    
    @if (status % 256) == 0
      exit_code = (status / 256) % 256
      @if exit_code == 0
        println("✓ Built " + name)
        return 0
      @else
        println("❌ Build failed for " + name)
        return 1
      @end
    @end
  @end
  
  println("❌ Build failed for " + name)
  return 1
@end

@fn main()
  println("▶ Starting Pure Maya Build Orchestrator")
  
  fails = 0
  fails = fails + build_module("DB Parser", "universe/db/sql/parser.lp", "build/db_parser.o")
  fails = fails + build_module("Raft", "universe/db/distributed/raft.lp", "build/raft.o")
  
  @if fails == 0
    println("▶ Universe build complete!")
    return 0
  @else
    println("▶ Build failed with " + int_to_str(fails) + " errors.")
    return 1
  @end
@end
