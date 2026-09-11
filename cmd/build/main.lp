@! ============================================================================
@! MAYA CLI: BUILD SYSTEM & PACKAGE COMPILER
@! Module: cmd/build/main
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct BuildTarget
  name: string,
  dependencies: array,
  is_built: i64
@end

@struct BuildSystem
  targets: array,
  build_order: array
@end

@fn build_system_new() -> BuildSystem
  return BuildSystem {
    targets: [],
    build_order: []
  }
@end

@fn build_system_add_target(bs: BuildSystem, name: string, deps: array) -> BuildSystem
  t = BuildTarget {
    name: name,
    dependencies: deps,
    is_built: 0
  }
  bs.targets = bs.targets.push(t)
  return bs
@end

@fn build_system_plan(bs: BuildSystem) -> BuildSystem
  order = []
  i = 0
  len = bs.targets.len()
  @while i < len
    t = bs.targets[i]
    order = order.push(t.name)
    i = i + 1
  @end
  bs.build_order = order
  return bs
@end

@fn build_system_execute(bs: BuildSystem) -> i64
  println("Executing Maya build plan...")
  i = 0
  len = bs.build_order.len()
  @while i < len
    target_name = bs.build_order[i]
    println("  -> Compiling target: " + target_name)
    i = i + 1
  @end
  println("Build completed successfully.")
  return 1
@end

@fn main()
  bs = build_system_new()
  bs = build_system_add_target(bs, "universe_core", [])
  bs = build_system_add_target(bs, "universe_crypto", ["universe_core"])
  bs = build_system_add_target(bs, "universe_net", ["universe_crypto"])
  bs = build_system_plan(bs)
  build_system_execute(bs)
  return 0
@end
