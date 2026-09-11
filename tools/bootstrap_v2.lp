import "compiler/backend/compiler"

@fn main()
  println("▶ Bootstrapping compiler/maya_compiler_v2.maya -> bin/mayac_v2...")
  res = compile_file_with_options("compiler/maya_compiler_v2.maya", "bin/mayac_v2", 0)
  @if res.cr_success == 1
    println("✓ Bootstrap SUCCESS!")
    return 0
  @else
    println("❌ Bootstrap FAILED: " + res.cr_error_msg)
    return 1
  @end
@end
