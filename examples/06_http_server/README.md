# 06_http_server

Zero-dependency HTTP web server implemented directly in Lipi using Linux socket syscalls (`SYS_socket`, `SYS_bind`, `SYS_listen`).

## Build & Run

```bash
./bin/lipc examples/06_http_server/main.lp -o /tmp/web_server
/tmp/web_server
```
