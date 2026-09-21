// ==============================================================================
// 🧪 LIPI SOVEREIGN ZERO-SHELL NATIVE TOOLCHAIN TEST SUITE
// Test Suite: tests/test_zero_shell_sovereignty.lp
// Purpose: Validates 100% Native Silicon Build & Install Engines (0% Bash, 0% C)
// Version: First 1.0.0 (প্রথম ১.০.০) — Fixed
// 100% Pure LiPi Implementation — Zero External / C / Node.js Dependencies
// ==============================================================================

include "build.lp"
include "src/tools/installer.lp"

// ── Test Assertion Utilities ──────────────────────────────────────────────────

fn assert_eq actual expected label
    if actual == expected
        say "  ✔ [PASS] " + label + ": " + actual
        return 1
    else
        say "  ❌ [FAIL] " + label + " -> Expected: " + expected + ", Got: " + actual
        return 0

fn assert_gt actual minimum label
    if actual > minimum
        say "  ✔ [PASS] " + label + ": " + actual + " > " + minimum
        return 1
    else
        say "  ❌ [FAIL] " + label + " -> Expected > " + minimum + ", Got: " + actual
        return 0

// ── Main Test Runner ──────────────────────────────────────────────────────────

fn main
    say "================================================================="
    say "👑 LIPI ZERO-SHELL SOVEREIGNTY TEST SUITE (VERSION: First 1.0.0) 👑"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: Build Target State Machine & Lifecycle ─────────────────────
    say "\n▶ Section 1: Build Target State Machine & Lifecycle..."
    total_tests = total_tests + 1
    // WHY: Target canonical sovereign compiler binary (bin/lipc)
    target = build_target_new("Native ELF Emitter", "src/compiler/driver_cli.lp", "bin/lipc", 1)
    
    ok_t1 = assert_eq(target.bt_status, BUILD_STATUS_PENDING, "Initial Target Status is PENDING")
    ok_t2 = assert_eq(target.bt_is_required, 1, "Target is Marked Required")

    build_target_mark_complete(target, 1, 45)
    ok_t3 = assert_eq(target.bt_status, BUILD_STATUS_OK, "Target Transitioned to BUILD_STATUS_OK")
    ok_t4 = assert_eq(target.bt_duration_ms, 45, "Target Duration Recorded (45ms)")

    if ok_t1 == 1 and ok_t2 == 1 and ok_t3 == 1 and ok_t4 == 1
        passed_tests = passed_tests + 1

    // ── Section 2: Build Pipeline Orchestration & Closure ─────────────────────
    say "\n▶ Section 2: Build Pipeline Orchestration & Closure..."
    total_tests = total_tests + 1
    pipe = build_pipeline_new()
    build_pipeline_add_target(pipe, "Core Compiler", "src/compiler/driver_cli.lp", "bin/lipc", 1)
    build_pipeline_add_target(pipe, "Sovereign Framework", "universe/web/sovereign_framework.lp", "dist/framework", 1)
    build_pipeline_add_target(pipe, "Ecosystem Tests", "tests/test_sovereign_fullstack_suite.lp", "dist/test", 1)

    ok_p1 = assert_eq(pipe.bp_total_targets, 3, "Pipeline Registered 3 Targets")
    passed_count = build_pipeline_run_all(pipe)
    ok_p2 = assert_eq(passed_count, 3, "Pipeline Executed All 3 Targets Successfully")
    ok_p3 = assert_eq(pipe.bp_passed_targets, 3, "Passed Targets Counter Matches Total")

    if ok_p1 == 1 and ok_p2 == 1 and ok_p3 == 1
        passed_tests = passed_tests + 1

    // ── Section 3: Native Installer Asset Manifest & Registration ─────────────
    say "\n▶ Section 3: Native Installer Manifest Registration..."
    total_tests = total_tests + 1
    inst = installer_engine_new("/home/test/.lipi", "/home/test/.local/bin")
    
    f1 = installer_add_file(inst, "bin/lipi", "/home/test/.local/bin/lipi", 1)
    f2 = installer_add_file(inst, "bin/lipc", "/home/test/.local/bin/lipc", 1)
    f3 = installer_add_file(inst, "universe/web/", "/home/test/.lipi/universe/web/", 0)

    ok_i1 = assert_eq(f1.if_is_executable, 1, "Binary Marked Executable")
    ok_i2 = assert_eq(f3.if_is_executable, 0, "Library Folder Marked Non-Executable")
    ok_i3 = assert_eq(f1.if_is_installed, 0, "Asset Pending Installation")

    if ok_i1 == 1 and ok_i2 == 1 and ok_i3 == 1
        passed_tests = passed_tests + 1

    // ── Section 4: Native Installer Deployment & Verification ─────────────────
    say "\n▶ Section 4: Native Installer Deployment & Verification..."
    total_tests = total_tests + 1
    deployed = installer_deploy_all(inst)
    
    ok_d1 = assert_eq(deployed, 3, "Deployed All 3 Manifest Assets")
    ok_d2 = assert_eq(f1.if_is_installed, 1, "Binary Asset 1 Marked Installed")
    ok_d3 = assert_eq(f2.if_is_installed, 1, "Binary Asset 2 Marked Installed")
    ok_d4 = assert_eq(f3.if_is_installed, 1, "Library Asset 3 Marked Installed")

    if ok_d1 == 1 and ok_d2 == 1 and ok_d3 == 1 and ok_d4 == 1
        passed_tests = passed_tests + 1

    // ── Section 5: Version Invariance Gate: First 1.0.0 ────────────────────────
    say "\n▶ Section 5: Version Invariance Gate (First 1.0.0 Fixed)..."
    total_tests = total_tests + 1
    
    // Strict requirement: version must be First 1.0.0 (version code 100)
    ok_v1 = assert_eq(pipe.bp_version_code, 100, "Build Pipeline Version Code is 100 (First 1.0.0)")
    ok_v2 = assert_eq(inst.ie_version_code, 100, "Installer Engine Version Code is 100 (First 1.0.0)")

    if ok_v1 == 1 and ok_v2 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // FINAL SUITE VERIFICATION REPORT
    // ─────────────────────────────────────────────────────────────────────────
    say "\n================================================================="
    say "🎉 ZERO-SHELL SOVEREIGNTY RESULTS: " + passed_tests + "/" + total_tests + " SECTIONS PASSED"
    say "================================================================="

    if passed_tests == total_tests
        say "👑 100% PASS: NATIVE ZERO-SHELL SOVEREIGNTY FULLY OPERATIONAL!"
        return 0
    else
        say "❌ SOME SECTIONS FAILED!"
        return 1
