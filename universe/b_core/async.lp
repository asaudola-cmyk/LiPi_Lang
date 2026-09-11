@! ============================================================================
@! UNIVERSE B CORE: ASYNCHRONOUS EVENT LOOP (epoll)
@! ============================================================================

@fn async_epoll_create()
  @! sys_epoll_create1 = 291
  return sys_syscall(291, 0, 0, 0, 0, 0, 0)
@end

@fn async_epoll_add(epfd, fd)
  @! struct epoll_event { uint32_t events; epoll_data_t data; } (12 bytes, packed as 16)
  event_ptr = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  
  @! EPOLLIN = 1
  sys_poke(event_ptr, 1) @! events
  sys_poke(event_ptr + 8, fd) @! data.fd
  
  @! sys_epoll_ctl = 233, EPOLL_CTL_ADD = 1
  return sys_syscall(233, epfd, 1, fd, event_ptr, 0, 0)
@end

@fn async_epoll_wait(epfd, events_buf, maxevents, timeout)
  @! sys_epoll_wait = 232
  return sys_syscall(232, epfd, events_buf, maxevents, timeout, 0, 0)
@end

@fn async_make_nonblocking(fd)
  @! fcntl(fd, F_GETFL, 0) (syscall 72)
  flags = sys_syscall(72, fd, 3, 0, 0, 0, 0)
  
  @! O_NONBLOCK = 2048
  new_flags = flags | 2048
  
  @! fcntl(fd, F_SETFL, new_flags)
  return sys_syscall(72, fd, 4, new_flags, 0, 0, 0)
@end
