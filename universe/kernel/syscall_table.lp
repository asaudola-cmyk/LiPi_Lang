@fn SYS_READ()
    return 0
@end

@fn SYS_WRITE()
    return 1
@end

@fn SYS_OPEN()
    return 2
@end

@fn SYS_CLOSE()
    return 3
@end

@fn SYS_MMAP()
    return 9
@end

@fn SYS_MUNMAP()
    return 11
@end

@fn SYS_BRK()
    return 12
@end

@fn SYS_GETPID()
    return 39
@end

@fn SYS_FORK()
    return 57
@end

@fn SYS_EXECVE()
    return 59
@end

@fn SYS_EXIT()
    return 60
@end

@fn SYS_KILL()
    return 62
@end

@fn SYS_SOCKET()
    return 41
@end

@fn SYS_CONNECT()
    return 42
@end

@fn SYS_ACCEPT()
    return 43
@end

@fn SYS_BIND()
    return 49
@end

@fn SYS_LISTEN()
    return 50
@end

@fn SYS_CLONE()
    return 56
@end

@fn SYS_FUTEX()
    return 202
@end

@fn O_RDONLY()
    return 0
@end

@fn O_WRONLY()
    return 1
@end

@fn O_RDWR()
    return 2
@end

@fn O_CREAT()
    return 64
@end

@fn O_TRUNC()
    return 512
@end

@fn O_APPEND()
    return 1024
@end

@fn PROT_NONE()
    return 0
@end

@fn PROT_READ()
    return 1
@end

@fn PROT_WRITE()
    return 2
@end

@fn PROT_EXEC()
    return 4
@end

@fn MAP_PRIVATE()
    return 2
@end

@fn MAP_ANON()
    return 32
@end

@fn AF_INET()
    return 2
@end

@fn AF_INET6()
    return 10
@end

@fn SOCK_STREAM()
    return 1
@end

@fn SOCK_DGRAM()
    return 2
@end

@fn SIGTERM()
    return 15
@end

@fn SIGKILL()
    return 9
@end

@fn SIGINT()
    return 2
@end

@fn kern_read(fd, ptr, count)
    return syscall(SYS_READ(), fd, ptr, count, 0, 0, 0)
@end

@fn kern_write(fd, ptr, count)
    return syscall(SYS_WRITE(), fd, ptr, count, 0, 0, 0)
@end

@fn kern_getpid()
    return syscall(SYS_GETPID(), 0, 0, 0, 0, 0, 0)
@end

@fn kern_exit(code)
    return syscall(SYS_EXIT(), code, 0, 0, 0, 0, 0)
@end

@fn kern_mmap(size)
    return syscall(SYS_MMAP(), 0, size, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), -1, 0)
@end

@fn kern_munmap(addr, size)
    return syscall(SYS_MUNMAP(), addr, size, 0, 0, 0, 0)
@end
