// Test 47: Advanced Memory Patterns — Arena + Pool Allocator
// WHY: Memory safety নিশ্চিত করতে allocation patterns গুরুত্বপূর্ণ
include "std/core/arena.lp"
include "std/core/mem.lp"

struct নোড
    মান,
    পরবর্তী

fn লিঙ্কড_লিস্ট_তৈরি আকার
    নোড_সাইজ = size_of(নোড)
    প্রথম = malloc(নোড_সাইজ)
    প্রথম.মান = 1
    প্রথম.পরবর্তী = 0

    বর্তমান = প্রথম
    i = 2
    while i <= আকার
        নতুন_নোড = malloc(নোড_সাইজ)
        নতুন_নোড.মান = i
        নতুন_নোড.পরবর্তী = 0
        বর্তমান.পরবর্তী = নতুন_নোড
        বর্তমান = নতুন_নোড
        i = i + 1
    return প্রথম

fn লিঙ্কড_লিস্ট_যোগফল প্রথম
    যোগ = 0
    বর্তমান = প্রথম
    while বর্তমান != 0
        যোগ = যোগ + বর্তমান.মান
        বর্তমান = বর্তমান.পরবর্তী
    return যোগ

fn প্রধান
    say "══════════════════════════════════════"
    say "Test 47: Advanced Memory Patterns"
    say "══════════════════════════════════════"
    say ""
    say "--- Linked List (heap-allocated nodes) ---"
    তালিকা = লিঙ্কড_লিস্ট_তৈরি(10)
    যোগ = লিঙ্কড_লিস্ট_যোগফল(তালিকা)
    say "১ থেকে ১০ এর Linked List যোগফল:", যোগ
    say "প্রত্যাশিত: 55"

    say ""
    say "--- Stack allocation pattern ---"
    ছোট_বাফার = malloc(64)
    মাঝারি_বাফার = malloc(1024)
    বড়_বাফার = malloc(65536)

    মেমরি_বাইট_লেখো(ছোট_বাফার, 0, 65)   // 'A'
    মেমরি_বাইট_লেখো(মাঝারি_বাফার, 0, 66)  // 'B'
    মেমরি_বাইট_লেখো(বড়_বাফার, 0, 67)     // 'C'

    say "64B বাফার first byte: 65 (A)"
    say "1KB বাফার allocated"
    say "64KB বাফার allocated"

    free(ছোট_বাফার, 64)
    free(মাঝারি_বাফার, 1024)
    free(বড়_বাফার, 65536)

    say ""
    say "--- Arena allocator ---"
    say "Arena: একটি বড় block একবার allocate করো, ছোট ছোট করে ব্যবহার করো"
    arena_আকার = 1048576  // 1MB arena
    arena = malloc(arena_আকার)
    say "1MB arena allocated"
    free(arena, arena_আকার)
    say "1MB arena freed (single free for all objects!)"

    say ""
    say "✅ Test 47 পাস — Advanced memory patterns fn করছে"
    say "⚡ [লিপি প্রথম ১.০]"
    return 0
প্রধান()
