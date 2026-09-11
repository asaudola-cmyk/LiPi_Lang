@! ============================================================================
@! MAYA BUILD SYSTEM TOPOLOGICAL SORT TEST (tests/tools/test_build_system.maya)
@! 100% Pure Maya Implementation — Zero Foreign Syntax
@! ============================================================================

import "universe/core/collections"

@struct BuildTarget
  name: "",
  deps: []
@end

@struct BuildSystem
  targets: {},
  ordered: []
@end

@fn new_build_system()
  return {
    targets: {},
    ordered: []
  }
@end

@fn bs_add_target(bs, name, deps)
  bs.targets[name] = { name: name, deps: deps }
  return bs
@end

@fn bs_topological_sort(bs)
  ordered = []
  visited = {}
  
  @for pair in bs.targets
    name = pair.key
    target = pair.value
    @for dep in target.deps
      @if !visited.contains(dep)
        visited[dep] = 1
        ordered = ordered.push(dep)
      @end
    @end
    @if !visited.contains(name)
      visited[name] = 1
      ordered = ordered.push(name)
    @end
  @end

  bs.ordered = ordered
  return bs
@end

@fn main()
  bs = new_build_system()
  bs = bs_add_target(bs, "a", [])
  bs = bs_add_target(bs, "b", ["a"])
  bs = bs_topological_sort(bs)

  @if bs.ordered.len() != 2
    println("FAIL: Expected 2 targets, got " + bs.ordered.len().to_str())
    return 1
  @end
  @if bs.ordered[0] != "a" || bs.ordered[1] != "b"
    println("FAIL: Unexpected order")
    return 1
  @end

  println("PASS: Build system topological sort verified.")
  return 0
@end
