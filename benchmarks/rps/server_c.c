// ==============================================================================
// 👑 C HIGH-THROUGHPUT MULTI-THREADED HTTP BENCHMARK SERVER
// Hardware Architecture: 4 Worker Threads matching 4 Physical Cores
// Socket Model: SO_REUSEPORT Kernel Load-Balancing + Keep-Alive HTTP/1.1
// ==============================================================================

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define PORT 8001
#define NUM_WORKERS 4

static const char HTTP_RESP[] =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/plain\r\n"
    "Content-Length: 13\r\n"
    "Connection: keep-alive\r\n\r\n"
    "Hello, World!";

// WHY: Each worker thread creates its own listening socket on the same port
// using Linux SO_REUSEPORT. The Linux kernel distributes incoming connections
// across threads without any userspace lock contention.
void* worker_thread(void* arg) {
    (void)arg;
    int sfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sfd < 0) return NULL;

    int opt = 1;
    setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    setsockopt(sfd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(PORT);

    if (bind(sfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sfd);
        return NULL;
    }

    if (listen(sfd, 2048) < 0) {
        close(sfd);
        return NULL;
    }

    char buf[2048];
    while (1) {
        int cfd = accept(sfd, NULL, NULL);
        if (cfd < 0) continue;
        while (1) {
            ssize_t n = read(cfd, buf, sizeof(buf));
            if (n <= 0) break;
            if (write(cfd, HTTP_RESP, sizeof(HTTP_RESP) - 1) <= 0) break;
        }
        close(cfd);
    }
    return NULL;
}

int main(void) {
    pthread_t th[NUM_WORKERS];
    for (int i = 0; i < NUM_WORKERS; i++) {
        pthread_create(&th[i], NULL, worker_thread, NULL);
    }
    printf("[C] Server listening on 0.0.0.0:%d with %d worker threads\n", PORT, NUM_WORKERS);
    fflush(stdout);
    for (int i = 0; i < NUM_WORKERS; i++) {
        pthread_join(th[i], NULL);
    }
    return 0;
}
