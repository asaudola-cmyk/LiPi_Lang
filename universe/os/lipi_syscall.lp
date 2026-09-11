@! ============================================================================
@! LIPI DIRECT LINUX x86-64 NATIVE SYSCALL INTERFACE (universe/os/lipi_syscall.lp)
@! 100% Written in Pure Lipi Language — Complete Independence from libc.so
@! Architecture: x86_64-unknown-linux-gnu
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Memory Protection & Mapping Constants
@! ----------------------------------------------------------------------------
@fn PROT_NONE() return 0 @end
@fn PROT_READ() return 1 @end
@fn PROT_WRITE() return 2 @end
@fn PROT_EXEC() return 4 @end
@fn PROT_GROWSDOWN() return 16777216 @end
@fn PROT_GROWSUP() return 33554432 @end

@fn MAP_SHARED() return 1 @end
@fn MAP_PRIVATE() return 2 @end
@fn MAP_SHARED_VALIDATE() return 3 @end
@fn MAP_FIXED() return 16 @end
@fn MAP_ANONYMOUS() return 32 @end
@fn MAP_ANON() return 32 @end
@fn MAP_GROWSDOWN() return 256 @end
@fn MAP_DENYWRITE() return 2048 @end
@fn MAP_EXECUTABLE() return 4096 @end
@fn MAP_LOCKED() return 8192 @end
@fn MAP_NORESERVE() return 16384 @end
@fn MAP_POPULATE() return 32768 @end
@fn MAP_NONBLOCK() return 65536 @end
@fn MAP_STACK() return 131072 @end
@fn MAP_HUGETLB() return 262144 @end
@fn MAP_FIXED_NOREPLACE() return 1048576 @end
@fn MAP_FAILED() return 0 - 1 @end

@! ----------------------------------------------------------------------------
@! 2. File Access & Mode Constants
@! ----------------------------------------------------------------------------
@fn O_RDONLY() return 0 @end
@fn O_WRONLY() return 1 @end
@fn O_RDWR() return 2 @end
@fn O_ACCMODE() return 3 @end
@fn O_CREAT() return 64 @end
@fn O_EXCL() return 128 @end
@fn O_NOCTTY() return 256 @end
@fn O_TRUNC() return 512 @end
@fn O_APPEND() return 1024 @end
@fn O_NONBLOCK() return 2048 @end
@fn O_NDELAY() return 2048 @end
@fn O_SYNC() return 1052672 @end
@fn O_FSYNC() return 1052672 @end
@fn O_ASYNC() return 8192 @end
@fn O_DIRECT() return 16384 @end
@fn O_DIRECTORY() return 65536 @end
@fn O_NOFOLLOW() return 131072 @end
@fn O_NOATIME() return 262144 @end
@fn O_CLOEXEC() return 524288 @end
@fn O_PATH() return 2097152 @end
@fn AT_FDCWD() return 0 - 100 @end

@fn KVM_GET_API_VERSION() return 44544 @end
@fn KVM_CREATE_VM() return 44545 @end
@fn KVM_GET_VCPU_MMAP_SIZE() return 44548 @end
@fn KVM_SET_USER_MEMORY_REGION() return 1075883590 @end
@fn KVM_CREATE_VCPU() return 44609 @end
@fn KVM_RUN() return 44672 @end
@fn KVM_GET_REGS() return 2156965505 @end
@fn KVM_SET_REGS() return 1083223682 @end
@fn KVM_GET_SREGS() return 2167975555 @end
@fn KVM_SET_SREGS() return 1094233732 @end

@fn IORING_OFF_SQ_RING() return 0 @end
@fn IORING_OFF_CQ_RING() return 134217728 @end
@fn IORING_OFF_SQES() return 268435456 @end

@fn SEEK_SET() return 0 @end
@fn SEEK_CUR() return 1 @end
@fn SEEK_END() return 2 @end
@fn SEEK_DATA() return 3 @end
@fn SEEK_HOLE() return 4 @end

@fn S_IRWXU() return 448 @end
@fn S_IRUSR() return 256 @end
@fn S_IWUSR() return 128 @end
@fn S_IXUSR() return 64 @end
@fn S_IRWXG() return 56 @end
@fn S_IRGRP() return 32 @end
@fn S_IWGRP() return 16 @end
@fn S_IXGRP() return 8 @end
@fn S_IRWXO() return 7 @end
@fn S_IROTH() return 4 @end
@fn S_IWOTH() return 2 @end
@fn S_IXOTH() return 1 @end

@fn MODE_DEFAULT_FILE() return 420 @end  @! 0644
@fn MODE_DEFAULT_DIR() return 493 @end   @! 0755
@fn MODE_DEFAULT_EXEC() return 493 @end  @! 0755

@fn STDIN_FILENO() return 0 @end
@fn STDOUT_FILENO() return 1 @end
@fn STDERR_FILENO() return 2 @end

@! ----------------------------------------------------------------------------
@! 3. Sockets, Epoll, Clock, and Futex Constants
@! ----------------------------------------------------------------------------
@fn AF_UNSPEC() return 0 @end
@fn AF_UNIX() return 1 @end
@fn AF_INET() return 2 @end
@fn AF_INET6() return 10 @end

@fn SOCK_STREAM() return 1 @end
@fn SOCK_DGRAM() return 2 @end
@fn SOCK_RAW() return 3 @end
@fn SOCK_NONBLOCK() return 2048 @end
@fn SOCK_CLOEXEC() return 524288 @end

@fn IPPROTO_IP() return 0 @end
@fn IPPROTO_ICMP() return 1 @end
@fn IPPROTO_TCP() return 6 @end
@fn IPPROTO_UDP() return 17 @end

@fn SOL_SOCKET() return 1 @end
@fn SO_REUSEADDR() return 2 @end
@fn SO_TYPE() return 3 @end
@fn SO_ERROR() return 4 @end
@fn SO_BROADCAST() return 6 @end
@fn SO_SNDBUF() return 7 @end
@fn SO_RCVBUF() return 8 @end
@fn SO_KEEPALIVE() return 9 @end
@fn SO_REUSEPORT() return 15 @end

@fn SHUT_RD() return 0 @end
@fn SHUT_WR() return 1 @end
@fn SHUT_RDWR() return 2 @end

@fn EPOLL_CTL_ADD() return 1 @end
@fn EPOLL_CTL_DEL() return 2 @end
@fn EPOLL_CTL_MOD() return 3 @end
@fn EPOLLIN() return 1 @end
@fn EPOLLPRI() return 2 @end
@fn EPOLLOUT() return 4 @end
@fn EPOLLERR() return 8 @end
@fn EPOLLHUP() return 16 @end
@fn EPOLLRDHUP() return 8192 @end

@fn CLOCK_REALTIME() return 0 @end
@fn CLOCK_MONOTONIC() return 1 @end
@fn CLOCK_PROCESS_CPUTIME_ID() return 2 @end
@fn CLOCK_THREAD_CPUTIME_ID() return 3 @end
@fn CLOCK_MONOTONIC_RAW() return 4 @end
@fn CLOCK_BOOTTIME() return 7 @end

@fn FUTEX_WAIT() return 0 @end
@fn FUTEX_WAKE() return 1 @end
@fn FUTEX_PRIVATE_FLAG() return 128 @end
@fn FUTEX_WAIT_PRIVATE() return 128 @end
@fn FUTEX_WAKE_PRIVATE() return 129 @end

@! ----------------------------------------------------------------------------
@! 4. Linux Errno Constants
@! ----------------------------------------------------------------------------
@fn EPERM() return 1 @end
@fn ENOENT() return 2 @end
@fn ESRCH() return 3 @end
@fn EINTR() return 4 @end
@fn EIO() return 5 @end
@fn ENXIO() return 6 @end
@fn E2BIG() return 7 @end
@fn ENOEXEC() return 8 @end
@fn EBADF() return 9 @end
@fn ECHILD() return 10 @end
@fn EAGAIN() return 11 @end
@fn EWOULDBLOCK() return 11 @end
@fn ENOMEM() return 12 @end
@fn EACCES() return 13 @end
@fn EFAULT() return 14 @end
@fn ENOTBLK() return 15 @end
@fn EBUSY() return 16 @end
@fn EEXIST() return 17 @end
@fn EXDEV() return 18 @end
@fn ENODEV() return 19 @end
@fn ENOTDIR() return 20 @end
@fn EISDIR() return 21 @end
@fn EINVAL() return 22 @end
@fn ENFILE() return 23 @end
@fn EMFILE() return 24 @end
@fn ENOTTY() return 25 @end
@fn ETXTBSY() return 26 @end
@fn EFBIG() return 27 @end
@fn ENOSPC() return 28 @end
@fn ESPIPE() return 29 @end
@fn EROFS() return 30 @end
@fn EMLINK() return 31 @end
@fn EPIPE() return 32 @end
@fn EDOM() return 33 @end
@fn ERANGE() return 34 @end
@fn EDEADLK() return 35 @end
@fn ENAMETOOLONG() return 36 @end
@fn ENOLCK() return 37 @end
@fn ENOSYS() return 38 @end
@fn ENOTEMPTY() return 39 @end
@fn ELOOP() return 40 @end
@fn EADDRINUSE() return 98 @end
@fn EADDRNOTAVAIL() return 99 @end
@fn ENETDOWN() return 100 @end
@fn ENETUNREACH() return 101 @end
@fn ENETRESET() return 102 @end
@fn ECONNABORTED() return 103 @end
@fn ECONNRESET() return 104 @end
@fn ENOBUFS() return 105 @end
@fn EISCONN() return 106 @end
@fn ENOTCONN() return 107 @end
@fn ETIMEDOUT() return 110 @end
@fn ECONNREFUSED() return 111 @end
@fn EHOSTDOWN() return 112 @end
@fn EHOSTUNREACH() return 113 @end
@fn EINPROGRESS() return 115 @end

@! ----------------------------------------------------------------------------
@! 5. Error Translation & Formatting Functions
@! ----------------------------------------------------------------------------
@fn is_error(res)
  return res < 0 && res >= 0 - 4095
@end

@fn is_ok(res)
  return !is_error(res)
@end

@fn get_errno(res)
  @if is_error(res)
    return 0 - res
  @end
  return 0
@end

@fn errno_name(err)
  @if err == 1 return "EPERM" @end
  @if err == 2 return "ENOENT" @end
  @if err == 3 return "ESRCH" @end
  @if err == 4 return "EINTR" @end
  @if err == 5 return "EIO" @end
  @if err == 9 return "EBADF" @end
  @if err == 11 return "EAGAIN" @end
  @if err == 12 return "ENOMEM" @end
  @if err == 13 return "EACCES" @end
  @if err == 14 return "EFAULT" @end
  @if err == 17 return "EEXIST" @end
  @if err == 20 return "ENOTDIR" @end
  @if err == 21 return "EISDIR" @end
  @if err == 22 return "EINVAL" @end
  @if err == 23 return "ENFILE" @end
  @if err == 24 return "EMFILE" @end
  @if err == 28 return "ENOSPC" @end
  @if err == 29 return "ESPIPE" @end
  @if err == 30 return "EROFS" @end
  @if err == 32 return "EPIPE" @end
  @if err == 38 return "ENOSYS" @end
  @if err == 98 return "EADDRINUSE" @end
  @if err == 99 return "EADDRNOTAVAIL" @end
  @if err == 101 return "ENETUNREACH" @end
  @if err == 104 return "ECONNRESET" @end
  @if err == 110 return "ETIMEDOUT" @end
  @if err == 111 return "ECONNREFUSED" @end
  return "EUNKNOWN"
@end

@fn errno_strerror(err)
  @if err == 1 return "Operation not permitted" @end
  @if err == 2 return "No such file or directory" @end
  @if err == 3 return "No such process" @end
  @if err == 4 return "Interrupted system call" @end
  @if err == 5 return "Input/output error" @end
  @if err == 9 return "Bad file descriptor" @end
  @if err == 11 return "Resource temporarily unavailable" @end
  @if err == 12 return "Cannot allocate memory" @end
  @if err == 13 return "Permission denied" @end
  @if err == 14 return "Bad address" @end
  @if err == 17 return "File exists" @end
  @if err == 20 return "Not a directory" @end
  @if err == 21 return "Is a directory" @end
  @if err == 22 return "Invalid argument" @end
  @if err == 23 return "Too many open files in system" @end
  @if err == 24 return "Too many open files" @end
  @if err == 28 return "No space left on device" @end
  @if err == 29 return "Illegal seek" @end
  @if err == 30 return "Read-only file system" @end
  @if err == 32 return "Broken pipe" @end
  @if err == 38 return "Function not implemented" @end
  @if err == 98 return "Address already in use" @end
  @if err == 99 return "Cannot assign requested address" @end
  @if err == 101 return "Network is unreachable" @end
  @if err == 104 return "Connection reset by peer" @end
  @if err == 110 return "Connection timed out" @end
  @if err == 111 return "Connection refused" @end
  return "Unknown system error"
@end

@! ----------------------------------------------------------------------------
@! 6. Pure Maya Raw Syscall Wrappers (Uniform 7-Parameter Gateway)
@! ----------------------------------------------------------------------------

@! Memory Management Syscalls
@fn sys_mmap(addr, length, prot, flags, fd, offset)
  return syscall(9, addr, length, prot, flags, fd, offset)
@end

@fn sys_munmap(addr, length)
  return syscall(11, addr, length, 0, 0, 0, 0)
@end

@fn sys_mprotect(addr, length, prot)
  return syscall(10, addr, length, prot, 0, 0, 0)
@end

@fn sys_brk(addr)
  return syscall(12, addr, 0, 0, 0, 0, 0)
@end

@! File I/O Syscalls
@fn sys_read(fd, buf_ptr, count)
  return syscall(0, fd, buf_ptr, count, 0, 0, 0)
@end

@fn sys_write(fd, buf_ptr, count)
  return syscall(1, fd, buf_ptr, count, 0, 0, 0)
@end

@fn sys_open(filename_ptr, flags, mode)
  return syscall(2, filename_ptr, flags, mode, 0, 0, 0)
@end

@fn sys_close(fd)
  return syscall(3, fd, 0, 0, 0, 0, 0)
@end

@fn sys_stat(filename_ptr, statbuf_ptr)
  return syscall(4, filename_ptr, statbuf_ptr, 0, 0, 0, 0)
@end

@fn sys_fstat(fd, statbuf_ptr)
  return syscall(5, fd, statbuf_ptr, 0, 0, 0, 0)
@end

@fn sys_lstat(filename_ptr, statbuf_ptr)
  return syscall(6, filename_ptr, statbuf_ptr, 0, 0, 0, 0)
@end

@fn sys_poll(ufds_ptr, nfds, timeout_ms)
  return syscall(7, ufds_ptr, nfds, timeout_ms, 0, 0, 0)
@end

@fn sys_lseek(fd, offset, whence)
  return syscall(8, fd, offset, whence, 0, 0, 0)
@end

@fn sys_ioctl(fd, req, arg)
  return syscall(16, fd, req, arg, 0, 0, 0)
@end

@fn sys_io_uring_setup(entries, params_ptr)
  return syscall(425, entries, params_ptr, 0, 0, 0, 0)
@end

@fn sys_io_uring_enter(fd, to_submit, min_complete, flags, sig_ptr)
  return syscall(426, fd, to_submit, min_complete, flags, sig_ptr, 0)
@end

@fn sys_io_uring_register(fd, opcode, arg, nr_args)
  return syscall(427, fd, opcode, arg, nr_args, 0, 0)
@end

@fn sys_access(filename_ptr, mode)
  return syscall(21, filename_ptr, mode, 0, 0, 0, 0)
@end

@fn sys_pipe(pipefd_ptr)
  return syscall(22, pipefd_ptr, 0, 0, 0, 0, 0)
@end

@fn sys_pipe2(pipefd_ptr, flags)
  return syscall(293, pipefd_ptr, flags, 0, 0, 0, 0)
@end

@fn sys_dup(oldfd)
  return syscall(32, oldfd, 0, 0, 0, 0, 0)
@end

@fn sys_dup2(oldfd, newfd)
  return syscall(33, oldfd, newfd, 0, 0, 0, 0)
@end

@fn sys_fcntl(fd, cmd, arg)
  return syscall(72, fd, cmd, arg, 0, 0, 0)
@end

@fn sys_fsync(fd)
  return syscall(74, fd, 0, 0, 0, 0, 0)
@end

@fn sys_ftruncate(fd, length)
  return syscall(77, fd, length, 0, 0, 0, 0)
@end

@fn sys_openat(dirfd, filename_ptr, flags, mode)
  return syscall(257, dirfd, filename_ptr, flags, mode, 0, 0)
@end

@fn sys_newfstatat(dirfd, pathname_ptr, statbuf_ptr, flags)
  return syscall(262, dirfd, pathname_ptr, statbuf_ptr, flags, 0, 0)
@end

@! Filesystem Syscalls
@fn sys_getcwd(buf_ptr, size)
  return syscall(79, buf_ptr, size, 0, 0, 0, 0)
@end

@fn sys_chdir(path_ptr)
  return syscall(80, path_ptr, 0, 0, 0, 0, 0)
@end

@fn sys_rename(oldpath_ptr, newpath_ptr)
  return syscall(82, oldpath_ptr, newpath_ptr, 0, 0, 0, 0)
@end

@fn sys_mkdir(path_ptr, mode)
  return syscall(83, path_ptr, mode, 0, 0, 0, 0)
@end

@fn sys_rmdir(path_ptr)
  return syscall(84, path_ptr, 0, 0, 0, 0, 0)
@end

@fn sys_unlink(path_ptr)
  return syscall(87, path_ptr, 0, 0, 0, 0, 0)
@end

@fn sys_readlink(path_ptr, buf_ptr, bufsiz)
  return syscall(89, path_ptr, buf_ptr, bufsiz, 0, 0, 0)
@end

@fn sys_chmod(path_ptr, mode)
  return syscall(90, path_ptr, mode, 0, 0, 0, 0)
@end

@fn sys_getdents64(fd, dirp_ptr, count)
  return syscall(217, fd, dirp_ptr, count, 0, 0, 0)
@end

@! Process Lifecycle & Execution Syscalls
@fn sys_getpid()
  return syscall(39, 0, 0, 0, 0, 0, 0)
@end

@fn sys_getppid()
  return syscall(110, 0, 0, 0, 0, 0, 0)
@end

@fn sys_fork()
  return syscall(57, 0, 0, 0, 0, 0, 0)
@end

@fn sys_execve(filename_ptr, argv_ptr, envp_ptr)
  return syscall(59, filename_ptr, argv_ptr, envp_ptr, 0, 0, 0)
@end

@fn sys_exit(status)
  return syscall(60, status, 0, 0, 0, 0, 0)
@end

@fn sys_wait4(pid, status_ptr, options, rusage_ptr)
  return syscall(61, pid, status_ptr, options, rusage_ptr, 0, 0)
@end

@fn sys_kill(pid, sig)
  return syscall(62, pid, sig, 0, 0, 0, 0)
@end

@fn sys_exit_group(status)
  return syscall(231, status, 0, 0, 0, 0, 0)
@end

@! Networking & Socket Syscalls
@fn sys_socket(domain, sock_type, protocol)
  return syscall(41, domain, sock_type, protocol, 0, 0, 0)
@end

@fn sys_connect(sockfd, addr_ptr, addrlen)
  return syscall(42, sockfd, addr_ptr, addrlen, 0, 0, 0)
@end

@fn sys_accept(sockfd, addr_ptr, addrlen_ptr)
  return syscall(43, sockfd, addr_ptr, addrlen_ptr, 0, 0, 0)
@end

@fn sys_sendto(sockfd, buf_ptr, num_items, flags, dest_addr, addrlen)
  return syscall(44, sockfd, buf_ptr, num_items, flags, dest_addr, addrlen)
@end

@fn sys_recvfrom(sockfd, buf_ptr, num_items, flags, src_addr, addrlen)
  return syscall(45, sockfd, buf_ptr, num_items, flags, src_addr, addrlen)
@end

@fn sys_shutdown(sockfd, how)
  return syscall(48, sockfd, how, 0, 0, 0, 0)
@end

@fn sys_bind(sockfd, addr_ptr, addrlen)
  return syscall(49, sockfd, addr_ptr, addrlen, 0, 0, 0)
@end

@fn sys_listen(sockfd, backlog)
  return syscall(50, sockfd, backlog, 0, 0, 0, 0)
@end

@fn sys_setsockopt(sockfd, level, optname, optval_ptr, optlen)
  return syscall(54, sockfd, level, optname, optval_ptr, optlen, 0)
@end

@fn sys_getsockopt(sockfd, level, optname, optval_ptr, optlen_ptr)
  return syscall(55, sockfd, level, optname, optval_ptr, optlen_ptr, 0)
@end

@! Time, Futex, Epoll, Security, Async Syscalls
@fn sys_nanosleep(req_ptr, rem_ptr)
  return syscall(35, req_ptr, rem_ptr, 0, 0, 0, 0)
@end

@fn sys_clock_gettime(clk_id, tp_ptr)
  return syscall(228, clk_id, tp_ptr, 0, 0, 0, 0)
@end

@fn sys_futex(uaddr_ptr, futex_op, val, timeout_ptr, uaddr2_ptr, val3)
  return syscall(202, uaddr_ptr, futex_op, val, timeout_ptr, uaddr2_ptr, val3)
@end

@fn sys_epoll_create1(flags)
  return syscall(291, flags, 0, 0, 0, 0, 0)
@end

@fn sys_epoll_ctl(epfd, op, fd, event_ptr)
  return syscall(233, epfd, op, fd, event_ptr, 0, 0)
@end

@fn sys_epoll_wait(epfd, events_ptr, maxevents, timeout)
  return syscall(232, epfd, events_ptr, maxevents, timeout, 0, 0)
@end

@fn sys_getrandom(buf_ptr, buflen, flags)
  return syscall(318, buf_ptr, buflen, flags, 0, 0, 0)
@end

@fn sys_io_uring_setup(entries, params_ptr)
  return syscall(425, entries, params_ptr, 0, 0, 0, 0)
@end

@fn sys_io_uring_enter(fd, to_submit, min_complete, flags, sig_ptr, sigsz)
  return syscall(426, fd, to_submit, min_complete, flags, sig_ptr, sigsz)
@end

@fn sys_io_uring_register(fd, opcode, arg_ptr, nr_args)
  return syscall(427, fd, opcode, arg_ptr, nr_args, 0, 0)
@end
