@! ============================================================================
@! MAYA UNIVERSE OS — INTER-PROCESS COMMUNICATION (IPC) SUBSYSTEM
@! 100% Written in Pure Maya Language — Microkernel & Userland Process Messaging
@! Features: Named Pipes (FIFO), Shared Memory, Unix Sockets, Message Queues, Mutex
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. NAMED PIPES & FIFOS
@! ----------------------------------------------------------------------------

@fn fifo_create(path, mode)
  println("  [IPC FIFO] Creating Named Pipe at: " + path)
  return {
    path: path,
    mode: mode,
    buffer: [],
    readers: 0,
    writers: 0,
    is_open: 1
  }
@end

@fn fifo_write(fifo, data_bytes)
  @if fifo.is_open == 0
    println("  [IPC FIFO Error] Broken pipe: cannot write to closed FIFO")
    return 0
  @end
  
  i = 0
  len = data_bytes.len()
  @while i < len
    fifo.buffer = fifo.buffer.push(data_bytes[i])
    i = i + 1
  @end
  
  println("  [IPC FIFO] Written " + data_bytes.len().to_str() + " bytes to " + fifo.path)
  return data_bytes.len()
@end

@fn fifo_read(fifo, max_bytes)
  read_data = []
  count = 0
  
  @while fifo.buffer.len() > 0 && count < max_bytes
    read_data = read_data.push(fifo.buffer[0])
    
    new_buf = []
    i = 1
    @while i < fifo.buffer.len()
      new_buf = new_buf.push(fifo.buffer[i])
      i = i + 1
    @end
    fifo.buffer = new_buf
    count = count + 1
  @end
  
  return read_data
@end

@fn fifo_close(fifo)
  fifo.is_open = 0
  fifo.buffer = []
  return fifo
@end

@! ----------------------------------------------------------------------------
@! 2. SHARED MEMORY SEGMENTS (MMAP / SHM)
@! ----------------------------------------------------------------------------

@fn shm_open(name, size, flags)
  println("  [IPC SHM] Allocating shared memory segment '" + name + "' (" + size.to_str() + " bytes)")
  
  initial_mem = []
  i = 0
  @while i < size
    initial_mem = initial_mem.push(0)
    i = i + 1
  @end
  
  return {
    name: name,
    size: size,
    fd: 100 + name.len(),
    memory: initial_mem,
    ref_count: 1
  }
@end

@fn shm_write_at(shm, offset, byte_val)
  @if offset >= 0 && offset < shm.size
    shm.memory = list_set(shm.memory, offset, byte_val)
    return 1
  @end
  return 0
@end

@fn shm_read_at(shm, offset)
  @if offset >= 0 && offset < shm.size
    return shm.memory[offset]
  @end
  return 0
@end

@fn shm_unlink(shm)
  println("  [IPC SHM] Unlinking shared memory: " + shm.name)
  shm.memory = []
  shm.ref_count = 0
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. UNIX DOMAIN SOCKETS (UDS)
@! ----------------------------------------------------------------------------

@fn uds_socket_new(sock_type)
  return {
    type: sock_type, @! "STREAM", "DGRAM"
    path: "",
    connected_peer: 0,
    recv_queue: [],
    bound: 0
  }
@end

@fn uds_bind(sock, path)
  sock.path = path
  sock.bound = 1
  println("  [IPC UDS] Bound Unix domain socket to: " + path)
  return sock
@end

@fn uds_send(sock, data_bytes)
  println("  [IPC UDS] Sent " + data_bytes.len().to_str() + " bytes over Unix socket " + sock.path)
  return data_bytes.len()
@end

@fn uds_recv(sock)
  @if sock.recv_queue.len() > 0
    msg = sock.recv_queue[0]
    new_q = []
    i = 1
    @while i < sock.recv_queue.len()
      new_q = new_q.push(sock.recv_queue[i])
      i = i + 1
    @end
    sock.recv_queue = new_q
    return msg
  @end
  return []
@end

@! ----------------------------------------------------------------------------
@! 4. POSIX MESSAGE QUEUES
@! ----------------------------------------------------------------------------

@fn mq_open(name, max_messages, max_msg_size)
  return {
    name: name,
    max_msgs: max_messages,
    max_size: max_msg_size,
    messages: []
  }
@end

@fn mq_send(mq, msg_bytes, priority)
  @if mq.messages.len() >= mq.max_msgs
    println("  [IPC MQ Error] Message queue full!")
    return 0
  @end
  
  mq.messages = mq.messages.push({ data: msg_bytes, prio: priority })
  return 1
@end

@fn mq_receive(mq)
  @if mq.messages.len() > 0
    msg = mq.messages[0]
    new_msgs = []
    i = 1
    @while i < mq.messages.len()
      new_msgs = new_msgs.push(mq.messages[i])
      i = i + 1
    @end
    mq.messages = new_msgs
    return msg.data
  @end
  return []
@end

@! ----------------------------------------------------------------------------
@! 5. COUNTING SEMAPHORES & MUTEX
@! ----------------------------------------------------------------------------

@fn sem_init(initial_value)
  return {
    value: initial_value,
    waiters: []
  }
@end

@fn sem_wait(sem)
  @if sem.value > 0
    sem.value = sem.value - 1
    return { sem: sem, acquired: 1 }
  @end
  
  @! Block thread
  sem.waiters = sem.waiters.push(1)
  return { sem: sem, acquired: 0, blocked: 1 }
@end

@fn sem_post(sem)
  @if sem.waiters.len() > 0
    new_waiters = []
    i = 1
    @while i < sem.waiters.len()
      new_waiters = new_waiters.push(sem.waiters[i])
      i = i + 1
    @end
    sem.waiters = new_waiters
    return sem
  @end
  
  sem.value = sem.value + 1
  return sem
@end
