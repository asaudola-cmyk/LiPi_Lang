import "compiler/backend/maya_ir"

@fn new_ast_node()
  return {
    kind: "",
    name: "",
    params: [],
    body: [],
    ret_type: "",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_var(name)
  n = new_ast_node()
  n.kind = "Variable"
  n.name = name
  return n
@end

@fn ast_int(val)
  n = new_ast_node()
  n.kind = "LiteralInt"
  n.val = val
  return n
@end

@fn ast_call(callee_name, args)
  n = new_ast_node()
  n.kind = "Call"
  n.func = ast_var(callee_name)
  n.args = args
  return n
@end

@fn ast_assign(target, value)
  n = new_ast_node()
  n.kind = "Assign"
  n.target = target
  n.value = value
  return n
@end

@fn ast_return(value)
  n = new_ast_node()
  n.kind = "Return"
  n.value = value
  return n
@end

@fn ast_fndef(name, params, ret_type, body)
  n = new_ast_node()
  n.kind = "FnDef"
  n.name = name
  n.params = params
  n.ret_type = ret_type
  n.body = body
  return n
@end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL LINUX SYSCALL ARGUMENT PADDING TEST HARNESS 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Test 1: Syscall with 0 Arguments (getpid: syscall 39)
  @! --------------------------------------------------------------------------
  println("▶ [Syscall 0] Testing syscall(39) [0 extra args]...")
  c0 = ast_call("syscall", [ast_int(39)])
  fn0 = ast_fndef("sys_getpid_wrapper", [], "i64", [
    ast_assign("pid", c0),
    ast_return(ast_var("pid"))
  ])
  res0 = ir_module_from_ast([fn0], { module_name: "mod_sys0", dump_ir: 0 })
  @if res0.error == 0
    fn0_ir = res0.module.functions[0]
    @! Find syscall instruction
    found_sys0 = 0
    @for inst in fn0_ir.blocks[0].instructions
      @if inst.op == "SYSCALL"
        found_sys0 = 1
        println("  Syscall nr: " + inst.nr.to_str() + ", args count: " + inst.args.len().to_str())
        @if inst.args.len() == 6
          println("  [PASS] 0-arg syscall padded to exactly 6 arguments")
        @else
          println("  [FAIL] 0-arg syscall argument count is " + inst.args.len().to_str() + " (expected 6)")
        @end
      @end
    @end
    @if found_sys0 == 0 println("  [FAIL] SYSCALL instruction not found in block") @end
  @else
    println("  [FAIL] Syscall 0 lowering failed: " + res0.message)
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Syscalls with 1, 2, 3, 4, 5, 6 Arguments
  @! --------------------------------------------------------------------------
  arg_counts = [1, 2, 3, 4, 5, 6]
  @for cnt in arg_counts
    println("▶ [Syscall " + cnt.to_str() + "] Testing syscall with " + cnt.to_str() + " arguments...")
    call_args = [ast_int(100 + cnt)]
    a_idx = 1
    @while a_idx <= cnt
      call_args = call_args.push(ast_int(a_idx * 10))
      a_idx = a_idx + 1
    @end
    call_node = ast_call("syscall", call_args)
    fn_node = ast_fndef("sys_test_" + cnt.to_str(), [], "i64", [
      ast_assign("res", call_node),
      ast_return(ast_var("res"))
    ])
    res = ir_module_from_ast([fn_node], { module_name: "mod_sys_" + cnt.to_str(), dump_ir: 0 })
    @if res.error == 0
      fn_ir = res.module.functions[0]
      @for inst in fn_ir.blocks[0].instructions
        @if inst.op == "SYSCALL"
          @if inst.args.len() == 6
            println("  [PASS] Syscall with " + cnt.to_str() + " args correctly normalized to 6 arguments")
          @else
            println("  [FAIL] Syscall with " + cnt.to_str() + " args has length " + inst.args.len().to_str())
          @end
        @end
      @end
    @else
      println("  [FAIL] Syscall with " + cnt.to_str() + " args failed to lower: " + res.message)
    @end
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: maya_syscall alias
  @! --------------------------------------------------------------------------
  println("▶ [Syscall Alias] Testing maya_syscall builtin alias...")
  c_alias = ast_call("maya_syscall", [ast_int(39)])
  fn_alias = ast_fndef("sys_alias_fn", [], "i64", [ast_return(c_alias)])
  res_alias = ir_module_from_ast([fn_alias], { module_name: "mod_alias", dump_ir: 0 })
  @if res_alias.error == 0
    fn_a_ir = res_alias.module.functions[0]
    has_sys = 0
    @for inst in fn_a_ir.blocks[0].instructions
      @if inst.op == "SYSCALL" has_sys = 1 @end
    @end
    @if has_sys == 1
      println("  [PASS] maya_syscall intercepted and lowered to SYSCALL instruction")
    @else
      println("  [FAIL] maya_syscall not lowered to SYSCALL instruction")
    @end
  @else
    println("  [FAIL] maya_syscall lowering failed: " + res_alias.message)
  @end

  return 0
@end
