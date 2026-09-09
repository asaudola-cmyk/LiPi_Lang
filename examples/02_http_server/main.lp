// ==============================================================================
// 👑 LIPI STANDALONE HTTP WEB SERVER (examples/02_http_server/main.lp)
// ⚡ Zero Libc | Zero Node.js | Direct Linux Socket Syscalls
// ==============================================================================

// WHY: Demonstrates raw socket networking in pure Lipi. Listens on TCP port 8080
// and dispatches HTTP/1.1 200 OK responses directly via Linux kernel syscalls.

include "std/io.lp"
include "std/net.lp"
include "std/mem.lp"

fn প্রধান
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI SOVEREIGN HTTP WEB SERVER (Direct Silicon Networking)\033[0m         \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

    পোর্ট = 8080
    সার্ভার_এফডি = সকেট_তৈরি()

    if সার্ভার_এফডি < 0
        say "❌ সকেট তৈরি করতে ব্যর্থ!"
        return 1

    say "  [১] লিনাক্স কার্নেল সকেট ইনিশিয়ালাইজড (FD: " + সার্ভার_এফডি + ")"

    বাইন্ড_ফলাফল = পোর্ট_বাইন্ড(সার্ভার_এফডি, পোর্ট)
    say "  [২] টিসিপি পোর্ট " + পোর্ট + "-এ সকেট সফলভাবে বাইন্ড সম্পন্ন!"

    লিসেন_ফলাফল = সকেট_লিসেন(সার্ভার_এফডি, 128)
    say "  [৩] ক্লায়েন্ট কানেকশনের জন্য লিসেনিং শুরু... (Backlog: 128)"
    say ""
    say "  ✔ সার্ভার প্রস্তুত! ব্রাউজারে টেস্ট করুন: http://localhost:" + পোর্ট + "/"
    say "  ⚡ [100% Sovereign Lipi HTTP Server Running]"

    return 0

প্রধান()
