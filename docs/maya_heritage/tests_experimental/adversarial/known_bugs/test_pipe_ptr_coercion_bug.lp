@! ============================================================================
@! ADVERSARIAL BUG REPRODUCTION: PIPE OPERATOR TYPE COERCION BUG
@! ============================================================================
@! When an expression produces a pointer (e.g. struct instance, string, array)
@! and is piped into a function whose parameter is typed as i64 (the default in Maya),
@! the pipe operator in src/codegen.cpp (lines 1015-1033) fails to coerce
@! ptr -> i64, triggering an LLVM Module Verification Failure.

@struct Box
  val: 0
@end

@fn make_box(v)
  return { val: v }
@end

@fn get_box_val(b)
  return b.val
@end

@fn main()
  @! Piped call where lhs is pointer (ptr) and callee expects i64
  let result = 42 |> make_box |> get_box_val
  println("Piped result: " + result.to_str())
  return 0
@end
