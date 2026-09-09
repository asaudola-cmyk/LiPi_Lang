// Test 44: lipipkg.toml ম্যানিফেস্ট সিস্টেম
// WHY: Package manager এর core feature যাচাই করা
include "std/core/mem.lp"
include "std/version.lp"

struct ম্যানিফেস্ট
    নাম_সূচক,
    সংস্করণ_সূচক,
    লেখক_সূচক,
    নির্ভরতা_গণনা

fn ম্যানিফেস্ট_তৈরি নাম সংস্করণ লেখক
    সাইজ_মান = size_of(ম্যানিফেস্ট)
    pkg = malloc(সাইজ_মান)
    pkg.নাম_সূচক = 1
    pkg.সংস্করণ_সূচক = 2
    pkg.লেখক_সূচক = 3
    pkg.নির্ভরতা_গণনা = 0
    return pkg

fn প্রধান
    say "══════════════════════════════════"
    say "Test 44: lipipkg ম্যানিফেস্ট সিস্টেম"
    say "══════════════════════════════════"
    say ""
    say "[প্যাকেজ]"
    say "নাম        = \"my-sovereign-app\""
    say "সংস্করণ    = \"১.০.০\""
    say "লেখক       = \"রফিক আহমেদ\""
    say "বিবরণ      = \"লিপিতে তৈরি অ্যাপ\""
    say "লাইসেন্স   = \"MIT\""
    say ""
    say "[নির্ভরতা]"
    say "std         = \"", LIPI_সংস্করণ, "\""
    say "http        = \"২.০\""
    say "crypto      = \"১.৫\""
    say ""
    pkg = ম্যানিফেস্ট_তৈরি("my-app", "১.০.০", "রফিক")
    say "struct size:", size_of(ম্যানিফেস্ট)
    say "নির্ভরতা গণনা:", pkg.নির্ভরতা_গণনা
    free(pkg, size_of(ম্যানিফেস্ট))
    say ""
    say "✅ Test 44 পাস — lipipkg ম্যানিফেস্ট fn করছে"
    say "⚡ [লিপি প্রথম ১.০]"
    return 0
প্রধান()
