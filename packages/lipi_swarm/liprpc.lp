// ==============================================================================
// 👑 LIPI SWARM: AUTONOMOUS P2P SWARM & LipRPC PROTOCOL (universe/swarm/liprpc.lp)
// ⚡ 100% Pure Native Lipi Language | 16-Byte Header | Work-Stealing Scheduler
// Zero External C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY: In decentralized peer-to-peer compute swarms, nodes must coordinate tasks
// with minimum latency and zero serialization overhead. LipRPC specifies a 16-byte
// fixed-length binary frame that fits squarely inside CPU L1 cache lines, enabling
// instant zero-copy decoding.
//
// In addition to synchronous RPC request/response flows, this engine embeds an
// autonomous Chase-Lev style Work-Stealing task scheduler. Underloaded worker nodes
// can dynamically steal pending tasks from overloaded victim peers, guaranteeing
// optimal cluster CPU utilization without any centralized orchestrator.
// ==============================================================================

include "universe/core/memory.lp"

// ── 1. Protocol Constants ─────────────────────────────────────────────────────
LIPRPC_MAGIC_0         = 76  // 'L' (0x4C)
LIPRPC_MAGIC_1         = 73  // 'I' (0x49)
LIPRPC_MAGIC_2         = 80  // 'P' (0x50)
LIPRPC_MAGIC_3         = 82  // 'R' (0x52)
LIPRPC_VERSION         = 1
LIPRPC_HDR_SIZE        = 16

// Message Types
LIPRPC_MSG_REQ         = 1 // Remote procedure call invocation
LIPRPC_MSG_RESP        = 2 // Procedure execution result
LIPRPC_MSG_STEAL_REQ   = 3 // Work-stealing task request from idle thief
LIPRPC_MSG_STEAL_RESP  = 4 // Work-stealing task grant from victim peer
LIPRPC_MSG_HEARTBEAT   = 5 // Peer liveness heartbeat
LIPRPC_MSG_ERROR       = 6 // Execution or protocol error

// Status Codes
LIPRPC_STATUS_OK       = 0
LIPRPC_STATUS_NOT_FOUND= 1
LIPRPC_STATUS_ERR      = 2
LIPRPC_STATUS_EMPTY    = 3

// ── 2. Binary Frame Header Serializer (16-Byte Compact Layout) ────────────────
// Layout:
//   Offset 0..3:  Magic 0x4C495052 ('LIPR')
//   Offset 4:     Protocol Version (1)
//   Offset 5:     Message Type (REQ, RESP, STEAL_REQ, STEAL_RESP...)
//   Offset 6..7:  Method ID (16-bit little-endian)
//   Offset 8..11: Sequence ID (32-bit little-endian)
//   Offset 12..15:Payload Length (32-bit little-endian)

fn liprpc_encode_header buf msg_type method_id seq_id payload_len
    // WHY: Direct byte manipulation eliminates memory allocation during RPC header framing
    mem_byte_write(buf, 0, LIPRPC_MAGIC_0)
    mem_byte_write(buf, 1, LIPRPC_MAGIC_1)
    mem_byte_write(buf, 2, LIPRPC_MAGIC_2)
    mem_byte_write(buf, 3, LIPRPC_MAGIC_3)

    mem_byte_write(buf, 4, LIPRPC_VERSION)
    mem_byte_write(buf, 5, msg_type)

    m0 = method_id % 256
    m1 = (method_id / 256) % 256
    mem_byte_write(buf, 6, m0)
    mem_byte_write(buf, 7, m1)

    s0 = seq_id % 256
    s1 = (seq_id / 256) % 256
    s2 = (seq_id / 65536) % 256
    s3 = (seq_id / 16777216) % 256
    mem_byte_write(buf, 8, s0)
    mem_byte_write(buf, 9, s1)
    mem_byte_write(buf, 10, s2)
    mem_byte_write(buf, 11, s3)

    l0 = payload_len % 256
    l1 = (payload_len / 256) % 256
    l2 = (payload_len / 65536) % 256
    l3 = (payload_len / 16777216) % 256
    mem_byte_write(buf, 12, l0)
    mem_byte_write(buf, 13, l1)
    mem_byte_write(buf, 14, l2)
    mem_byte_write(buf, 15, l3)
    return LIPRPC_HDR_SIZE

fn liprpc_decode_header buf buf_len out_meta
    if buf_len < LIPRPC_HDR_SIZE
        return 0
    b0 = mem_byte_read(buf, 0)
    b1 = mem_byte_read(buf, 1)
    b2 = mem_byte_read(buf, 2)
    b3 = mem_byte_read(buf, 3)
    if b0 != LIPRPC_MAGIC_0 or b1 != LIPRPC_MAGIC_1 or b2 != LIPRPC_MAGIC_2 or b3 != LIPRPC_MAGIC_3
        return 0
    ver = mem_byte_read(buf, 4)
    if ver != LIPRPC_VERSION
        return 0
    msg_type = mem_byte_read(buf, 5)

    m0 = mem_byte_read(buf, 6)
    m1 = mem_byte_read(buf, 7)
    method_id = m0 + (m1 * 256)

    s0 = mem_byte_read(buf, 8)
    s1 = mem_byte_read(buf, 9)
    s2 = mem_byte_read(buf, 10)
    s3 = mem_byte_read(buf, 11)
    seq_id = s0 + (s1 * 256) + (s2 * 65536) + (s3 * 16777216)

    l0 = mem_byte_read(buf, 12)
    l1 = mem_byte_read(buf, 13)
    l2 = mem_byte_read(buf, 14)
    l3 = mem_byte_read(buf, 15)
    payload_len = l0 + (l1 * 256) + (l2 * 65536) + (l3 * 16777216)

    push(out_meta, msg_type)
    push(out_meta, method_id)
    push(out_meta, seq_id)
    push(out_meta, payload_len)
    return 1

// ── 3. High-Speed Parameter Packing & Unpacking ───────────────────────────────
fn liprpc_pack_i32 buf offset val
    v0 = val % 256
    v1 = (val / 256) % 256
    v2 = (val / 65536) % 256
    v3 = (val / 16777216) % 256
    mem_byte_write(buf, offset, v0)
    mem_byte_write(buf, offset + 1, v1)
    mem_byte_write(buf, offset + 2, v2)
    mem_byte_write(buf, offset + 3, v3)
    return 4

fn liprpc_unpack_i32 buf offset
    v0 = mem_byte_read(buf, offset)
    v1 = mem_byte_read(buf, offset + 1)
    v2 = mem_byte_read(buf, offset + 2)
    v3 = mem_byte_read(buf, offset + 3)
    return v0 + (v1 * 256) + (v2 * 65536) + (v3 * 16777216)

fn liprpc_pack_str buf offset text
    tlen = len(text)
    mem_byte_write(buf, offset, tlen % 256)
    mem_byte_write(buf, offset + 1, (tlen / 256) % 256)
    i = 0
    while i < tlen
        mem_byte_write(buf, offset + 2 + i, ord(char_at(text, i)))
        i = i + 1
    return 2 + tlen

fn liprpc_unpack_str buf offset
    l0 = mem_byte_read(buf, offset)
    l1 = mem_byte_read(buf, offset + 1)
    tlen = l0 + (l1 * 256)
    res = ""
    i = 0
    while i < tlen
        ch = mem_byte_read(buf, offset + 2 + i)
        res = res + chr(ch)
        i = i + 1
    return res

// ── 4. Work-Stealing Task Queue (Chase-Lev Circular Deque) ────────────────────
// WHY: The owner thread pushes and pops locally from top/head in LIFO order
// for optimal CPU cache warmness. Underloaded thieves steal from bottom/tail
// in FIFO order, obtaining older, larger subproblems while minimizing contention.

fn liprpc_queue_new capacity
    q = list()
    buf = list()
    i = 0
    while i < capacity
        push(buf, 0)
        i = i + 1
    push(q, buf)      // 0: task storage buffer
    push(q, capacity) // 1: buffer capacity
    push(q, 0)        // 2: bottom (tail index for thief stealing)
    push(q, 0)        // 3: top (head index for local worker push/pop)
    return q

fn liprpc_queue_len q
    bottom = get(q, 2)
    top = get(q, 3)
    count = top - bottom
    if count < 0
        return 0
    return count

fn liprpc_queue_push q task
    buf = get(q, 0)
    cap = get(q, 1)
    top = get(q, 3)
    idx = top % cap
    list_set(buf, idx, task)
    list_set(q, 3, top + 1)
    return 1

fn liprpc_queue_pop q
    // Local worker pops from top (LIFO)
    bottom = get(q, 2)
    top = get(q, 3)
    if top <= bottom
        return 0 // Queue empty
    new_top = top - 1
    list_set(q, 3, new_top)
    buf = get(q, 0)
    cap = get(q, 1)
    idx = new_top % cap
    task = get(buf, idx)
    return task

fn liprpc_queue_steal q
    // Remote thief steals from bottom (FIFO)
    bottom = get(q, 2)
    top = get(q, 3)
    if bottom >= top
        return 0 // No task available to steal
    buf = get(q, 0)
    cap = get(q, 1)
    idx = bottom % cap
    task = get(buf, idx)
    list_set(q, 2, bottom + 1)
    return task

// ── 5. LipRPC Swarm Compute Node ──────────────────────────────────────────────
// Structure:
//   node[0]: node_name (string)
//   node[1]: method_ids (list of registered int IDs)
//   node[2]: method_handlers (list of handler keys)
//   node[3]: work_queue (Chase-Lev deque)
//   node[4]: stats (list: [calls_handled, tasks_executed, tasks_stolen])
//   node[5]: completed_results (list of results)

fn liprpc_node_new node_name queue_cap
    node = list()
    push(node, node_name)               // 0: node name
    push(node, list())                  // 1: method ids
    push(node, list())                  // 2: method handlers
    push(node, liprpc_queue_new(queue_cap)) // 3: local work queue
    stats = list()
    push(stats, 0)                      // calls handled
    push(stats, 0)                      // tasks executed
    push(stats, 0)                      // tasks stolen
    push(node, stats)                   // 4: stats
    push(node, list())                  // 5: completed results
    return node

fn liprpc_register_method node method_id handler_tag
    mids = get(node, 1)
    mhandlers = get(node, 2)
    push(mids, method_id)
    push(mhandlers, handler_tag)
    return 1

fn liprpc_submit_task node task_id task_type task_arg
    task = list()
    push(task, task_id)
    push(task, task_type)
    push(task, task_arg)
    q = get(node, 3)
    return liprpc_queue_push(q, task)

fn liprpc_execute_task node task
    task_id = get(task, 0)
    task_type = get(task, 1)
    task_arg = get(task, 2)

    // Compute task result based on task_type:
    // Type 1: Square arithmetic: arg * arg
    // Type 2: Step increment: arg * 2 + 1
    // Type 3: Hash transform: (arg ^ 0x5A5A) % 65536
    result = 0
    if task_type == 1
        result = task_arg * task_arg
    else
        if task_type == 2
            result = (task_arg * 2) + 1
        else
            result = (task_arg ^ 23130) % 65536

    stats = get(node, 4)
    list_set(stats, 1, get(stats, 1) + 1) // tasks_executed + 1
    res_entry = list()
    push(res_entry, task_id)
    push(res_entry, result)
    completed = get(node, 5)
    push(completed, res_entry)
    return result

fn liprpc_run_local_task node
    q = get(node, 3)
    task = liprpc_queue_pop(q)
    if task == 0
        return -1
    return liprpc_execute_task(node, task)

// ── 6. Remote Procedure Dispatcher (Server-side Frame Processor) ──────────────
// Ingests request frame, dispatches to handler or work-stealing engine,
// and formats 16-byte response frame.

fn liprpc_dispatch_frame node req_buf req_len resp_buf max_resp_len
    meta = list()
    valid = liprpc_decode_header(req_buf, req_len, meta)
    if valid == 0
        liprpc_encode_header(resp_buf, LIPRPC_MSG_ERROR, 0, 0, 0)
        return LIPRPC_HDR_SIZE

    msg_type = get(meta, 0)
    method_id = get(meta, 1)
    seq_id = get(meta, 2)
    payload_len = get(meta, 3)

    // ── Case A: Synchronous RPC Call ──
    if msg_type == LIPRPC_MSG_REQ
        // Lookup method
        mids = get(node, 1)
        mhandlers = get(node, 2)
        idx = -1
        i = 0
        while i < len(mids)
            if get(mids, i) == method_id
                idx = i
                i = len(mids)
            i = i + 1

        if idx == -1
            // Method not found error
            liprpc_encode_header(resp_buf, LIPRPC_MSG_ERROR, method_id, seq_id, 0)
            return LIPRPC_HDR_SIZE

        handler_tag = get(mhandlers, idx)
        stats = get(node, 4)
        list_set(stats, 0, get(stats, 0) + 1) // calls_handled + 1

        // Execute built-in procedures:
        // Handler 1: Sum two packed i32 integers
        // Handler 2: Reply prefix on string
        resp_payload_len = 0
        if handler_tag == 1
            a = liprpc_unpack_i32(req_buf, LIPRPC_HDR_SIZE)
            b = liprpc_unpack_i32(req_buf, LIPRPC_HDR_SIZE + 4)
            sum_res = a + b
            liprpc_pack_i32(resp_buf, LIPRPC_HDR_SIZE, sum_res)
            resp_payload_len = 4
        else
            if handler_tag == 2
                in_str = liprpc_unpack_str(req_buf, LIPRPC_HDR_SIZE)
                out_str = "REPLY:" + in_str
                resp_payload_len = liprpc_pack_str(resp_buf, LIPRPC_HDR_SIZE, out_str)

        liprpc_encode_header(resp_buf, LIPRPC_MSG_RESP, method_id, seq_id, resp_payload_len)
        return LIPRPC_HDR_SIZE + resp_payload_len

    // ── Case B: Work-Stealing Request ──
    if msg_type == LIPRPC_MSG_STEAL_REQ
        q = get(node, 3)
        stolen_task = liprpc_queue_steal(q)
        if stolen_task == 0
            // No tasks to steal: send EMPTY response
            liprpc_encode_header(resp_buf, LIPRPC_MSG_STEAL_RESP, 0, seq_id, 0)
            return LIPRPC_HDR_SIZE

        // Pack stolen task: [task_id(4), task_type(4), task_arg(4)] = 12 bytes
        t_id = get(stolen_task, 0)
        t_type = get(stolen_task, 1)
        t_arg = get(stolen_task, 2)
        liprpc_pack_i32(resp_buf, LIPRPC_HDR_SIZE, t_id)
        liprpc_pack_i32(resp_buf, LIPRPC_HDR_SIZE + 4, t_type)
        liprpc_pack_i32(resp_buf, LIPRPC_HDR_SIZE + 8, t_arg)
        liprpc_encode_header(resp_buf, LIPRPC_MSG_STEAL_RESP, 0, seq_id, 12)
        return LIPRPC_HDR_SIZE + 12

    // Unrecognized message type
    liprpc_encode_header(resp_buf, LIPRPC_MSG_ERROR, method_id, seq_id, 0)
    return LIPRPC_HDR_SIZE

// ── 7. Remote Work Stealing Invocator ─────────────────────────────────────────
// Initiates work steal over simulated wire frames from victim to thief node
fn liprpc_steal_from_victim thief_node victim_node wire_buf seq_id
    // Step 1: Thief prepares 16-byte LIPRPC_MSG_STEAL_REQ frame
    liprpc_encode_header(wire_buf, LIPRPC_MSG_STEAL_REQ, 0, seq_id, 0)

    // Step 2: Victim dispatches frame and produces response in wire_buf
    resp_buf = wire_buf + 128 // Offset response buffer safely
    resp_len = liprpc_dispatch_frame(victim_node, wire_buf, LIPRPC_HDR_SIZE, resp_buf, 128)

    // Step 3: Thief inspects response
    meta = list()
    valid = liprpc_decode_header(resp_buf, resp_len, meta)
    if valid == 0
        return 0

    msg_type = get(meta, 0)
    payload_len = get(meta, 3)
    if msg_type != LIPRPC_MSG_STEAL_RESP or payload_len < 12
        return 0 // No task obtained

    // Step 4: Unpack stolen task and execute locally on thief node
    t_id = liprpc_unpack_i32(resp_buf, LIPRPC_HDR_SIZE)
    t_type = liprpc_unpack_i32(resp_buf, LIPRPC_HDR_SIZE + 4)
    t_arg = liprpc_unpack_i32(resp_buf, LIPRPC_HDR_SIZE + 8)

    stolen_task = list()
    push(stolen_task, t_id)
    push(stolen_task, t_type)
    push(stolen_task, t_arg)

    // Execute task on thief node
    result = liprpc_execute_task(thief_node, stolen_task)

    // Increment thief stolen counter
    thief_stats = get(thief_node, 4)
    list_set(thief_stats, 2, get(thief_stats, 2) + 1)
    return result
