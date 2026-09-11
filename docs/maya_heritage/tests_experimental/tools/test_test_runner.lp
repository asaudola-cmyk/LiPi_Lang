import test.assert_eq
import test.assert_approx_eq

@test
fn test_assert_eq() {
    assert_eq(1, 1);
    assert_eq("test", "test");
}

@test
fn test_assert_approx_eq() {
    assert_approx_eq(1.0, 1.0000001, 1e-5);
}

@test
fn test_discover_tests() {
    let runner = TestRunner::new(1);
    runner.discover_tests("tests/");
    assert(runner.files.len() > 0, "Should find tests");
}
