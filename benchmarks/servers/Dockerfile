# ==============================================================================
# 👑 LIPI SOVEREIGN ZERO-LIBC MICRO-CONTAINER
# ⚡ 100% Pure Native Silicon Machine Code | 0% Libc | 0% Alpine | FROM scratch
#
# WHY: Lipi produces completely autonomous ELF64 executables that invoke Linux AMD64
# kernel system calls directly. No C library, dynamic linker (ld-linux.so), shell,
# or OS distribution is required. This results in the world's smallest full-stack
# web server container (< 200 KB) with absolute zero attack surface.
# ==============================================================================

FROM scratch

# Sovereign ELF64 server binary
COPY benchmarks/servers/web_server_bin /lipi_server

# Sovereign documentation & branding assets
COPY docs/branding /docs/branding

# Persistent NVMe/SSD binary database directory
COPY benchmarks/data /benchmarks/data

# Sovereign HTTP web server port
EXPOSE 8088

# Direct silicon entrypoint (no /bin/sh wrapper)
ENTRYPOINT ["/lipi_server", "8088"]
