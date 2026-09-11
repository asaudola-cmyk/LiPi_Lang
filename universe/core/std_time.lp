// ==============================================================================
// 📜 লিপি সময় ও টাইমস্ট্যাম্প লাইব্রেরি (Pure Lipi Standard Time Library)
// 🏛️ Direct লিনাক্স কার্নেল ক্লক ও হাই-রেজোলিউশন স্লিপ (Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — Direct SYS_nanosleep ও SYS_clock_gettime
// File: std/time.lp
// ==============================================================================

include "universe/core/std_mem.lp"

// ── ১. মিলিসেকেন্ড স্লিপ (High-Resolution Sleep via SYS_nanosleep: Syscall 35) ──
// WHY: সিপিউ সাইকেল অপচয় না করে নির্দিষ্ট মিলিসেকেন্ডের জন্য কার্নেল দ্বারা প্রসেস সাসপেন্ড করা।
// Linux struct timespec: { int64_t tv_sec (offset 0), int64_t tv_nsec (offset 8) }
fn মিলিসেকেন্ড_ঘুম মিলি
    sec = মিলি / 1000
    rem_ms = মিলি % 1000
    nsec = rem_ms * 1000000
    ts_buf = malloc(16)
    mem_write(ts_buf, 0, sec)
    mem_write(ts_buf, 8, nsec)
    res = syscall(35, ts_buf, 0, 0, 0, 0, 0)
    free(ts_buf, 16)
    return res

fn sleep_ms ms
    return মিলিসেকেন্ড_ঘুম(ms)

// ── ২. সেকেন্ড স্লিপ (Standard Sleep in Seconds via SYS_nanosleep: Syscall 35) ──
// WHY: নির্দিষ্ট পূর্ণ সেকেন্ডের জন্য এক্সিকিউশন পজ করা।
fn ঘুম সেকেন্ড
    ts_buf = malloc(16)
    mem_write(ts_buf, 0, সেকেন্ড)
    mem_write(ts_buf, 8, 0)
    res = syscall(35, ts_buf, 0, 0, 0, 0, 0)
    free(ts_buf, 16)
    return res

fn sleep sec
    return ঘুম(sec)

// ── ৩. বর্তমান ইউনিক্স টাইমস্ট্যাম্প সেকেন্ড (Current Epoch Time in Seconds) ──────
// WHY: CLOCK_REALTIME (0) ব্যবহার করে কার্নেল থেকে সঠিক ইউনিক্স epoch সেকেন্ড প্রাপ্তি।
// SYS_clock_gettime: Syscall 228
fn বর্তমান_সময়_সেকেন্ড
    ts_buf = malloc(16)
    syscall(228, 0, ts_buf, 0, 0, 0, 0)
    sec = mem_read(ts_buf, 0)
    free(ts_buf, 16)
    return sec

fn time_now_sec
    return বর্তমান_সময়_সেকেন্ড()

// ── ৪. বর্তমান ন্যানোসেকেন্ড ফ্র্যাকশন (Current Nanosecond Offset) ────────────────
// WHY: সাব-সেকেন্ড নির্ভুলতা ও পারফরম্যান্স বেঞ্চমার্কিংয়ের জন্য কার্নেল ন্যানোসেকেন্ড পড়া।
fn বর্তমান_সময়_ন্যানো
    ts_buf = malloc(16)
    syscall(228, 0, ts_buf, 0, 0, 0, 0)
    nsec = mem_read(ts_buf, 8)
    free(ts_buf, 16)
    return nsec

fn time_now_nano
    return বর্তমান_সময়_ন্যানো()
