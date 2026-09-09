# 👑 02_http_server

A zero-dependency high-throughput HTTP web server implemented directly in pure Lipi using Linux kernel socket system calls (`SYS_socket`, `SYS_bind`, `SYS_listen`).

## How to Build & Run:
```bash
# Compile to standalone native ELF binary
./bin/lipi examples/02_http_server/main.lp -o bin/web_server

# Start the server on port 8080
./bin/web_server
```
