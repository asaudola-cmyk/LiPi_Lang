import test.assert
import test.assert_eq

@test
fn test_repl_is_incomplete() {
    let repl = Repl::new();
    assert(repl.is_incomplete("{".to_string()), "Should detect unclosed brace");
    assert(!repl.is_incomplete("{}".to_string()), "Should be balanced");
}

@test
fn test_repl_handle_command() {
    let repl = Repl::new();
    assert_eq(repl.running, true);
    repl.handle_command(":quit".to_string());
    assert_eq(repl.running, false);
}
