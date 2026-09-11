@! ============================================================================
@! MAYA E2E TIER 1 — F20: Test Report Serialization
@! File: tests/e2e/tier1_features/infra/test_f20_test_report_serialization.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/string"
import "universe/tools/maya_test"

@fn main()
  mock_res = [
    { name: "t1", tier: 1, category: "ai", passed: 1, skipped: 0, duration_ms: 1, exit_code: 0, signal_num: 0, signal_name: "", error_msg: "" }
  ]
  xml_file = "/tmp/maya_t1_f20_junit.xml"
  json_file = "/tmp/maya_t1_f20_rep.json"
  
  generate_junit_xml("t20_suite", mock_res, xml_file)
  generate_json_report("t20_suite", mock_res, json_file)

  xml_str = fs_read_file(xml_file)
  json_str = fs_read_file(json_file)

  sys_unlink(xml_file)
  sys_unlink(json_file)

  @if string_contains(xml_str, "<testsuite") != 1 return 1 @end
  @if string_contains(json_str, "\"suite\"") != 1 return 1 @end
  println("✓ PASS: test_f20_test_report_serialization")
  return 0
@end
