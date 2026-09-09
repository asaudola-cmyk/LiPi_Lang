// Test 11: Bare Metal / Hardware Control — Lipi 2.0
// Demonstrates: port I/O simulation, register patterns, syscall-like dispatch
// NOTE: Uses decimal port numbers (no hex literals — not supported by parser)

// Simulate reading from a hardware port (returns a mock register value)
// Port 1016 = 0x3F8 (UART), Port 96 = 0x60 (PS/2)
fn port_read port
    if port == 1016
        return 65    // UART data register mock: ASCII 'A'
    elif port == 96
        return 28    // PS/2 keyboard: Enter key scancode (0x1C)
    else
        return 0     // Unknown port returns 0

// Simulate writing to a port (returns acknowledgement code)
fn port_write port value
    if port == 1016
        return 1     // UART write acknowledged
    elif port == 32
        return 1     // PIC end-of-interrupt acknowledged (0x20 = 32)
    else
        return 0     // Unknown port, write ignored

// Simulated syscall dispatcher
// syscall 1 = sys_write (returns bytes written), syscall 60 = sys_exit
fn syscall number arg1 arg2
    if number == 1
        return arg2    // sys_write: return length
    elif number == 60
        return arg1    // sys_exit: return exit code
    else
        return -1      // ENOSYS

// Read from UART (port 0x3F8 = 1016)
uart_data = port_read 1016
say "UART read:"
say uart_data

// Read keyboard scancode (port 0x60 = 96)
key_code = port_read 96
say "Keyboard scancode:"
say key_code

// Write to UART
ack = port_write 1016 72
say "UART write ack:"
say ack

// Write to unknown port
unk = port_write 999 0
say "Unknown port write:"
say unk

// Simulate syscall write (fd=1, len=13)
bytes_written = syscall(1, 1, 13)
say "Bytes written:"
say bytes_written

// Simulate syscall exit (code=0)
exit_code = syscall(60, 0, 0)
say "Exit code:"
say exit_code

say "PASS: Test 11 Baremetal Hardware"
