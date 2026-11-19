// ==============================================================================
// 👑 C++ HIGH-THROUGHPUT MULTI-THREADED HTTP BENCHMARK SERVER
// Architecture: std::thread + SO_REUSEPORT + Keep-Alive HTTP/1.1
// ==============================================================================

#include <iostream>
#include <thread>
#include <vector>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

constexpr int PORT = 8002;
constexpr int NUM_WORKERS = 4;
constexpr char HTTP_RESP[] =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/plain\r\n"
    "Content-Length: 13\r\n"
    "Connection: keep-alive\r\n\r\n"
    "Hello, World!";

// WHY: High-concurrency C++ worker threads bound to isolated SO_REUSEPORT sockets
void worker_loop() {
    int sfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sfd < 0) return;

    int opt = 1;
    setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    setsockopt(sfd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(PORT);

    if (bind(sfd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        close(sfd);
        return;
    }

    if (listen(sfd, 2048) < 0) {
        close(sfd);
        return;
    }

    char buf[2048];
    while (true) {
        int cfd = accept(sfd, nullptr, nullptr);
        if (cfd < 0) continue;
        while (true) {
            ssize_t n = read(cfd, buf, sizeof(buf));
            if (n <= 0) break;
            if (write(cfd, HTTP_RESP, sizeof(HTTP_RESP) - 1) <= 0) break;
        }
        close(cfd);
    }
}

int main() {
    std::vector<std::thread> workers;
    workers.reserve(NUM_WORKERS);
    for (int i = 0; i < NUM_WORKERS; ++i) {
        workers.emplace_back(worker_loop);
    }
    std::cout << "[C++] Server listening on 0.0.0.0:" << PORT
              << " with " << NUM_WORKERS << " worker threads" << std::endl;
    for (auto& t : workers) {
        t.join();
    }
    return 0;
}
