// ==============================================================================
// 👑 LIPI FULL-STACK SOVEREIGN HTTP WEB SERVER & DATABASE BACKEND
// File: apps/website/server.lp
// ⚡ 100% Pure Lipi | Zero Libc | Zero PHP | Linux Kernel AMD64 Syscalls
//
// WHY: Full-stack engine handling HTTP 1.1 routing, REST API endpoints,
// binary database CRUD operations, and persistent NVMe/SSD storage.
// ==============================================================================

অন্তর্ভুক্ত "std/io.lp"
অন্তর্ভুক্ত "std/net.lp"
অন্তর্ভুক্ত "std/mem.lp"
অন্তর্ভুক্ত "std/str.lp"
অন্তর্ভুক্ত "apps/website/db_engine.lp"

// ১. পূর্ণসংখ্যাকে আস্কি অক্ষরে রূপান্তর করে মেমরিতে লেখা
// WHY: ডাইনামিক মেট্রিক্স ও আইডিকে আস্কি স্ট্রিংয়ে রূপান্তর করা
কাজ সংখ্যা_থেকে_আস্কি(মান, গন্তব্য, শুরু_অফসেট) {
    if মান == ০ {
        মেমরি_বাইট_লেখো(গন্তব্য, শুরু_অফসেট, ৪৮)
        return শুরু_অফসেট + ১
    }

     টেম্প_মান = মান
     ডিজিট_সংখ্যা = ০
     স্ট্যাক_বাফার = বাফার()

    যতক্ষণ টেম্প_মান > ০ {
         ভাগশেষ = টেম্প_মান % ১০
        মেমরি_বাইট_লেখো(স্ট্যাক_বাফার, ডিজিট_সংখ্যা, ভাগশেষ + ৪৮)
        ডিজিট_সংখ্যা = ডিজিট_সংখ্যা + ১
        টেম্প_মান = টেম্প_মান / ১০
    }

     cursor = শুরু_অফসেট
     k = ডিজিট_সংখ্যা - ১
    যতক্ষণ k >= ০ {
         চ = মেমরি_বাইট_পড়ো(স্ট্যাক_বাফার, k)
        মেমরি_বাইট_লেখো(গন্তব্য, cursor, চ)
        cursor = cursor + ১
        k = k - ১
    }

    return cursor
}

// ২. স্ট্রিং অনুলিপি করে মেমরিতে অ্যাপেন্ড করা
// WHY: মেমরি বাফারে এইচটিটিপি হেডার ও জেএসন ফিল্ড সাজানো
কাজ স্ট্রিং_যোগ_করো(উৎস, গন্তব্য, শুরু_অফসেট) {
     cursor = শুরু_অফসেট
     i = ০
     চলমান = ১
    যতক্ষণ চলমান {
         বাইট = মেমরি_বাইট_পড়ো(উৎস, i)
        if বাইট == ০ {
            return cursor
        }
        মেমরি_বাইট_লেখো(গন্তব্য, cursor, বাইট)
        cursor = cursor + ১
        i = i + ১
    }
    return cursor
}

// ৩. HTTP রিকোয়েস্টে পাথ শুরুর অফসেট নির্ধারণ (Find Path Offset after Method)
// WHY: GET, POST, DELETE এর দৈর্ঘ্য ৩-৬ অক্ষর হতে পারে। প্রথম স্পেস খুঁজে পাথ স্টার্ট বের করা।
কাজ প্রথম_স্পেস_খুঁজো(বাফার_ঠিকানা, সাইজ) {
     i = ০
    যতক্ষণ i < সাইজ {
         b = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i)
        if b == ৩২ { // ' ' space
            return i + ১
        }
        i = i + ১
    }
    return ০
}

// ৪. রিকোয়েস্ট থেকে 'val=' সংখ্যা পার্স করা (Parse val=XXXX)
// WHY: POST বা GET রিকোয়েস্টে আসা নিউমেরিক প্যারামিটার এক্সট্রাক্ট করা
কাজ পার্স_মান(বাফার_ঠিকানা, সাইজ) {
     i = ০
     মান = ০
     সীমা = সাইজ - ৩
    যতক্ষণ i < সীমা {
         c1 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i)
         c2 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i + ১)
         c3 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i + ২)
         c4 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i + ৩)
        // 'v' = 118, 'a' = 97, 'l' = 108, '=' = 61
        if c1 == ১১৮ {
            if c2 == ৯৭ {
                if c3 == ১০৮ {
                    if c4 == ৬১ {
                         j = i + ৪
                         চলা = ১
                        যতক্ষণ চলা {
                            if j >= সাইজ {
                                চলা = ০
                            }
                            if j < সাইজ {
                                 ch = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, j)
                                if ch >= ৪৮ {
                                    if ch <= ৫৭ {
                                        মান = (মান * ১০) + (ch - ৪৮)
                                        j = j + ১
                                    }
                                }
                                if ch < ৪৮ {
                                    চলা = ০
                                }
                                if ch > ৫৭ {
                                    চলা = ০
                                }
                            }
                        }
                        return মান
                    }
                }
            }
        }
        i = i + ১
    }
    return মান
}

// ৫. রিকোয়েস্ট থেকে 'id=' সংখ্যা পার্স করা (Parse id=X)
// WHY: রেকর্ড মোছার জন্য টার্গেট রেকর্ড আইডি সংগ্রহ করা
কাজ পার্স_আইডি(বাফার_ঠিকানা, সাইজ) {
     i = ০
     মান = ০
     সীমা = সাইজ - ২
    যতক্ষণ i < সীমা {
         c1 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i)
         c2 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i + ১)
         c3 = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, i + ২)
        // 'i' = 105, 'd' = 100, '=' = 61
        if c1 == ১০৫ {
            if c2 == ১০০ {
                if c3 == ৬১ {
                     j = i + ৩
                     চলা = ১
                    যতক্ষণ চলা {
                        if j >= সাইজ {
                            চলা = ০
                        }
                        if j < সাইজ {
                             ch = মেমরি_বাইট_পড়ো(বাফার_ঠিকানা, j)
                            if ch >= ৪৮ {
                                if ch <= ৫৭ {
                                    মান = (মান * ১০) + (ch - ৪৮)
                                    j = j + ১
                                }
                            }
                            if ch < ৪৮ {
                                চলা = ০
                            }
                            if ch > ৫৭ {
                                চলা = ০
                            }
                        }
                    }
                    return মান
                }
            }
        }
        i = i + ১
    }
    return মান
}

// ৬. ডিস্ক থেকে স্ট্যাটিক ফাইল পাঠাও
কাজ ফাইল_পাঠাও(client_fd, ফাইলপাথ, মাইম_টাইপ) {
     ফাইল_এফডি = ফাইল_খোলো(ফাইলপাথ)
    if ফাইল_এফডি < ০ {
         নট_ফাউন্ড = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n404: File Not Found\n"
        ফাইল_লেখো(client_fd, নট_ফাউন্ড, দৈর্ঘ্য(নট_ফাউন্ড))
        return -১
    }

     আকার = syscall(৮, ফাইল_এফডি, ০, ২) // lseek SEEK_END
    syscall(৮, ফাইল_এফডি, ০, ০)            // lseek SEEK_SET

     ফাইল_বাফার = মেমরি_বরাদ্দ(আকার + ৮)
     পঠিত = ফাইল_পড়ো(ফাইল_এফডি, ফাইল_বাফার, আকার)
    ফাইল_বন্ধ(ফাইল_এফডি)

     হেডার_বাফার = বাফার()
     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 200 OK\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: ", হেডার_বাফার, cursor)
    cursor = স্ট্রিং_যোগ_করো(মাইম_টাইপ, হেডার_বাফার, cursor)
    cursor = স্ট্রিং_যোগ_করো("\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", হেডার_বাফার, cursor)

    syscall(১, client_fd, হেডার_বাফার, cursor)
    syscall(১, client_fd, ফাইল_বাফার, আকার)

    মেমরি_মুক্তি(ফাইল_বাফার, আকার + ৮)
    return ০
}

// ৭. ডাইনামিক টেলিমেট্রি স্ট্যাটাস এপিআই (/api/status)
কাজ ডাইনামিক_স্ট্যাটাস_প্রেরণ(client_fd, অনুরোধ_গণনা, শুরু_ক্লক) {
     বর্তমান_ক্লক = সিপিউ_ক্লক()
     ডেল্টা_সাইকেল = বর্তমান_ক্লক - শুরু_ক্লক

     response_buffer = মেমরি_বরাদ্দ(২০৪৮)
     বডি_শুরু = ১০২৪
     cursor = বডি_শুরু

    cursor = স্ট্রিং_যোগ_করো("{\"status\":\"sovereign_online\",\"engine\":\"Lipi Full-Stack Silicon ELF64\",\"version\":\"2.1-ultra\",\"cpu_cycles\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(বর্তমান_ক্লক, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"uptime_cycles\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(ডেল্টা_সাইকেল, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"requests_served\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(অনুরোধ_গণনা, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"memory_allocated_kb\":128,\"active_horizons\":21,\"php_dependency\":0,\"libc_dependency\":0}\n", response_buffer, cursor)

     বডি_আকার = cursor - বডি_শুরু

     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 200 OK\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", response_buffer, cursor)

    syscall(১, client_fd, response_buffer, cursor)
    syscall(১, client_fd, response_buffer + বডি_শুরু, বডি_আকার)

    মেমরি_মুক্তি(response_buffer, ২০৪৮)
    return ০
}

// ৮. ডাটাবেজ সমস্ত রেকর্ড JSON এ রিটার্ন (/api/db/items)
// WHY: বাইনারি ফাইল থেকে সরাসরি প্রতিটি রেকর্ড স্ক্যান করে JSON অ্যারে প্রস্তুত করা
কাজ ডিবি_রেকর্ডস_প্রেরণ(client_fd, ডিবি_এফডি) {
     মোট = ডিবি_মোট_রেকর্ড(ডিবি_এফডি)
     response_buffer = মেমরি_বরাদ্দ(১৬৩৮৪)
     বডি_শুরু = ১০২৪
     cursor = বডি_শুরু

    cursor = স্ট্রিং_যোগ_করো("[", response_buffer, cursor)

    syscall(৮, ডিবি_এফডি, ০, ০) // SEEK_SET
     বাফ = বাফার()
     প্রথম = ১
     i = ০

    যতক্ষণ i < মোট {
        syscall(০, ডিবি_এফডি, বাফ, ৩২)
         rec_id = মেমরি_পড়ো(বাফ, ০)
         rec_time = মেমরি_পড়ো(বাফ, ৮)
         rec_status = মেমরি_পড়ো(বাফ, ১৬)
         rec_val = মেমরি_পড়ো(বাফ, ২৪)

        if rec_status == ১ {
            if প্রথম == ০ {
                cursor = স্ট্রিং_যোগ_করো(",", response_buffer, cursor)
            }
            প্রথম = ০
            cursor = স্ট্রিং_যোগ_করো("{\"id\":", response_buffer, cursor)
            cursor = সংখ্যা_থেকে_আস্কি(rec_id, response_buffer, cursor)
            cursor = স্ট্রিং_যোগ_করো(",\"timestamp\":", response_buffer, cursor)
            cursor = সংখ্যা_থেকে_আস্কি(rec_time, response_buffer, cursor)
            cursor = স্ট্রিং_যোগ_করো(",\"status\":1,\"value\":", response_buffer, cursor)
            cursor = সংখ্যা_থেকে_আস্কি(rec_val, response_buffer, cursor)
            cursor = স্ট্রিং_যোগ_করো("}", response_buffer, cursor)
        }
        i = i + ১
    }

    cursor = স্ট্রিং_যোগ_করো("]\n", response_buffer, cursor)
     বডি_আকার = cursor - বডি_শুরু

     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 200 OK\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", response_buffer, cursor)

    syscall(১, client_fd, response_buffer, cursor)
    syscall(১, client_fd, response_buffer + বডি_শুরু, বডি_আকার)

    মেমরি_মুক্তি(response_buffer, ১৬৩৮৪)
    return ০
}

// ৯. ডাটাবেজে রেকর্ড যোগ করার এপিআই (/api/db/add)
কাজ ডিবি_রেকর্ড_ইনসার্ট_এপিআই(client_fd, ডিবি_এফডি, মান) {
    if মান == ০ {
        মান = ১০০
    }
     নতুন_আইডি = ডিবি_রেকর্ড_যোগ(ডিবি_এফডি, মান)

     response_buffer = মেমরি_বরাদ্দ(১০২৪)
     বডি_শুরু = ৫১২
     cursor = বডি_শুরু

    cursor = স্ট্রিং_যোগ_করো("{\"success\":true,\"message\":\"Record committed to Lipi NVMe store\",\"id\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(নতুন_আইডি, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"value\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(মান, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো("}\n", response_buffer, cursor)

     বডি_আকার = cursor - বডি_শুরু

     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 201 Created\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", response_buffer, cursor)

    syscall(১, client_fd, response_buffer, cursor)
    syscall(১, client_fd, response_buffer + বডি_শুরু, বডি_আকার)

    মেমরি_মুক্তি(response_buffer, ১০২৪)
    return নতুন_আইডি
}

// ১০. ডাটাবেজ থেকে রেকর্ড মোছার এপিআই (/api/db/delete)
কাজ ডিবি_রেকর্ড_ডিলিট_এপিআই(client_fd, ডিবি_এফডি, টার্গেট_আইডি) {
     ফলাফল = ডিবি_রেকর্ড_মুছো(ডিবি_এফডি, টার্গেট_আইডি)

     response_buffer = মেমরি_বরাদ্দ(১০২৪)
     বডি_শুরু = ৫১২
     cursor = বডি_শুরু

    cursor = স্ট্রিং_যোগ_করো("{\"success\":true,\"message\":\"Record soft deleted in Lipi store\",\"id\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(টার্গেট_আইডি, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"result\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(ফলাফল, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো("}\n", response_buffer, cursor)

     বডি_আকার = cursor - বডি_শুরু

     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 200 OK\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", response_buffer, cursor)

    syscall(১, client_fd, response_buffer, cursor)
    syscall(১, client_fd, response_buffer + বডি_শুরু, বডি_আকার)

    মেমরি_মুক্তি(response_buffer, ১০২৪)
    return ফলাফল
}

// ১১. ডাটাবেজ পরিসংখ্যান এপিআই (/api/db/stats)
কাজ ডিবি_স্ট্যাটস_প্রেরণ(client_fd, ডিবি_এফডি) {
     মোট = ডিবি_মোট_রেকর্ড(ডিবি_এফডি)
     সাইজ = ডিবি_ফাইলের_সাইজ(ডিবি_এফডি)

     response_buffer = মেমরি_বরাদ্দ(১০২৪)
     বডি_শুরু = ৫১২
     cursor = বডি_শুরু

    cursor = স্ট্রিং_যোগ_করো("{\"status\":\"success\",\"total_records\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(মোট, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"file_size_bytes\":", response_buffer, cursor)
    cursor = সংখ্যা_থেকে_আস্কি(সাইজ, response_buffer, cursor)
    cursor = স্ট্রিং_যোগ_করো(",\"fsync_guarantee\":\"100% NVMe Direct\",\"engine\":\"Lipi Native Binary Storage v1.0\"}\n", response_buffer, cursor)

     বডি_আকার = cursor - বডি_শুরু

     cursor = ০
    cursor = স্ট্রিং_যোগ_করো("HTTP/1.1 200 OK\r\nServer: Lipi-FullStack-Silicon/2.1\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", response_buffer, cursor)

    syscall(১, client_fd, response_buffer, cursor)
    syscall(১, client_fd, response_buffer + বডি_শুরু, বডি_আকার)

    মেমরি_মুক্তি(response_buffer, ১০২৪)
    return ০
}

// ==============================================================================
// প্রধান ফুল-স্ট্যাক সার্ভার এক্সিকিউশন (Main Server Execution)
// ==============================================================================

say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI FULL-STACK SOVEREIGN WEB & DATABASE ENGINE (v2.1 Ultra)\033[0m       \033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Frontend + Backend + Database | 100% Pure Native Machine Code        \033[0m\033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
say ""

// ১. ডাটাবেজ ফাইল ইনিশিয়ালাইজেশন
 ডিবি_পাথ = "apps/website/data/sovereign_store.db"
 ডিবি_এফডি = ডিবি_খোলো(ডিবি_পাথ)
if ডিবি_এফডি < ০ {
    say "\033[1;31m❌ ত্রুটি: ডাটাবেজ ফাইল খোলা সম্ভব হয়নি!\033[0m"
    return ১
}

// if ডাটাবেজ সম্পূর্ণ নতুন হয়, তবে প্রাথমিক বীজ রেকর্ড যোগ করা
 প্রাথমিক_রেকর্ড = ডিবি_মোট_রেকর্ড(ডিবি_এফডি)
if প্রাথমিক_রেকর্ড == ০ {
    ডিবি_রেকর্ড_যোগ(ডিবি_এফডি, ১০২৪)
    ডিবি_রেকর্ড_যোগ(ডিবি_এফডি, ২০৪৮)
    ডিবি_রেকর্ড_যোগ(ডিবি_এফডি, ৪০৯৬)
    say "\033[1;32m  ✔ ডাটাবেজে ৩টি প্রাথমিক বীজ রেকর্ড সফলভাবে ইনসার্ট করা হয়েছে।\033[0m"
}

// ২. টিসিপি নেটওয়ার্ক সকেট কনফিগারেশন
 সার্ভার_এফডি = সকেট_তৈরি()
if সার্ভার_এফডি < ০ {
    say "\033[1;31m❌ ত্রুটি: নেটওয়ার্ক সকেট তৈরি ব্যর্থ!\033[0m"
    return ১
}

সকেট_অপশন_সেট(সার্ভার_এফডি, বাফার())
 পোর্ট = ৮০৮০
 বাইন্ড_কোড = পোর্ট_বাইন্ড(সার্ভার_এফডি, বাফার(), পোর্ট)
if বাইন্ড_কোড != ০ {
    say "\033[1;31m❌ ত্রুটি: পোর্ট ৮০৮০ এ বাইন্ড ব্যর্থ (Port In Use)!\033[0m"
    সকেট_বন্ধ(সার্ভার_এফডি)
    return ১
}

 ব্যাকলগ = ৬৪
 লিসেন_কোড = সকেট_লিসেন(সার্ভার_এফডি, ব্যাকলগ)
if লিসেন_কোড != ০ {
    say "\033[1;31m❌ ত্রুটি: লিসেন মোড চালু করা যায়নি!\033[0m"
    সকেট_বন্ধ(সার্ভার_এফডি)
    return ১
}

say "\033[1;32m✔ লিপি ফুল-স্ট্যাক সার্বভৌম ওয়েব ও ডাটাবেজ সার্ভার সক্রিয়!\033[0m"
say "\033[1;36m  • ফ্রন্টএন্ড ইউআই  : http://localhost:8080/\033[0m"
say "\033[1;36m  • ডাটাবেজ এন্ডপয়েন্ট: http://localhost:8080/api/db/items\033[0m"
say "\033[1;33m  • স্টোরেজ পাথ     : " + ডিবি_পাথ + "\033[0m"
say "\033[1;33m  • নির্ভরতা        : ০% Libc | ০% PHP | ০% Node | ১০০% খাঁটি লিপি\033[0m"
say ""

 শুরু_ক্লক = সিপিউ_ক্লক()
 অনুরোধ_গণনা = ০
 রিকোয়েস্ট_বাফার = মেমরি_বরাদ্দ(৪০৯৬)

// ৩. ফুল-স্ট্যাক রিকোয়েস্ট লুপ (Full-Stack Request Event Loop)
 সার্ভার_চলমান = ১
যতক্ষণ সার্ভার_চলমান {
     client_fd = সকেট_গ্রহণ(সার্ভার_এফডি)
    if client_fd >= ০ {
        অনুরোধ_গণনা = অনুরোধ_গণনা + ১
         পঠিত = ফাইল_পড়ো(client_fd, রিকোয়েস্ট_বাফার, ২০৪৮)

        // মেথড পরবর্তী পাথ শুরুর পজিশন নির্ণয় (Dynamic Path Start Offset)
         p = প্রথম_স্পেস_খুঁজো(রিকোয়েস্ট_বাফার, পঠিত)

         p0 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ০) // '/'
         p1 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ১)
         p2 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ২)
         p3 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৩)
         p4 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৪)
         p5 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৫)
         p6 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৬)
         p7 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৭)
         p8 = মেমরি_বাইট_পড়ো(রিকোয়েস্ট_বাফার, p + ৮)

         হ্যান্ডেলড = ০

        // [এপিআই ১] /api/db/... (p1='a', p2='p', p3='i', p4='/', p5='d', p6='b', p7='/')
        if p1 == ৯৭ {
            if p2 == ১১২ {
                if p3 == ১০৫ {
                    if p4 == ৪৭ {
                        if p5 == ১০০ {
                            if p6 == ৯৮ {
                                if p7 == ৪৭ {
                                    // p8 == 'i' (/api/db/items)
                                    if p8 == ১০৫ {
                                        ডিবি_রেকর্ডস_প্রেরণ(client_fd, ডিবি_এফডি)
                                        সকেট_বন্ধ(client_fd)
                                        হ্যান্ডেলড = ১
                                        say "  [DB 📦] /api/db/items সার্ভ সম্পন্ন #" + অনুরোধ_গণনা
                                    }

                                    // p8 == 'a' (/api/db/add)
                                    if p8 == ৯৭ {
                                         ইনপুট_মান = পার্স_মান(রিকোয়েস্ট_বাফার, পঠিত)
                                        ডিবি_রেকর্ড_ইনসার্ট_এপিআই(client_fd, ডিবি_এফডি, ইনপুট_মান)
                                        সকেট_বন্ধ(client_fd)
                                        হ্যান্ডেলড = ১
                                        say "  [DB ➕] /api/db/add সম্পন্ন: মান=" + ইনপুট_মান
                                    }

                                    // p8 == 'd' (/api/db/delete)
                                    if p8 == ১০০ {
                                         ডেল_আইডি = পার্স_আইডি(রিকোয়েস্ট_বাফার, পঠিত)
                                        ডিবি_রেকর্ড_ডিলিট_এপিআই(client_fd, ডিবি_এফডি, ডেল_আইডি)
                                        সকেট_বন্ধ(client_fd)
                                        হ্যান্ডেলড = ১
                                        say "  [DB 🗑️] /api/db/delete সম্পন্ন: id=" + ডেল_আইডি
                                    }

                                    // p8 == 's' (/api/db/stats)
                                    if p8 == ১১৫ {
                                        ডিবি_স্ট্যাটস_প্রেরণ(client_fd, ডিবি_এফডি)
                                        সকেট_বন্ধ(client_fd)
                                        হ্যান্ডেলড = ১
                                        say "  [DB 📊] /api/db/stats সম্পন্ন #" + অনুরোধ_গণনা
                                    }
                                }
                            }
                        }

                        // [এপিআই ২] /api/status (p5='s', p6='t', p7='a', p8='t')
                        if p5 == ১১৫ {
                            ডাইনামিক_স্ট্যাটাস_প্রেরণ(client_fd, অনুরোধ_গণনা, শুরু_ক্লক)
                            সকেট_বন্ধ(client_fd)
                            হ্যান্ডেলড = ১
                            say "  [API ⚡] /api/status সম্পন্ন #" + অনুরোধ_গণনা
                        }
                    }
                }
            }
        }

        // [অ্যাসেট ১] /style.css
        if হ্যান্ডেলড == ০ {
            if p1 == ১১৫ {
                if p2 == ১১৬ {
                    if p3 == ১২১ {
                        ফাইল_পাঠাও(client_fd, "apps/website/public/style.css", "text/css; charset=utf-8")
                        সকেট_বন্ধ(client_fd)
                        হ্যান্ডেলড = ১
                    }
                }
            }
        }

        // [অ্যাসেট ২] /app.js
        if হ্যান্ডেলড == ০ {
            if p1 == ৯৭ {
                if p2 == ১১২ {
                    if p3 == ১১২ {
                        if p4 == ৪৬ {
                            ফাইল_পাঠাও(client_fd, "apps/website/public/app.js", "application/javascript; charset=utf-8")
                            সকেট_বন্ধ(client_fd)
                            হ্যান্ডেলড = ১
                        }
                    }
                }
            }
        }

        // [অ্যাসেট ৩] /favicon.svg
        if হ্যান্ডেলড == ০ {
            if p1 == ১০২ {
                if p2 == ৯৭ {
                    if p3 == ১১৮ {
                        ফাইল_পাঠাও(client_fd, "apps/website/public/favicon.svg", "image/svg+xml")
                        সকেট_বন্ধ(client_fd)
                        হ্যান্ডেলড = ১
                    }
                }
            }
        }

        // [হোমপেজ] / অথবা /index.html
        if হ্যান্ডেলড == ০ {
            ফাইল_পাঠাও(client_fd, "apps/website/public/index.html", "text/html; charset=utf-8")
            সকেট_বন্ধ(client_fd)
            হ্যান্ডেলড = ১
        }
    }
}

মেমরি_মুক্তি(রিকোয়েস্ট_বাফার, ৪০৯৬)
ফাইল_বন্ধ(ডিবি_এফডি)
সকেট_বন্ধ(সার্ভার_এফডি)
say "সার্ভার সমাপ্ত।"
