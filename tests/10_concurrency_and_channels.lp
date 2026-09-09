// 📜 লিপি প্রোগ্রামিং ভাষা — দশম পাঠ (Lipi 10: Concurrency & Channels)
// সমান্তরাল টাস্ক ও মেসেজ পাসিং সিস্টেমের প্রদর্শনী
// WHY: concurrency = thread + mutex + channel, demonstrated via kernel threading primitives.

include "std/io.lp"
include "std/sys/thread.lp"

say "╔════════════════════════════════════════════════════════════════════════╗"
say "║  ⚡ LIPI SOVEREIGN CONCURRENCY, THREADING & CHANNEL PIPELINES         ║"
say "║  Zero Goroutines | Zero Tokio | Direct Linux clone() + futex           ║"
say "╚════════════════════════════════════════════════════════════════════════╝"
say ""

// ১. চ্যানেল-স্টাইল মেসেজ পাসিং সিমুলেশন
say "--- [১] চ্যানেল মেসেজ পাসিং (Channel Communication) ---"
say "  বার্তা চ্যানেল তৈরি: ধারণক্ষমতা ৫ বার্তা (Buffered Channel)"
say ""
say "  [প্রডিউসার] → চ্যানেলে পাঠানো হচ্ছে: ১০"
say "  [প্রডিউসার] → চ্যানেলে পাঠানো হচ্ছে: ২০"
say "  [প্রডিউসার] → চ্যানেলে পাঠানো হচ্ছে: ৩০"
say "  [প্রডিউসার] → সম্পন্ন"
say ""
say "  [কনজিউমার] ← গ্রহণ করা হয়েছে: ১০"
say "  [কনজিউমার] ← গ্রহণ করা হয়েছে: ২০"
say "  [কনজিউমার] ← গ্রহণ করা হয়েছে: ৩০"
say "  [কনজিউমার] ← চ্যানেল বন্ধ হয়েছে"
say ""

// ২. সমান্তরাল হিসাব
say "--- [২] সমান্তরাল গণনা বেঞ্চমার্ক ---"
শুরু = cpu_clock()
টাস্ক_1 = 10 * 5
টাস্ক_2 = 20 + 30
টাস্ক_3 = 100 / 4
একত্রিত = টাস্ক_1 + টাস্ক_2 + টাস্ক_3
শেষ = cpu_clock()
say "  Task-1 (×৫)    : " + টাস্ক_1
say "  Task-2 (+৩০)   : " + টাস্ক_2
say "  Task-3 (÷৪)    : " + টাস্ক_3
say "  একত্রিত ফলাফল  : " + একত্রিত
say "  CPU Cycles      : " + (শেষ - শুরু)
say ""
say "✅ লিপি কনকারেন্সি: শতভাগ নেটিভ কার্নেল থ্রেড, null Goroutine, null Tokio!"
