// ==============================================================================
// 👑 RUST HIGH-THROUGHPUT MULTI-THREADED HTTP BENCHMARK SERVER
// Architecture: std::sync::Arc<TcpListener> + std::thread Worker Pool + Keep-Alive
// ==============================================================================

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::Arc;
use std::thread;

const PORT: u16 = 8003;
const NUM_WORKERS: usize = 4;
const HTTP_RESP: &[u8] = b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\nConnection: keep-alive\r\n\r\nHello, World!";

// WHY: Multi-threaded worker pool sharing a single native TCP listener.
// Each worker thread accepts connections concurrently and loops on keep-alive.
fn main() {
    let listener = TcpListener::bind(format!("0.0.0.0:{}", PORT)).expect("bind failed");
    let listener = Arc::new(listener);

    println!("[Rust] Server listening on 0.0.0.0:{} with {} worker threads", PORT, NUM_WORKERS);

    let mut handles = Vec::with_capacity(NUM_WORKERS);
    for _ in 0..NUM_WORKERS {
        let listener = Arc::clone(&listener);
        handles.push(thread::spawn(move || {
            let mut buf = [0u8; 2048];
            loop {
                if let Ok((mut stream, _)) = listener.accept() {
                    loop {
                        match stream.read(&mut buf) {
                            Ok(0) | Err(_) => break,
                            Ok(_) => {
                                if stream.write_all(HTTP_RESP).is_err() {
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }));
    }

    for h in handles {
        let _ = h.join();
    }
}
