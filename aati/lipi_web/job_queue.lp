// ==============================================================================
// 👑 LIPI SOVEREIGN DISTRIBUTED BACKGROUND JOB QUEUE & CRON WORKER
// Module: aati/lipi_web/job_queue.lp
// Milestone: Sovereign Full-Stack Framework v2 (Replacing BullMQ, Celery, and Sidekiq)
// 100% Pure LiPi Implementation — Crash-Proof Binary "LJQW" CRC-32 WAL + Spinlock
// ==============================================================================
//
// WHY THIS MODULE:
// Instead of requiring an external Redis server (BullMQ/Sidekiq/Celery) to survive
// process restarts or crashes, job_queue embeds an atomic hardware-spinlock-guarded,
// IEEE 802.3 CRC-32 checksummed binary Write-Ahead Log ("LJQW" / "JQWR") directly
// over kernel SYS_write + SYS_fsync, automatically recovering torn writes and in-flight
// RUNNING jobs on restart.

include "utso/core/memory.lp"

// ── 1. Job Status & WAL Operation Constants ───────────────────────────────────
JOB_STATUS_PENDING      = 1
JOB_STATUS_RUNNING      = 2
JOB_STATUS_COMPLETED    = 3
JOB_STATUS_FAILED       = 4
JOB_STATUS_DEAD         = 5 // Dead-Letter Queue

JQ_SYS_READ             = 0
JQ_SYS_WRITE            = 1
JQ_SYS_OPEN             = 2
JQ_SYS_CLOSE            = 3
JQ_SYS_LSEEK            = 8
JQ_SYS_FSYNC            = 74
JQ_SYS_FTRUNCATE        = 77
JQ_SYS_RENAME           = 82

JQ_OP_ENQUEUE           = 1
JQ_OP_START_RUNNING     = 2
JQ_OP_COMPLETE          = 3
JQ_OP_FAIL_RETRY        = 4
JQ_OP_DEAD_LETTER       = 5
JQ_OP_REGISTER_CRON     = 6
JQ_OP_CRON_LAST_RUN     = 7
JQ_OP_RECOVER_PENDING   = 8

// ── 2. Hardware-Aligned Models ────────────────────────────────────────────────

struct BackgroundJob
    bj_tag
    bj_id
    bj_task_name
    bj_payload
    bj_status
    bj_run_at
    bj_retry_count
    bj_max_retries

struct CronSchedule
    cs_tag
    cs_task_name
    cs_interval_secs
    cs_last_run
    cs_is_active

struct JobQueueEngine
    jqe_tag
    jqe_jobs
    jqe_cron_tasks
    jqe_total_processed
    jqe_total_failed
    jqe_dead_letter_count
    jqe_wal_fd
    jqe_wal_path
    jqe_crc_table
    jqe_is_replaying
    jqe_lock_ptr

// ── 3. Internal CRC-32 & Kernel Journal Helpers ───────────────────────────────

fn _jq_crc32_init
    tbl = sys_alloc(2048)
    i = 0
    while i < 256
        c = i
        j = 0
        while j < 8
            if (c & 1) != 0
                c = (((c / 2) & 2147483647) ^ 3988292384) & 4294967295
            else
                c = (c / 2) & 2147483647
            end
            j = j + 1
        end
        mem_write_idx(tbl, i, c)
        i = i + 1
    end
    return tbl

fn _jq_crc32_compute crc_tbl buf start_off total_end
    crc = 4294967295
    i = start_off
    while i < total_end
        b = mem_byte_read(buf, i) & 255
        idx = (crc ^ b) & 255
        crc = ((crc / 256) & 16777215) ^ mem_read_idx(crc_tbl, idx)
        crc = crc & 4294967295
        i = i + 1
    end
    return (crc ^ 4294967295) & 4294967295

fn _jq_write_exact fd buf n
    sent = 0
    while sent < n
        w = syscall(JQ_SYS_WRITE, fd, buf + sent, n - sent, 0, 0, 0)
        if w <= 0 return -1 end
        sent = sent + w
    end
    return sent

fn _jq_read_str_from_mem ptr slen
    out = ""
    i = 0
    while i < slen
        out = out + chr(mem_byte_read(ptr, i) & 255)
        i = i + 1
    end
    return out

fn _jq_write_str_to_mem ptr s slen
    i = 0
    while i < slen
        mem_byte_write(ptr, i, str_char_at(s, i) & 255)
        i = i + 1
    end
    return slen

fn _jq_append_wal engine op_code job_id ts_val payload_buf payload_len
    if engine == 0 return 0 end
    if engine.jqe_wal_fd < 0 or engine.jqe_is_replaying == 1
        return 0
    end
    tot = 32 + payload_len
    rec = sys_alloc(tot)
    // Magic "JQWR" (74, 81, 87, 82)
    mem_byte_write(rec, 0, 74)
    mem_byte_write(rec, 1, 81)
    mem_byte_write(rec, 2, 87)
    mem_byte_write(rec, 3, 82)
    mem_write_u32(rec, 8, op_code)
    mem_write_u32(rec, 12, payload_len)
    mem_write(rec, 16, job_id)
    mem_write(rec, 24, ts_val)
    if payload_len > 0 and payload_buf > 0
        mem_copy(rec + 32, payload_buf, payload_len)
    end
    crc = _jq_crc32_compute(engine.jqe_crc_table, rec, 8, tot)
    mem_write_u32(rec, 4, crc)
    _jq_write_exact(engine.jqe_wal_fd, rec, tot)
    syscall(JQ_SYS_FSYNC, engine.jqe_wal_fd, 0, 0, 0, 0, 0)
    sys_free(rec)
    return 1

fn _jq_log_enqueue engine job
    if engine.jqe_wal_fd < 0 or engine.jqe_is_replaying == 1
        return 0
    end
    nlen = str_len(job.bj_task_name)
    plen = str_len(job.bj_payload)
    tot_p = 24 + nlen + plen
    pb = sys_alloc(tot_p)
    mem_write(pb, 0, job.bj_retry_count)
    mem_write(pb, 8, job.bj_max_retries)
    mem_write_u32(pb, 16, nlen)
    mem_write_u32(pb, 20, plen)
    if nlen > 0 _jq_write_str_to_mem(pb + 24, job.bj_task_name, nlen) end
    if plen > 0 _jq_write_str_to_mem(pb + 24 + nlen, job.bj_payload, plen) end
    _jq_append_wal(engine, JQ_OP_ENQUEUE, job.bj_id, job.bj_run_at, pb, tot_p)
    sys_free(pb)
    return 1

fn _jq_log_cron_reg engine cron
    if engine.jqe_wal_fd < 0 or engine.jqe_is_replaying == 1
        return 0
    end
    nlen = str_len(cron.cs_task_name)
    tot_p = 12 + nlen
    pb = sys_alloc(tot_p)
    mem_write(pb, 0, cron.cs_interval_secs)
    mem_write_u32(pb, 8, nlen)
    if nlen > 0 _jq_write_str_to_mem(pb + 12, cron.cs_task_name, nlen) end
    _jq_append_wal(engine, JQ_OP_REGISTER_CRON, 0, cron.cs_last_run, pb, tot_p)
    sys_free(pb)
    return 1

// ── 4. Constructor Primitives ─────────────────────────────────────────────────

fn background_job_new id task_name payload run_at max_retries
    job = BackgroundJob()
    job.bj_tag = 1
    job.bj_id = id
    job.bj_task_name = task_name
    job.bj_payload = payload
    job.bj_status = JOB_STATUS_PENDING
    job.bj_run_at = run_at
    job.bj_retry_count = 0
    job.bj_max_retries = max_retries
    return job

fn cron_schedule_new task_name interval_secs
    cs = CronSchedule()
    cs.cs_tag = 1
    cs.cs_task_name = task_name
    cs.cs_interval_secs = interval_secs
    cs.cs_last_run = 0
    cs.cs_is_active = 1
    return cs

fn job_queue_engine_new
    jqe = JobQueueEngine()
    jqe.jqe_tag = 1
    jqe.jqe_jobs = list()
    jqe.jqe_cron_tasks = list()
    jqe.jqe_total_processed = 0
    jqe.jqe_total_failed = 0
    jqe.jqe_dead_letter_count = 0
    jqe.jqe_wal_fd = 0 - 1
    jqe.jqe_wal_path = ""
    jqe.jqe_crc_table = _jq_crc32_init()
    jqe.jqe_is_replaying = 0
    lck = malloc(16)
    mem_zero(lck, 16)
    jqe.jqe_lock_ptr = lck
    return jqe

// ── 5. Unlocked Internal State Mutations (Deadlock-Free Single-Lock Design) ───

fn _jq_find_job_unlocked engine id
    jobs = engine.jqe_jobs
    jcount = len(jobs)
    i = 0
    while i < jcount
        j = get(jobs, i)
        if j.bj_id == id return j end
        i = i + 1
    end
    return 0

fn _jq_enqueue_unlocked engine id task_name payload run_at max_retries
    job = background_job_new(id, task_name, payload, run_at, max_retries)
    jobs = engine.jqe_jobs
    push(jobs, job)
    _jq_log_enqueue(engine, job)
    return job

fn _jq_poll_ready_unlocked engine current_time
    jobs = engine.jqe_jobs
    jcount = len(jobs)
    i = 0
    while i < jcount
        j = get(jobs, i)
        if j.bj_status == JOB_STATUS_PENDING
            if current_time >= j.bj_run_at
                j.bj_status = JOB_STATUS_RUNNING
                _jq_append_wal(engine, JQ_OP_START_RUNNING, j.bj_id, current_time, 0, 0)
                return j
            end
        end
        i = i + 1
    end
    return 0

fn _jq_complete_unlocked engine job_id
    job = _jq_find_job_unlocked(engine, job_id)
    if job == 0 return 0 end
    job.bj_status = JOB_STATUS_COMPLETED
    engine.jqe_total_processed = engine.jqe_total_processed + 1
    _jq_append_wal(engine, JQ_OP_COMPLETE, job_id, 0, 0, 0)
    return 1

fn _jq_fail_retry_unlocked engine job_id current_time backoff_secs
    job = _jq_find_job_unlocked(engine, job_id)
    if job == 0 return 0 end
    job.bj_retry_count = job.bj_retry_count + 1
    engine.jqe_total_failed = engine.jqe_total_failed + 1
    if job.bj_retry_count >= job.bj_max_retries
        job.bj_status = JOB_STATUS_DEAD
        engine.jqe_dead_letter_count = engine.jqe_dead_letter_count + 1
        pb = sys_alloc(8)
        mem_write(pb, 0, job.bj_retry_count)
        _jq_append_wal(engine, JQ_OP_DEAD_LETTER, job_id, current_time, pb, 8)
        sys_free(pb)
        return JOB_STATUS_DEAD
    else
        next_run = current_time + (backoff_secs * job.bj_retry_count)
        job.bj_status = JOB_STATUS_PENDING
        job.bj_run_at = next_run
        pb = sys_alloc(16)
        mem_write(pb, 0, job.bj_retry_count)
        mem_write(pb, 8, next_run)
        _jq_append_wal(engine, JQ_OP_FAIL_RETRY, job_id, next_run, pb, 16)
        sys_free(pb)
        return JOB_STATUS_PENDING
    end

fn _jq_register_cron_unlocked engine task_name interval_secs
    cron = cron_schedule_new(task_name, interval_secs)
    tasks = engine.jqe_cron_tasks
    push(tasks, cron)
    _jq_log_cron_reg(engine, cron)
    return cron

// ── 6. Public Thread-Safe Lock-Guarded API ────────────────────────────────────

fn job_queue_enqueue engine id task_name payload run_at max_retries
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_enqueue_unlocked(engine, id, task_name, payload, run_at, max_retries)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_find_job engine id
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_find_job_unlocked(engine, id)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_poll_ready engine current_time
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_poll_ready_unlocked(engine, current_time)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_complete engine job_id
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_complete_unlocked(engine, job_id)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_fail_retry engine job_id current_time backoff_secs
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_fail_retry_unlocked(engine, job_id, current_time, backoff_secs)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_register_cron engine task_name interval_secs
    atomic_lock(engine.jqe_lock_ptr)
    res = _jq_register_cron_unlocked(engine, task_name, interval_secs)
    atomic_unlock(engine.jqe_lock_ptr)
    return res

fn job_queue_tick_cron engine current_time next_job_id
    atomic_lock(engine.jqe_lock_ptr)
    tasks = engine.jqe_cron_tasks
    tcount = len(tasks)
    enqueued_count = 0
    i = 0
    while i < tcount
        c = get(tasks, i)
        if c.cs_is_active == 1
            if (current_time - c.cs_last_run) >= c.cs_interval_secs
                c.cs_last_run = current_time
                if engine.jqe_wal_fd >= 0 and engine.jqe_is_replaying == 0
                    nl = str_len(c.cs_task_name)
                    pb = sys_alloc(8 + nl)
                    mem_write(pb, 0, nl)
                    if nl > 0 _jq_write_str_to_mem(pb + 8, c.cs_task_name, nl) end
                    _jq_append_wal(engine, JQ_OP_CRON_LAST_RUN, 0, current_time, pb, 8 + nl)
                    sys_free(pb)
                end
                _jq_enqueue_unlocked(engine, next_job_id + enqueued_count, c.cs_task_name, "CRON_TRIGGER", current_time, 3)
                enqueued_count = enqueued_count + 1
            end
        end
        i = i + 1
    end
    atomic_unlock(engine.jqe_lock_ptr)
    return enqueued_count

// ── 7. Crash-Safe Persistence: Open/Replay, Torn Truncate, & In-Flight Recovery

fn _jq_write_wal_header fd
    hdr = sys_alloc(16)
    mem_zero(hdr, 16)
    mem_byte_write(hdr, 0, 76) // 'L'
    mem_byte_write(hdr, 1, 74) // 'J'
    mem_byte_write(hdr, 2, 81) // 'Q'
    mem_byte_write(hdr, 3, 87) // 'W'
    mem_write_u32(hdr, 4, 1)
    _jq_write_exact(fd, hdr, 16)
    syscall(JQ_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
    sys_free(hdr)
    return 0

fn job_queue_engine_open wal_path
    // WHY: Opens or creates binary "LJQW" WAL journal, replays all CRC-32 valid records,
    // ftruncates any torn tail record, and recovers crashed RUNNING jobs back to PENDING.
    jqe = job_queue_engine_new()
    jqe.jqe_wal_path = wal_path
    fd = syscall(JQ_SYS_OPEN, wal_path, 66, 420, 0, 0, 0)
    if fd < 0 return jqe end

    sz = syscall(JQ_SYS_LSEEK, fd, 0, 2, 0, 0, 0)
    syscall(JQ_SYS_LSEEK, fd, 0, 0, 0, 0, 0)

    if sz < 16
        syscall(JQ_SYS_FTRUNCATE, fd, 0, 0, 0, 0, 0)
        syscall(JQ_SYS_LSEEK, fd, 0, 0, 0, 0, 0)
        _jq_write_wal_header(fd)
        jqe.jqe_wal_fd = fd
        return jqe
    end

    buf = sys_alloc(sz)
    got = 0
    while got < sz
        n = syscall(JQ_SYS_READ, fd, buf + got, sz - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end

    valid_end = 16
    if got >= 16 and mem_byte_read(buf, 0) == 76 and mem_byte_read(buf, 1) == 74 and mem_byte_read(buf, 2) == 81 and mem_byte_read(buf, 3) == 87
        jqe.jqe_is_replaying = 1
        pos = 16
        while pos + 32 <= got
            if mem_byte_read(buf, pos) != 74 or mem_byte_read(buf, pos + 1) != 81 or mem_byte_read(buf, pos + 2) != 87 or mem_byte_read(buf, pos + 3) != 82
                break
            end
            exp_crc = mem_read_u32(buf, pos + 4)
            op = mem_read_u32(buf, pos + 8)
            plen = mem_read_u32(buf, pos + 12)
            jid = mem_read(buf, pos + 16)
            ts_val = mem_read(buf, pos + 24)
            if plen < 0 or plen > 16777216 or (pos + 32 + plen) > got
                break
            end
            act_crc = _jq_crc32_compute(jqe.jqe_crc_table, buf, pos + 8, pos + 32 + plen)
            if act_crc != exp_crc
                break
            end

            p = buf + pos + 32
            if op == JQ_OP_ENQUEUE and plen >= 24
                rc_v = mem_read(p, 0)
                mr_v = mem_read(p, 8)
                nlen = mem_read_u32(p, 16)
                dlen = mem_read_u32(p, 20)
                if 24 + nlen + dlen <= plen
                    tname = _jq_read_str_from_mem(p + 24, nlen)
                    pld = _jq_read_str_from_mem(p + 24 + nlen, dlen)
                    job = _jq_enqueue_unlocked(jqe, jid, tname, pld, ts_val, mr_v)
                    job.bj_retry_count = rc_v
                end
            elif op == JQ_OP_START_RUNNING
                job = _jq_find_job_unlocked(jqe, jid)
                if job != 0
                    job.bj_status = JOB_STATUS_RUNNING
                end
            elif op == JQ_OP_COMPLETE
                job = _jq_find_job_unlocked(jqe, jid)
                if job != 0
                    job.bj_status = JOB_STATUS_COMPLETED
                    jqe.jqe_total_processed = jqe.jqe_total_processed + 1
                end
            elif op == JQ_OP_FAIL_RETRY and plen >= 16
                job = _jq_find_job_unlocked(jqe, jid)
                if job != 0
                    job.bj_retry_count = mem_read(p, 0)
                    job.bj_run_at = mem_read(p, 8)
                    job.bj_status = JOB_STATUS_PENDING
                    jqe.jqe_total_failed = jqe.jqe_total_failed + 1
                end
            elif op == JQ_OP_DEAD_LETTER and plen >= 8
                job = _jq_find_job_unlocked(jqe, jid)
                if job != 0
                    job.bj_retry_count = mem_read(p, 0)
                    job.bj_status = JOB_STATUS_DEAD
                    jqe.jqe_total_failed = jqe.jqe_total_failed + 1
                    jqe.jqe_dead_letter_count = jqe.jqe_dead_letter_count + 1
                end
            elif op == JQ_OP_REGISTER_CRON and plen >= 12
                iv_s = mem_read(p, 0)
                nlen = mem_read_u32(p, 8)
                if 12 + nlen <= plen
                    cname = _jq_read_str_from_mem(p + 12, nlen)
                    cr = _jq_register_cron_unlocked(jqe, cname, iv_s)
                    cr.cs_last_run = ts_val
                end
            elif op == JQ_OP_CRON_LAST_RUN and plen >= 8
                nlen = mem_read(p, 0)
                if 8 + nlen <= plen
                    cname = _jq_read_str_from_mem(p + 8, nlen)
                    ci = 0
                    while ci < len(jqe.jqe_cron_tasks)
                        cr = get(jqe.jqe_cron_tasks, ci)
                        if cr.cs_task_name == cname
                            cr.cs_last_run = ts_val
                            break
                        end
                        ci = ci + 1
                    end
                end
            elif op == JQ_OP_RECOVER_PENDING
                job = _jq_find_job_unlocked(jqe, jid)
                if job != 0
                    job.bj_status = JOB_STATUS_PENDING
                end
            end

            pos = pos + 32 + plen
            valid_end = pos
        end
        jqe.jqe_is_replaying = 0
    end

    sys_free(buf)
    if valid_end < sz
        syscall(JQ_SYS_FTRUNCATE, fd, valid_end, 0, 0, 0, 0)
        syscall(JQ_SYS_FSYNC, fd, 0, 0, 0, 0, 0)
    end
    syscall(JQ_SYS_LSEEK, fd, valid_end, 0, 0, 0, 0)
    jqe.jqe_wal_fd = fd

    // Automatic Crash Recovery: return any crashed in-flight RUNNING job back to PENDING (or DEAD if retries exhausted)
    jobs = jqe.jqe_jobs
    i = 0
    while i < len(jobs)
        j = get(jobs, i)
        if j.bj_status == JOB_STATUS_RUNNING
            if j.bj_retry_count >= j.bj_max_retries
                j.bj_status = JOB_STATUS_DEAD
                jqe.jqe_dead_letter_count = jqe.jqe_dead_letter_count + 1
                pb = sys_alloc(8)
                mem_write(pb, 0, j.bj_retry_count)
                _jq_append_wal(jqe, JQ_OP_DEAD_LETTER, j.bj_id, j.bj_run_at, pb, 8)
                sys_free(pb)
            else
                j.bj_status = JOB_STATUS_PENDING
                _jq_append_wal(jqe, JQ_OP_RECOVER_PENDING, j.bj_id, j.bj_run_at, 0, 0)
            end
        end
        i = i + 1
    end
    return jqe

fn job_queue_checkpoint engine
    if engine == 0 or str_len(engine.jqe_wal_path) == 0
        return -1
    end
    atomic_lock(engine.jqe_lock_ptr)
    wpath = engine.jqe_wal_path
    tmp_path = wpath + ".tmp"
    tfd = syscall(JQ_SYS_OPEN, tmp_path, 578, 420, 0, 0, 0)
    if tfd < 0
        atomic_unlock(engine.jqe_lock_ptr)
        return -1
    end
    _jq_write_wal_header(tfd)

    old_fd = engine.jqe_wal_fd
    old_rep = engine.jqe_is_replaying
    engine.jqe_wal_fd = tfd
    engine.jqe_is_replaying = 0

    // Snapshot crons
    tasks = engine.jqe_cron_tasks
    ci = 0
    while ci < len(tasks)
        _jq_log_cron_reg(engine, get(tasks, ci))
        ci = ci + 1
    end

    // Snapshot all jobs and their final states
    jobs = engine.jqe_jobs
    ji = 0
    while ji < len(jobs)
        j = get(jobs, ji)
        _jq_log_enqueue(engine, j)
        if j.bj_status == JOB_STATUS_RUNNING
            _jq_append_wal(engine, JQ_OP_START_RUNNING, j.bj_id, j.bj_run_at, 0, 0)
        elif j.bj_status == JOB_STATUS_COMPLETED
            _jq_append_wal(engine, JQ_OP_COMPLETE, j.bj_id, 0, 0, 0)
        elif j.bj_status == JOB_STATUS_DEAD
            pb = sys_alloc(8)
            mem_write(pb, 0, j.bj_retry_count)
            _jq_append_wal(engine, JQ_OP_DEAD_LETTER, j.bj_id, j.bj_run_at, pb, 8)
            sys_free(pb)
        end
        ji = ji + 1
    end

    syscall(JQ_SYS_FSYNC, tfd, 0, 0, 0, 0, 0)
    syscall(JQ_SYS_CLOSE, tfd, 0, 0, 0, 0, 0)
    if old_fd >= 0
        syscall(JQ_SYS_CLOSE, old_fd, 0, 0, 0, 0, 0)
    end
    syscall(JQ_SYS_RENAME, tmp_path, wpath, 0, 0, 0, 0)
    nfd = syscall(JQ_SYS_OPEN, wpath, 66, 420, 0, 0, 0)
    if nfd >= 0
        syscall(JQ_SYS_LSEEK, nfd, 0, 2, 0, 0, 0)
    end
    engine.jqe_wal_fd = nfd
    engine.jqe_is_replaying = old_rep
    atomic_unlock(engine.jqe_lock_ptr)
    return 1

fn job_queue_close engine
    if engine == 0 return 0 end
    if engine.jqe_wal_fd >= 0
        syscall(JQ_SYS_FSYNC, engine.jqe_wal_fd, 0, 0, 0, 0, 0)
        syscall(JQ_SYS_CLOSE, engine.jqe_wal_fd, 0, 0, 0, 0, 0)
        engine.jqe_wal_fd = 0 - 1
    end
    if engine.jqe_crc_table > 0
        sys_free(engine.jqe_crc_table)
        engine.jqe_crc_table = 0
    end
    if engine.jqe_lock_ptr > 0
        free(engine.jqe_lock_ptr, 16)
        engine.jqe_lock_ptr = 0
    end
    return 0
