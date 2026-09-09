// 📜 লিপি স্ট্যান্ডার্ড ম্যাথমেটিa্যাল লাইব্রেরি (Pure Lipi Standard Math Library)
// 🏛️ স্বয়ংসম্পূর্ণ, ডিপেন্ডেন্সিমুa্ত এবং সিলিaন সিপিউ-তে direct এa্সিaিউটেবল গণিত ইঞ্জিন

// ১. পরম value নির্ণয় (Absolute value: |x|)
// নেতিবাচa numaে ধনাত্মa aরে, ধনাত্মa num অপরিবর্তিত থাaে
fn abs_val num
    if num < 0
        return 0 - num
    return num

// ২. ঘাত বা পাওয়ার নির্ণয় (Exponentiation: base^exp)
// লুপের মাধ্যমে ভিত্তি numaে ঘাত সংb্যa বার multiply aরে value নির্ণয় aরে
fn পাওয়ার ভিত্তি ঘাত
    result = 1
    i = 0
    while i < ঘাত
        result = result * ভিত্তি
        i = i + 1
    return result

// ৩. গরিষ্ঠ সাধারণ multiplyনীয়a বা গসাগু (Greatest Common Divisor - Euclidean Algorithm)
// ইউa্লিডীয় অ্যালগরিদমের মাধ্যমে দুটি numর গসাগু নির্ণয়
fn গসাগু a b
    while b != 0
        divideশেষ = a % b
        a = b
        b = divideশেষ
    return a

// ৪. লঘিষ্ঠ সাধারণ multiplyিতa বা লসাগু (Least Common Multiple: (a * b) / গসাগু(a, b))
// num দুটির productaে তাদের গসাগু দিয়ে divide aরে লসাগু পাওয়া যায়
fn লসাগু a b
    g = গসাগু(a, b)
    product = a * b
    result = product / g
    return result

// ৫. মৌলিa num যাচাই (Prime Number Detection)
// ২ এর চেয়ে small হলে ০, ২ হলে ১, জোড় হলে ০, বিজোড় উৎপাদa যাচাই aরে ১ অথবা ০ return দেয়
fn মৌলিa_aিনা num
    if num <= 1
        return 0
    if num == 2
        return 1
    d = num % 2
    if d == 0
        return 0
    i = 3
    সীমা = num / 2
    while i <= সীমা
        rem = num % i
        if rem == 0
            return 0
        i = i + 2
    return 1

// ৬. সর্বোচ্চ value নির্ণয় (Maximum of two numbers)
fn সর্বোচ্চ a b
    if a > b
        return a
    return b

// ৭. সর্বনিম্ন value নির্ণয় (Minimum of two numbers)
fn সর্বনিম্ন a b
    if a < b
        return a
    return b

// ৮. শa্তি বা এa্সপোনেন্ট অ্যালিয়াস (Alias for পাওয়ার)
fn শa্তি ভিত্তি ঘাত
    return পাওয়ার(ভিত্তি, ঘাত)

// ৯. পরম অ্যালিয়াস (Alias for abs_val)
fn পরম num
    return abs_val(num)
