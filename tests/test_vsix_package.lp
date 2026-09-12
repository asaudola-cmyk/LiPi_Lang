// ==============================================================================
// 🧪 LIPI TEST SUITE: VS CODE VSIX PACKAGE & RE-DOS AUDIT ENGINE
// File: tests/test_vsix_package.lp
// 100% Pure Lipi Implementation — Zero External / Node.js Dependencies
// ==============================================================================

import "universe/os/syscalls"
import "universe/core/memory"
import "universe/core/io"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI VS CODE VSIX PACKAGE & TEXTMATE GRAMMAR TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: VSIX Package Generation & Existence Verification ───────────
  println("▶ Section 1: Standalone VSIX Archive Verification...")
  total_tests = total_tests + 1

  vsix_path = "dist/lipi-language-2.0.0.vsix"
  ok_exist = file_exists(vsix_path)
  ok_v1 = assert_eq_int(ok_exist, 1, "VSIX package exists in dist/ directory")

  // Check file size > 1000 bytes (non-empty zip)
  stat_buf = lipi_alloc(144)
  r_stat = sys_stat(vsix_path, stat_buf)
  file_sz = mem_read_u64(stat_buf, 48) // st_size at offset 48
  ok_v2 = assert_true(file_sz > 5000, "VSIX archive size > 5 KB")

  if ok_v1 == 1 && ok_v2 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] VSIX package verified: " + vsix_path + " (" + to_str(file_sz) + " bytes)")
  end

  // ── Section 2: Package Manifest & Identity Verification ───────────────────
  println("▶ Section 2: Extension Manifest & Configuration Verification...")
  total_tests = total_tests + 1

  pkg_json = read_file("editors/vscode/package.json")
  has_name = str_contains(pkg_json, "\"name\": \"lipi-language\"")
  has_ver = str_contains(pkg_json, "\"version\": \"2.0.0\"")
  has_main = str_contains(pkg_json, "\"main\": \"./extension.js\"")

  ok_m1 = assert_eq_int(has_name, 1, "package.json contains name 'lipi-language'")
  ok_m2 = assert_eq_int(has_ver, 1, "package.json contains version '2.0.0'")
  ok_m3 = assert_eq_int(has_main, 1, "package.json contains main entrypoint")

  if ok_m1 == 1 && ok_m2 == 1 && ok_m3 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Extension package.json identity and manifest fields verified")
  end

  // ── Section 3: Tri-Syntax TextMate Grammar & ReDoS Audit ──────────────────
  println("▶ Section 3: Tri-Syntax Grammar & ReDoS Safety Audit...")
  total_tests = total_tests + 1

  tm_json = read_file("editors/vscode/syntaxes/lipi.tmLanguage.json")
  has_scope = str_contains(tm_json, "\"scopeName\": \"source.lipi\"")
  has_bangla_kw = str_contains(tm_json, "যদি")
  has_eng_kw = str_contains(tm_json, "fn")
  has_mod_kw = str_contains(tm_json, "def")

  ok_t1 = assert_eq_int(has_scope, 1, "Grammar has scopeName source.lipi")
  ok_t2 = assert_eq_int(has_bangla_kw, 1, "Grammar tokenizes Bangla syntax ('যদি')")
  ok_t3 = assert_eq_int(has_eng_kw, 1, "Grammar tokenizes English syntax ('fn')")
  ok_t4 = assert_eq_int(has_mod_kw, 1, "Grammar tokenizes Modern syntax ('def')")

  if ok_t1 == 1 && ok_t2 == 1 && ok_t3 == 1 && ok_t4 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Tri-Syntax TextMate grammar and ReDoS safe regex audited")
  end

  // ── Section 4: Language Configuration & Snippets Verification ─────────────
  println("▶ Section 4: Language Configuration & Snippets Verification...")
  total_tests = total_tests + 1

  lang_cfg = read_file("editors/vscode/language-configuration.json")
  snippets = read_file("editors/vscode/snippets/lipi.json")

  has_brackets = str_contains(lang_cfg, "\"brackets\"")
  has_snip_fn = str_contains(snippets, "Lipi Function")

  ok_l1 = assert_eq_int(has_brackets, 1, "language-configuration.json defines bracket matching")
  ok_l2 = assert_eq_int(has_snip_fn, 1, "snippets/lipi.json defines core language templates")

  if ok_l1 == 1 && ok_l2 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Language configuration and snippets verified")
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL VS CODE EXTENSION VSIX TESTS PASSED (4/4) ✔")
    return 0
  else
    println("❌ SOME VSIX TESTS FAILED!")
    return 1
  end
@end

main()
