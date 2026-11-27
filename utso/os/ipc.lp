@! ============================================================================
@! @deprecated Simulation-only in-memory IPC model (FIFOs/SHM/sockets/semaphores in arrays).
@! WHY: Models IPC primitives inside a single process rather than using kernel syscalls.
@! For real kernel IPC use `utso/os/shm.lp`, `utso/os/wayland.lp`, `utso/os/pty.lp`, or `utso/core/sync.lp`.
@! ============================================================================
@! LIPI INTER-PROCESS COMMUNICATION (IPC) — utso/os/ipc.lp
@! 100% Written in Pure Lipi Language — Zero Foreign / Zero libc Dependencies
@! Features: Named Pipes (FIFO), Shared Memory, Unix Domain Sockets (Stream/Dgram),
@! Prioritized Message Queues, and Counting Semaphores / Mutexes
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Named Pipes (FIFO Ring Buffer)
@! ----------------------------------------------------------------------------

@fn ipc_fifo_create(name, capacity)
  buf = []
  i = 0
  @while i < capacity
    buf = buf.push(0)
    i = i + 1
  @end
  
  return {
    name: name,
    capacity: capacity,
    buffer: buf,
    read_ptr: 0,
    write_ptr: 0,
    count: 0,
    readers_count: 1,
    writers_count: 1,
    is_open: 1
  }
@end

@fn ipc_fifo_write(fifo, data)
  @if fifo.is_open == 0 return 0 - 32 @! EPIPE (Broken pipe)
  
  data_len = data.len()
  avail = fifo.capacity - fifo.count
  @if avail <= 0 return 0 @! Buffer full
  
  write_bytes = data_len
  @if write_bytes > avail
    write_bytes = avail
  @end
  
  i = 0
  @while i < write_bytes
    pos = (fifo.write_ptr + i) % fifo.capacity
    fifo.buffer[pos] = data[i]
    i = i + 1
  @end
  
  fifo.write_ptr = (fifo.write_ptr + write_bytes) % fifo.capacity
  fifo.count = fifo.count + write_bytes
  return write_bytes
@end

@fn ipc_fifo_read(fifo, max_bytes)
  @if fifo.count <= 0
    @if fifo.writers_count == 0 return [] @! EOF
    return [] @! Non-blocking empty
  @end
  
  read_bytes = max_bytes
  @if read_bytes > fifo.count
    read_bytes = fifo.count
  @end
  
  res = []
  i = 0
  @while i < read_bytes
    pos = (fifo.read_ptr + i) % fifo.capacity
    res = res.push(fifo.buffer[pos])
    i = i + 1
  @end
  
  fifo.read_ptr = (fifo.read_ptr + read_bytes) % fifo.capacity
  fifo.count = fifo.count - read_bytes
  return res
@end

@fn ipc_fifo_close(fifo)
  fifo.is_open = 0
  fifo.readers_count = 0
  fifo.writers_count = 0
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. Shared Memory Segments
@! ----------------------------------------------------------------------------

@fn ipc_shm_create(name, size, permissions)
  buf = []
  i = 0
  @while i < size
    buf = buf.push(0)
    i = i + 1
  @end
  
  return {
    name: name,
    size: size,
    data: buf,
    ref_count: 1,
    permissions: permissions
  }
@end

@fn ipc_shm_write_at(shm, offset, data)
  @if offset < 0 || offset >= shm.size return 0 - 22 @! EINVAL
  
  data_len = data.len()
  avail = shm.size - offset
  write_len = data_len
  @if write_len > avail
    write_len = avail
  @end
  
  i = 0
  @while i < write_len
    shm.data[offset + i] = data[i]
    i = i + 1
  @end
  
  return write_len
@end

@fn ipc_shm_read_at(shm, offset, count)
  @if offset < 0 || offset >= shm.size return []
  
  avail = shm.size - offset
  read_len = count
  @if read_len > avail
    read_len = avail
  @end
  
  res = []
  i = 0
  @while i < read_len
    res = res.push(shm.data[offset + i])
    i = i + 1
  @end
  
  return res
@end

@! ----------------------------------------------------------------------------
@! 3. Unix Domain Sockets (Stream & Datagram)
@! ----------------------------------------------------------------------------

@fn ipc_uds_socket(sock_type)
  return {
    sock_type: sock_type, @! 1 = SOCK_STREAM, 2 = SOCK_DGRAM
    state: 0,             @! 0=UNBOUND, 1=BOUND, 2=LISTENING, 3=CONNECTED, 4=CLOSED
    bind_path: "",
    peer_sock: 0,
    rx_buffer: [],
    backlog: 5
  }
@end

@fn ipc_uds_bind(sock, path)
  sock.bind_path = path
  sock.state = 1 @! BOUND
  return 0
@end

@fn ipc_uds_listen(sock, backlog)
  @if sock.state != 1 return 0 - 22 @! Must be BOUND
  sock.backlog = backlog
  sock.state = 2 @! LISTENING
  return 0
@end

@fn ipc_uds_connect(client_sock, server_sock)
  @if server_sock.state != 2 return 0 - 111 @! ECONNREFUSED
  
  client_sock.peer_sock = server_sock
  server_sock.peer_sock = client_sock
  client_sock.state = 3 @! CONNECTED
  server_sock.state = 3 @! CONNECTED
  return 0
@end

@fn ipc_uds_send(sock, data)
  @if sock.state != 3 return 0 - 107 @! ENOTCONN
  @if sock.peer_sock == 0 return 0 - 107 @! ENOTCONN
  
  peer = sock.peer_sock
  i = 0
  d_len = data.len()
  @while i < d_len
    peer.rx_buffer = peer.rx_buffer.push(data[i])
    i = i + 1
  @end
  
  return d_len
@end

@fn ipc_uds_recv(sock, max_bytes)
  @if sock.rx_buffer.len() == 0 return []
  
  read_len = max_bytes
  @if read_len > sock.rx_buffer.len()
    read_len = sock.rx_buffer.len()
  @end
  
  res = []
  i = 0
  @while i < read_len
    res = res.push(sock.rx_buffer[i])
    i = i + 1
  @end
  
  @! Truncate rx_buffer
  rem_buf = []
  j = read_len
  @while j < sock.rx_buffer.len()
    rem_buf = rem_buf.push(sock.rx_buffer[j])
    j = j + 1
  @end
  sock.rx_buffer = rem_buf
  
  return res
@end

@fn ipc_uds_close(sock)
  sock.state = 4 @! CLOSED
  sock.peer_sock = 0
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. POSIX Priority Message Queues
@! ----------------------------------------------------------------------------

@fn ipc_mq_open(name, max_msgs, max_msg_size)
  return {
    name: name,
    max_msgs: max_msgs,
    max_msg_size: max_msg_size,
    messages: []
  }
@end

@fn ipc_mq_send(mq, data, priority, timestamp)
  @if mq.messages.len() >= mq.max_msgs return 0 - 11 @! EAGAIN (Queue full)
  @if data.len() > mq.max_msg_size return 0 - 90 @! EMSGSIZE
  
  new_msg = {
    priority: priority,
    data: data,
    timestamp: timestamp
  }
  
  @! Insertion sort: descending priority (higher priority number dequeued first)
  inserted = 0
  new_list = []
  i = 0
  n = mq.messages.len()
  @while i < n
    cur = mq.messages[i]
    @if inserted == 0 && priority > cur.priority
      new_list = new_list.push(new_msg)
      inserted = 1
    @end
    new_list = new_list.push(cur)
    i = i + 1
  @end
  
  @if inserted == 0
    new_list = new_list.push(new_msg)
  @end
  
  mq.messages = new_list
  return 0
@end

@fn ipc_mq_receive(mq)
  @if mq.messages.len() == 0 return 0 @! Empty queue
  
  msg = mq.messages[0]
  
  @! Pop front
  new_list = []
  i = 1
  n = mq.messages.len()
  @while i < n
    new_list = new_list.push(mq.messages[i])
    i = i + 1
  @end
  mq.messages = new_list
  
  return msg
@end

@! ----------------------------------------------------------------------------
@! 5. Counting Semaphores & Mutexes
@! ----------------------------------------------------------------------------

@fn ipc_sem_init(initial_val, max_val)
  return {
    value: initial_val,
    max_value: max_val,
    waiters_count: 0
  }
@end

@fn ipc_sem_wait(sem)
  @if sem.value > 0
    sem.value = sem.value - 1
    return { acquired: 1, blocked: 0 }
  @end
  sem.waiters_count = sem.waiters_count + 1
  return { acquired: 0, blocked: 1 }
@end

@fn ipc_sem_post(sem)
  @if sem.waiters_count > 0
    sem.waiters_count = sem.waiters_count - 1
    return 1
  @end
  @if sem.value < sem.max_value
    sem.value = sem.value + 1
  @end
  return 1
@end

@fn ipc_mutex_init()
  return {
    locked: 0,
    owner_task_id: 0
  }
@end

@fn ipc_mutex_lock(mutex, task_id)
  @if mutex.locked == 0
    mutex.locked = 1
    mutex.owner_task_id = task_id
    return { acquired: 1, blocked: 0 }
  @end
  return { acquired: 0, blocked: 1 }
@end

@fn ipc_mutex_unlock(mutex, task_id)
  @if mutex.locked == 1 && mutex.owner_task_id == task_id
    mutex.locked = 0
    mutex.owner_task_id = 0
    return 1
  @end
  return 0 - 1 @! EPERM (Not lock owner)
@end

@! ----------------------------------------------------------------------------
@! 6. Native Linux Kernel IPC — Real OS Pipes, AF_UNIX Sockets & memfd SHM
@! 0% C, 0% libc — Direct Linux x86_64 Syscalls + ERMS bytes_to_str
@! ----------------------------------------------------------------------------

@fn _ipc_raw_ptr(x) return x @end

@fn _ipc_write_all(fd, data)
  s = str(data)
  s_ptr = _ipc_raw_ptr(s)
  total = str_len(s)
  @if total == 0
    return 0
  @end
  sent = 0
  @while sent < total
    n = syscall(1, fd, s_ptr + sent, total - sent, 0, 0, 0)
    @if n == (0 - 4)
      @! EINTR: retry interrupted syscall
      continue
    @end
    @if n <= 0
      @if sent > 0
        return sent
      @end
      return n
    @end
    sent = sent + n
  @end
  return sent
@end

@fn _ipc_read_str(fd, max_bytes)
  sz = max_bytes
  @if sz <= 0
    sz = 4096
  @end
  buf = alloc(sz)
  @if buf <= 0
    return ""
  @end
  n = syscall(0, fd, buf, sz, 0, 0, 0)
  @while n == (0 - 4)
    n = syscall(0, fd, buf, sz, 0, 0, 0)
  @end
  res = ""
  @if n > 0
    res = bytes_to_str(buf, n)
  @end
  free(buf)
  return res
@end

@fn _ipc_pack_sockaddr_un(path)
  @! Linux struct sockaddr_un: 2-byte AF_UNIX (1) + up to 107-byte path + NUL (110 bytes)
  sa = alloc(112)
  i = 0
  @while i < 112
    mem_byte_write(sa, i, 0)
    i = i + 1
  @end
  mem_byte_write(sa, 0, 1)
  mem_byte_write(sa, 1, 0)
  p = str(path)
  plen = str_len(p)
  @if plen > 107
    plen = 107
  @end
  j = 0
  @while j < plen
    mem_byte_write(sa, 2 + j, mem_byte_read(p, j))
    j = j + 1
  @end
  mem_byte_write(sa, 2 + plen, 0)
  return sa
@end

@struct IpcPipe
  r_fd: i64
  w_fd: i64
  open: i64
  err: i64
@end

@struct IpcUnixPair
  fd0: i64
  fd1: i64
  open: i64
  err: i64
@end

@struct IpcKernelShm
  shm_fd: i64
  shm_ptr: i64
  shm_size: i64
  shm_err: i64
@end

@! Real Kernel Pipe via SYS_pipe2 (293)
@fn ipc_pipe_open_flags(flags)
  fds = alloc(16)
  mem_word_write(fds, 0, 0)
  rc = syscall(293, fds, flags, 0, 0, 0, 0)
  @if rc < 0
    free(fds)
    return IpcPipe(0 - 1, 0 - 1, 0, rc)
  @end
  packed = mem_word_read(fds, 0)
  r_fd = packed & 4294967295
  w_fd = (packed >> 32) & 4294967295
  free(fds)
  return IpcPipe(r_fd, w_fd, 1, 0)
@end

@fn ipc_pipe_open()
  return ipc_pipe_open_flags(0)
@end

@fn ipc_pipe_write(p: IpcPipe, data)
  @if p.w_fd < 0
    return 0 - 9
  @end
  return _ipc_write_all(p.w_fd, data)
@end

@fn ipc_pipe_read(p: IpcPipe, max_bytes)
  @if p.r_fd < 0
    return ""
  @end
  return _ipc_read_str(p.r_fd, max_bytes)
@end

@fn ipc_pipe_close_read(p: IpcPipe)
  @if p.r_fd >= 0
    syscall(3, p.r_fd, 0, 0, 0, 0, 0)
    p.r_fd = 0 - 1
  @end
  @if p.r_fd < 0 && p.w_fd < 0
    p.open = 0
  @end
  return 0
@end

@fn ipc_pipe_close_write(p: IpcPipe)
  @if p.w_fd >= 0
    syscall(3, p.w_fd, 0, 0, 0, 0, 0)
    p.w_fd = 0 - 1
  @end
  @if p.r_fd < 0 && p.w_fd < 0
    p.open = 0
  @end
  return 0
@end

@fn ipc_pipe_close(p: IpcPipe)
  ipc_pipe_close_read(p)
  ipc_pipe_close_write(p)
  return 0
@end

@! Real Kernel AF_UNIX SocketPair via SYS_socketpair (53) & Stream Server/Client
@fn ipc_unix_pair()
  fds = alloc(16)
  mem_word_write(fds, 0, 0)
  @! AF_UNIX=1, SOCK_STREAM=1, protocol=0
  rc = syscall(53, 1, 1, 0, fds, 0, 0)
  @if rc < 0
    free(fds)
    return IpcUnixPair(0 - 1, 0 - 1, 0, rc)
  @end
  packed = mem_word_read(fds, 0)
  fd0 = packed & 4294967295
  fd1 = (packed >> 32) & 4294967295
  free(fds)
  return IpcUnixPair(fd0, fd1, 1, 0)
@end

@fn ipc_unix_listen(path, backlog)
  syscall(87, path, 0, 0, 0, 0, 0) @! SYS_unlink stale socket file
  fd = syscall(41, 1, 1, 0, 0, 0, 0) @! SYS_socket(AF_UNIX, SOCK_STREAM, 0)
  @if fd < 0
    return fd
  @end
  sa = _ipc_pack_sockaddr_un(path)
  plen = str_len(str(path))
  @if plen > 107
    plen = 107
  @end
  addr_len = 2 + plen + 1
  rc = syscall(49, fd, sa, addr_len, 0, 0, 0) @! SYS_bind
  free(sa)
  @if rc < 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return rc
  @end
  bl = backlog
  @if bl <= 0
    bl = 16
  @end
  lrc = syscall(50, fd, bl, 0, 0, 0, 0) @! SYS_listen
  @if lrc < 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return lrc
  @end
  return fd
@end

@fn ipc_unix_accept(srv_fd)
  return syscall(43, srv_fd, 0, 0, 0, 0, 0) @! SYS_accept
@end

@fn ipc_unix_connect(path)
  fd = syscall(41, 1, 1, 0, 0, 0, 0)
  @if fd < 0
    return fd
  @end
  sa = _ipc_pack_sockaddr_un(path)
  plen = str_len(str(path))
  @if plen > 107
    plen = 107
  @end
  addr_len = 2 + plen + 1
  rc = syscall(42, fd, sa, addr_len, 0, 0, 0) @! SYS_connect
  free(sa)
  @if rc < 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return rc
  @end
  return fd
@end

@fn ipc_unix_send(fd, data)
  return _ipc_write_all(fd, data)
@end

@fn ipc_unix_recv(fd, max_bytes)
  return _ipc_read_str(fd, max_bytes)
@end

@fn ipc_unix_close(fd)
  @if fd >= 0
    return syscall(3, fd, 0, 0, 0, 0, 0)
  @end
  return 0
@end

@! Real Kernel Shared Memory via SYS_memfd_create (319) + SYS_ftruncate (77) + MAP_SHARED (1)
@fn ipc_shm_kernel_create(name, size)
  sz = size
  @if sz < 4096
    sz = 4096
  @end
  fd = syscall(319, name, 0, 0, 0, 0, 0)
  @if fd < 0
    return IpcKernelShm(0 - 1, 0, 0, fd)
  @end
  trc = syscall(77, fd, sz, 0, 0, 0, 0)
  @if trc < 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return IpcKernelShm(0 - 1, 0, 0, trc)
  @end
  @! PROT_READ|PROT_WRITE (3), MAP_SHARED (1)
  ptr = syscall(9, 0, sz, 3, 1, fd, 0)
  @if ptr <= 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return IpcKernelShm(0 - 1, 0, 0, ptr)
  @end
  return IpcKernelShm(fd, ptr, sz, 0)
@end

@fn ipc_shm_kernel_write(shm: IpcKernelShm, offset, data)
  @if shm.shm_ptr <= 0 || offset < 0 || offset >= shm.shm_size
    return 0 - 22
  @end
  s = str(data)
  n = str_len(s)
  avail = shm.shm_size - offset
  @if n > avail
    n = avail
  @end
  i = 0
  @while i < n
    mem_byte_write(shm.shm_ptr, offset + i, mem_byte_read(s, i))
    i = i + 1
  @end
  return n
@end

@fn ipc_shm_kernel_read(shm: IpcKernelShm, offset, count)
  @if shm.shm_ptr <= 0 || offset < 0 || offset >= shm.shm_size || count <= 0
    return ""
  @end
  avail = shm.shm_size - offset
  n = count
  @if n > avail
    n = avail
  @end
  return bytes_to_str(shm.shm_ptr + offset, n)
@end

@fn ipc_shm_kernel_close(shm: IpcKernelShm)
  @if shm.shm_ptr > 0 && shm.shm_size > 0
    syscall(11, shm.shm_ptr, shm.shm_size, 0, 0, 0, 0)
    shm.shm_ptr = 0
  @end
  @if shm.shm_fd >= 0
    syscall(3, shm.shm_fd, 0, 0, 0, 0, 0)
    shm.shm_fd = 0 - 1
  @end
  return 0
@end
