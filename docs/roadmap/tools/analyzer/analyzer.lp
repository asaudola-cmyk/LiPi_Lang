@! ============================================================================
@! MAYA STATIC ANALYSIS & LINTER (maylint)
@! 100% Written in Pure Maya Language
@! ============================================================================

import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "compiler/frontend/borrowck"

@fn lint_source_file(source_code)
  println("  [Linter] Running static analysis & lint passes on Maya source...")
  
  ast = parse_all(source_code)
  type_errs = typecheck_program(ast)
  borrow_errs = borrowck_program(ast)
  
  total_warnings = []
  @for err in type_errs
    total_warnings = total_warnings.push("[TypeCheck] " + err)
  @end
  @for err in borrow_errs
    total_warnings = total_warnings.push("[BorrowCheck] " + err)
  @end
  
  @if total_warnings.len() == 0
    println("  ✓ Clean code! 0 warnings, 0 errors.")
  @else
    println("  ⚠️ Found " + total_warnings.len().to_str() + " lint warnings.")
  @end
  
  return total_warnings
@end
