import cmd::debug::main as dap
import std::collections::Map

@test
fn test_dap_server_init() {
    let server = dap::DapServer::new()
    let req = Map::new()
    req.set("command", "initialize")
    req.set("seq", 1)
    
    // In a real test, we would mock stdin/stdout to capture the response
    // For this structural test, we just instantiate the server
    std::assert(server.breakpoints.is_empty())
}
