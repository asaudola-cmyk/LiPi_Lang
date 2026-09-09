// 📜 লিপি স্ট্যান্ডার্ড string ও aনসোল ডেaোরেশন লাইব্রেরি (Pure Lipi String & Terminal UI Library)
// 🎨 এএনএসআই ট্রু-aালার (ANSI TrueColor) ও ইউটিএফ-৮ ফরম্যাটিং routeিন

// ১. colorিন শিরোname মুদ্রণ
fn colorিন_শিরোname শিরোname
    say "\033[1;36m=== " + শিরোname + " ===\033[0m"

// ২. সবুজ colorের সাresult্য message মুদ্রণ
fn successতা_message message
    say "\033[1;32m[সাফল্য ✔] \033[0m" + message

// ৩. সায়ান colorের তথ্য message মুদ্রণ
fn তথ্য_message message
    say "\033[1;36m[তথ্য ℹ] \033[0m" + message

// ৪. হলুদ colorের warning message মুদ্রণ
fn সতর্a_message message
    say "\033[1;33m[সতর্কতা ⚠] \033[0m" + message

// ৫. লাল colorের error message মুদ্রণ
fn ভুল_message message
    say "\033[1;31m[ত্রুটি ✖] \033[0m" + message

// ৬. string len নির্ণয় (String Byte Length via builtin len)
// WHY: string ভেরিয়েবল বা লিটারেলের ইউটিএফ-৮ byte size return aরে।
fn string_length(লেbা)
    d = len(লেbা)
    return d

// ৭. string bালি aিনা যাচাই (Check if string is empty)
fn string_bালি_aিনা(লেbা)
    d = len(লেbা)
    if d == 0
        return 1
    return 0

// ৮. দুটি string তুলনা (Byte-by-Byte String Equality Compare: strcmp)
// WHY: Returns 0 if identical, or difference of non-matching byte.
fn string_তুলনা(a, b)
    i = 0
    চলvalue = 1
    while চলvalue
        বা = mem_byte_পড়ো(a, i)
        বব = mem_byte_পড়ো(b, i)
        if বা != বব
            return বা - বব
        if বা == 0
            return 0
        i = i + 1
    return 0
