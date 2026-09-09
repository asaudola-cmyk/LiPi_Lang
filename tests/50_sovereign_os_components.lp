// Test 50: OS Components — Lipi 2.0 Global Standard

fn vfs_mount device mp fstype
    say "Mount: " + device + " -> " + mp + " [" + fstype + "]"
    return 1

fn vfs_open path flags
    say "Open: " + path
    return 4

fn vfs_read_op fd size
    say "Read fd=" + fd + " size=" + size
    return size

fn vfs_write_op fd size
    say "Write fd=" + fd + " size=" + size
    return size

fn task_create name priority
    say "Task: " + name + " pri=" + priority
    return 1

fn scheduler_yield
    say "yield"

fn ipc_pipe
    say "Pipe: created"
    return 3

fn ipc_send_msg pipe_fd msg
    say "IPC send: " + msg
    return 1

fn ipc_recv_msg pipe_fd
    say "IPC recv fd=" + pipe_fd
    return 1

say "=== OS Components ==="
vfs_mount("/dev/sda1", "/", "ext4")
vfs_mount("tmpfs", "/tmp", "tmpfs")
vfs_mount("proc", "/proc", "procfs")

fd = vfs_open("/etc/config", 0)
vfs_read_op(fd, 4096)
vfs_write_op(fd, 7)

task_create("init", 1)
task_create("httpd", 5)
task_create("worker", 3)

repeat 3
    scheduler_yield()

pipe = ipc_pipe()
ipc_send_msg(pipe, "hello from process1")
ipc_recv_msg(pipe)

say "OS: operational"
say "PASS: Test 50 OS Components"
