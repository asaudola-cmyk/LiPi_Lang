// ==============================================================================
// 📜 লিপি কলাম-স্টোর ডাটাবেস ইঞ্জিন (Pure Lipi Vectorized ColumnStore)
// 🏛️ SQL ও রিলেশনাল ডাটাবেসের বিকল্প হিসেবে কন্টিনুয়াস বাইনারি মেমরি কলাম
// ০% SQL, ০% SQLite, ০% B-Tree নির্ভরতা — direct mem-অ্যালাইনড কলাম ও SIMD প্রসেসিং
// ==============================================================================

include "universe/core/memory.lp"

// ১. কলাম মেমরি বরাদ্দ (Allocate Column Memory via SYS_mmap)
// WHY: নির্দিষ্ট ডেটা টাইপের (যেমন ৬৪-বিট ইন্টিজার) জন্য মেমরিতে একটি কন্টিনুয়াস ব্লক তৈরি করা।
fn column_create row_count
    // প্রতিটি রো ৮ বাইট (৬৪-বিট QWORD)
    size = row_count * 8
    // SYS_mmap (9) -> PROT_READ|PROT_WRITE (3), MAP_PRIVATE|MAP_ANONYMOUS (34)
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    mem_fill(পয়েন্টার, 0, size)
    return পয়েন্টার

fn কলাম_তৈরি row_count
    return column_create(row_count)

// ২. কলামে ডেটা লেখা (Write 64-bit Data to Column at row_index)
// WHY: ৬৪-বিট ইন্টিজার ডেটা কলামের রো ইনডেক্স অনুযায়ী মেমরি অফসেটে দ্রুত সংরক্ষণ করা।
fn col_write column_pointer row_index value
    offset = row_index * 8
    mem_write(column_pointer, offset, value)
    return value

fn column_write column_pointer row_index value
    return col_write(column_pointer, row_index, value)

fn কলাম_লেখো column_pointer row_index value
    return col_write(column_pointer, row_index, value)

// ৩. কলাম থেকে ডেটা পড়া (Read 64-bit Data from Column at row_index)
// WHY: রো ইনডেক্সের অফসেট হিসাব করে সরাসরি মেমরি থেকে ৬৪-বিট মান লোড করা।
fn column_read column_pointer row_index
    offset = row_index * 8
    value = mem_read(column_pointer, offset)
    return value

fn column_পড়ো column_pointer row_index
    return column_read(column_pointer, row_index)

fn কলাম_পড়ো column_pointer row_index
    return column_read(column_pointer, row_index)

// ৪. ভেক্টরাইজড অ্যানালিটিক্যাল কুয়েরি: ফিল্টার ও যোগফল (Vectorized Conditional Sum Query)
// WHY: লুপের ভেতরে শর্ত চেক করে নির্দিষ্ট রো-এর ডেটা যোগ করা (SELECT SUM(col2) WHERE col1 > cond_val)।
fn column_cond_sum cond_col sum_col row_count cond_val
    total_sum = 0
    index = 0

    while index < row_count
        offset = index * 8
        বর্তমান_শর্ত = mem_read(cond_col, offset)
        if বর্তমান_শর্ত > cond_val
            বর্তমান_মান = mem_read(sum_col, offset)
            total_sum = total_sum + বর্তমান_মান
        index = index + 1

    return total_sum

fn কলাম_শর্ত_যোগ cond_col sum_col row_count cond_val
    return column_cond_sum(cond_col, sum_col, row_count, cond_val)

// ৫. কলাম মেমরি অবমুক্তি (Free Column via SYS_munmap)
// WHY: বরাদ্দকৃত মেমরি পেজগুলো লিনাক্স কার্নেলে সফলভাবে ফিরিয়ে দেওয়া।
fn column_delete column_pointer row_count
    size = row_count * 8
    result = syscall(11, column_pointer, size, 0, 0, 0, 0) // SYS_munmap
    return 1

fn column_free column_pointer row_count
    return column_delete(column_pointer, row_count)

fn কলাম_মুক্তি column_pointer row_count
    return column_delete(column_pointer, row_count)
