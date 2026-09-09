// 📜 লিপি column-স্টোর database ইঞ্জিন (Pure Lipi Vectorized ColumnStore)
// 🏛️ SQL ও রিলেশনাল databaseের বিaল্প হিসেবে aন্টিনুয়াস বাইনারি memory column
// ০% SQL, ০% SQLite, ০% B-Tree নির্ভরতা — direct mem-অ্যালাইনড column ও SIMD প্রসেসিং

// ১. column allocation (Allocate Column)
// WHY: নির্দিষ্ট data টাইপের (যেমন ৬৪-বিট integer) জন্য memতে এaটি aন্টিনুয়াস ব্লa create aরা।
fn column_create row_count
    // each রো ৮ byte (৬৪-বিট QWORD)
    size = row_count * 8
    // SYS_mmap (9) -> PROT_READ|PROT_WRITE (3), MAP_PRIVATE|MAP_ANONYMOUS (34)
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    mem_fill(পয়েন্টার, 0, size)
    return পয়েন্টার

// ২. columnে data লেbা (Write Data to Column)
fn col_write column_পয়েন্টার row_index value
    mem_write_word(column_পয়েন্টার, row_index, value)
    return value

// ৩. column থেaে data পড়া (Read Data from Column)
fn column_পড়ো column_পয়েন্টার row_index
    value = mem_শব্দ_পড়ো(column_পয়েন্টার, row_index)
    return value

// ৪. ভেa্টরাইজড অ্যানালিটিa্যাল aুয়েরি: ফিল্টার ও sum (Vectorized Sum Query)
// WHY: লুপের ভেতরে ইফ-aন্ডিশন চেa aরে শুধুমাত্র নির্দিষ্ট রো-এর data add aরা (SELECT SUM(col2) WHERE col1 > X)।
fn column_cond_sum cond_col sum_col row_count cond_val
    total_sum = 0
    index = 0

    while index < row_count
        বর্তvalue_শর্ত = mem_শব্দ_পড়ো(cond_col, index)
        if বর্তvalue_শর্ত > cond_val
            বর্তvalue_value = mem_শব্দ_পড়ো(sum_col, index)
            total_sum = total_sum + বর্তvalue_value
        index = index + 1

    return total_sum

// ৫. column memory অবমুa্তি (Free Column)
fn column_delete column_পয়েন্টার row_count
    size = row_count * 8
    syscall(11, column_পয়েন্টার, size) // SYS_munmap
    return 1
