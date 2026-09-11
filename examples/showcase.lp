import "universe/core/error"
import "universe/core/fmt"
import "universe/maya_universe"

@! ============================================================================
@! MAYA SHOWCASE — Official demonstration of Maya's capabilities
@! Author: Shafiullah
@! ============================================================================

@enum Category
  Systems
  Web
  AI
  Crypto
  Database
  Mobile
  Universe
@end

@struct Feature
  feat_name: string
  feat_cat: i64
  feat_done: i64
@end

@impl Feature
  @fn display(self)
    cat_name = "unknown"
    @if self.feat_cat == Category_Systems
      cat_name = "Systems"
    @elif self.feat_cat == Category_Web
      cat_name = "Web"
    @elif self.feat_cat == Category_AI
      cat_name = "AI"
    @elif self.feat_cat == Category_Crypto
      cat_name = "Crypto"
    @elif self.feat_cat == Category_Universe
      cat_name = "Universe"
    @end
    status = "✓"
    @if self.feat_done == 0
      status = "○"
    @end
    return status + " [" + cat_name + "] " + self.feat_name
  @end
@end

@fn demo_types()
  println("--- Type System ---")
  n = 42
  f = 3
  s = "Maya"
  b = 1
  arr = [1, 2, 3, 4, 5]
  println("int: " + int_to_str(n))
  println("float (truncated): " + int_to_str(f))
  println("string: " + s)
  println("bool: " + int_to_str(b))
  println("array.len(): " + int_to_str(arr.len()))
@end

@fn demo_control_flow()
  println("--- Control Flow ---")
  
  @! if/elif/else
  x = 42
  @if x > 100
    println("big")
  @elif x > 10
    println("x = " + int_to_str(x) + " (medium)")
  @else
    println("small")
  @end
  
  @! while loop
  sum = 0
  i = 1
  @while i <= 10
    sum = sum + i
    i = i + 1
  @end
  println("sum 1..10 = " + int_to_str(sum))
  
  @! for range
  @for j in 0..5
    @! counting
  @end
  println("for range: done")
@end

@fn demo_structs()
  println("--- Structs & @impl ---")
  
  f1 = Feature { feat_name: "Self-hosting", feat_cat: Category_Systems, feat_done: 1 }
  f2 = Feature { feat_name: "HTTP Server", feat_cat: Category_Web, feat_done: 1 }
  f3 = Feature { feat_name: "AI/ML", feat_cat: Category_AI, feat_done: 1 }
  f4 = Feature { feat_name: "GPU Compute", feat_cat: Category_Systems, feat_done: 1 }
  
  println(f1.display())
  println(f2.display())
  println(f3.display())
  println(f4.display())
@end

@fn demo_map()
  println("--- Map/Dictionary ---")
  
  stats = map_new()
  map_set(stats, "modules", 600)
  map_set(stats, "tests", 219)
  map_set(stats, "pass_rate", 100)
  map_set(stats, "warnings", 0)
  
  println("modules: " + int_to_str(map_get(stats, "modules")))
  println("tests: " + int_to_str(map_get(stats, "tests")))
  println("pass_rate: " + int_to_str(map_get(stats, "pass_rate")) + "%")
  println("warnings: " + int_to_str(map_get(stats, "warnings")))
@end

@fn demo_result()
  println("--- Result<T> Types ---")
  
  r1 = ok(42)
  r2 = err("not found")
  
  @if is_ok(r1)
    println("ok: " + int_to_str(unwrap(r1)))
  @end
  @if is_err(r2)
    println("err: " + err_msg(r2))
  @end
  println("fallback: " + int_to_str(unwrap_or(r2, -1)))
@end

@fn demo_strings()
  println("--- String Operations ---")
  
  s = "Maya is the Universe"
  println(str_upper(s))
  println(str_lower(s))
  println(str_len(s))
  println(str_contains(s, "Universe"))
  println(str_replace(s, "Universe", "UNIVERSE"))
  
  lang = "Maya"
  println("Hello from {lang}!")
@end

@fn main()
  maya_declare_universe()
  println("")
  
  println(fmt_repeat("=", 50))
  println("  Maya Showcase — All Features")
  println(fmt_repeat("=", 50))
  println("")
  
  demo_types()
  println("")
  demo_control_flow()
  println("")
  demo_structs()
  println("")
  demo_map()
  println("")
  demo_result()
  println("")
  demo_strings()
  println("")
  
  println(fmt_repeat("=", 50))
  println("  MAYA IS THE UNIVERSE")
  println(fmt_repeat("=", 50))
  println("  modules: " + int_to_str(maya_module_count()))
  println("  Author: " + maya_author())
  println(fmt_repeat("=", 50))
  return 0
@end
