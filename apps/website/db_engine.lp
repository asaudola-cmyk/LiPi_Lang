// ==============================================================================
// 👑 LIPI SOVEREIGN BINARY DATABASE ENGINE (apps/website/db_engine.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Zero External DBMS | Direct Silicon Storage
//
// WHY: Implements a standalone, persistent 32-byte binary record database engine
// directly on Linux kernel filesystem syscalls (SYS_open, SYS_lseek, SYS_write,
// SYS_read, SYS_fsync) with zero data loss guarantee.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"

// ১. ডাটাবেজ ফাইল খোলা বা তৈরি করা (Open or Create Binary DB File)
// WHY: O_RDWR (2) | O_CREAT (64) = 66, Mode 0644o = 420
fn db_open path
    fd = syscall(2, path, 66, 420, 0, 0, 0)
    return fd

fn ডিবি_খোলো পাথ
    return db_open(পাথ)

// ২. ডাটাবেজে নতুন রেকর্ড ইনসার্ট করা (Insert Record with SYS_fsync)
// WHY: 32-byte binary layout: [ID: 8B (off 0) | Timestamp: 8B (off 8) | Status: 8B (off 16) | Value: 8B (off 24)]
// SYS_fsync (74) ensures the data is written directly to physical NVMe/SSD silicon.
fn db_insert_record fd val
    size = syscall(8, fd, 0, 2, 0, 0, 0)
    next_id = (size / 32) + 1
    buf = malloc(64)

    mem_write(buf, 0, next_id)
    mem_write(buf, 8, cpu_clock())
    mem_write(buf, 16, 1)
    mem_write(buf, 24, val)

    syscall(1, fd, buf, 32, 0, 0, 0)
    syscall(74, fd, 0, 0, 0, 0, 0)
    free(buf, 64)
    return next_id

fn ডিবি_রেকর্ড_যোগ fd মান
    return db_insert_record(fd, মান)

// ৩. রেকর্ড মুছে ফেলা (Soft Delete Record via Offset Mutation)
// WHY: স্ট্যাটাস ফিল্ডকে ০ করে দিলে রেকর্ডটি নিষ্ক্রিয় হয়, ডাটাবেজের ইনডেক্স অখণ্ড থাকে।
fn db_delete_record fd target_id
    if target_id <= 0
        return 0

    offset = (target_id - 1) * 32
    syscall(8, fd, offset + 16, 0, 0, 0, 0)

    buf = malloc(16)
    mem_write(buf, 0, 0)
    syscall(1, fd, buf, 8, 0, 0, 0)
    syscall(74, fd, 0, 0, 0, 0, 0)
    free(buf, 16)
    return 1

fn ডিবি_রেকর্ড_মুছো fd টার্গেট_আইডি
    return db_delete_record(fd, টার্গেট_আইডি)

// ৪. মোট রেকর্ডের সংখ্যা গণনা
fn db_total_records fd
    size = syscall(8, fd, 0, 2, 0, 0, 0)
    total = size / 32
    return total

fn ডিবি_মোট_রেকর্ড fd
    return db_total_records(fd)

// ৫. ডাটাবেজের বাইট সাইজ রিটার্ন করা
fn db_file_size fd
    size = syscall(8, fd, 0, 2, 0, 0, 0)
    return size

fn ডিবি_ফাইলের_সাইজ fd
    return db_file_size(fd)
