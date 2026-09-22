# 👑 08_baremetal_os

A standalone x86 Multiboot-1 compliant bare-metal operating system kernel built with Lipi. Boasts direct 0xB8000 VGA Text Mode framebuffering and boots directly on real silicon or QEMU without Linux or any host OS.

## How to Build & Run:
```bash
# Compile and synthesize the Multiboot OS Kernel ELF
./bin/lipi examples/08_baremetal_os/main.lp -o bin/kernel_builder
./bin/kernel_builder

# Boot the kernel directly in QEMU emulator:
qemu-system-x86_64 -kernel dist/lipi_os_kernel.elf
```
