# 08_baremetal_os

Standalone x86 Multiboot bare-metal kernel builder written in Lipi with direct `0xB8000` VGA text-mode output, bootable in QEMU.

## Build & Run

```bash
./bin/lipc examples/08_baremetal_os/main.lp -o /tmp/kernel_builder
/tmp/kernel_builder

# Boot in QEMU
qemu-system-x86_64 -kernel dist/lipi_os_kernel.elf
```
