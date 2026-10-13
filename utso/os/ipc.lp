@! ============================================================================
@! LIPI INTER-PROCESS COMMUNICATION (IPC) — universe/os/ipc.lp
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
