import "universe/core/error"
import "universe/core/math"
import "universe/registry/registry"

@enum TestResult
  Pass
  Fail
@end

@struct TestSuite
  ts_name: string
  ts_pass: i64
  ts_fail: i64
  ts_total: i64
@end

@impl TestSuite
  @fn check(self, name, cond)
    self.ts_total = self.ts_total + 1
    @if cond == 1
      self.ts_pass = self.ts_pass + 1
      println("  [PASS] " + name)
    @else
      self.ts_fail = self.ts_fail + 1
      println("  [FAIL] " + name)
    @end
    return self
  @end
  
  @fn report(self)
    println("")
    println(self.ts_name + ": " + int_to_str(self.ts_pass) + "/" + int_to_str(self.ts_total) + " passed")
    @if self.ts_fail == 0
      println("ALL PASS")
    @else
      println(int_to_str(self.ts_fail) + " FAILED")
    @end
    return self
  @end
@end

@fn test_core()
  suite = { ts_name: "Core Language", ts_pass: 0, ts_fail: 0, ts_total: 0 }
  
  @! Basic arithmetic
  suite = suite.check("Addition", 2 + 3 == 5)
  suite = suite.check("Multiplication", 6 * 7 == 42)
  suite = suite.check("String concat", str_contains(str_concat("hello", " world"), "world"))
  suite = suite.check("int_to_str", int_to_str(42) == "42")
  suite = suite.check("int_from_str", int_from_str("100") == 100)
  suite = suite.check("str_len", str_len("hello") == 5)
  
  suite = suite.report()
  return suite.ts_fail
@end

@fn test_result_type()
  suite = { ts_name: "Result/Option Types", ts_pass: 0, ts_fail: 0, ts_total: 0 }
  
  r1 = ok(42)
  suite = suite.check("ok() is_ok", is_ok(r1))
  suite = suite.check("ok() unwrap", unwrap(r1) == 42)
  
  r2 = err("not found")
  suite = suite.check("err() is_err", is_err(r2))
  suite = suite.check("err_msg", err_msg(r2) == "not found")
  suite = suite.check("unwrap_or fallback", unwrap_or(r2, -1) == -1)
  
  suite = suite.report()
  return suite.ts_fail
@end

@fn test_registry()
  suite = { ts_name: "Maya Registry", ts_pass: 0, ts_fail: 0, ts_total: 0 }
  
  reg = registry_new("https://registry.maya-lang.org")
  
  p1 = package_new("maya-json", "1.0.0", "shafiullah", "JSON parser for Maya")
  p2 = package_new("maya-http", "2.1.0", "shafiullah", "HTTP client for Maya")
  p3 = package_new("maya-crypto", "1.5.0", "shafiullah", "Crypto library")
  
  reg = registry_publish(reg, p1)
  reg = registry_publish(reg, p2)
  reg = registry_publish(reg, p3)
  
  suite = suite.check("registry publish 3 packages", reg.reg_total == 3)
  
  results = registry_search(reg, "maya")
  suite = suite.check("search finds packages", results.len() >= 1)
  
  found = registry_find(reg, "maya-http", "2.1.0")
  suite = suite.check("find specific package", found.pkg_name == "maya-http")
  
  suite = suite.report()
  return suite.ts_fail
@end

@fn test_enum()
  suite = { ts_name: "@enum", ts_pass: 0, ts_fail: 0, ts_total: 0 }
  
  r = TestResult_Pass
  suite = suite.check("Pass == 0", r == 0)
  
  f = TestResult_Fail
  suite = suite.check("Fail == 1", f == 1)
  
  suite = suite.report()
  return suite.ts_fail
@end

@fn main()
  println("================================================================")
  println("  MAYA UNIVERSE — Final Integration Test")
  println("================================================================")
  println("")
  
  total_fail = 0
  total_fail = total_fail + test_core()
  total_fail = total_fail + test_result_type()
  total_fail = total_fail + test_registry()
  total_fail = total_fail + test_enum()
  
  println("")
  println("================================================================")
  @if total_fail == 0
    println("  ALL UNIVERSE TESTS PASSED!")
    println("  Maya is the Universe. Maya is free.")
  @else
    println("  FAILURES: " + int_to_str(total_fail))
  @end
  println("================================================================")
  
  return total_fail
@end
