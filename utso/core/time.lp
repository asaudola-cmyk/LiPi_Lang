// ==============================================================================
// 📜 লিপি সময় ও টাইমস্ট্যাম্প লাইব্রেরি (Pure Lipi Standard Time Library)
// 🏛️ Direct লিনাক্স কার্নেল ক্লক ও হাই-রেজোলিউশন স্লিপ (Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — Direct SYS_nanosleep ও SYS_clock_gettime
// File: std/time.lp
// ==============================================================================

include "utso/core/memory.lp"

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

fn clock_ms
    return time_now_ms()


// WHY: Benchmarking timer utilities
fn timer_start label
    return clock_ms()

fn timer_stop start_ms
    now = clock_ms()
    elapsed = now - start_ms
    if elapsed < 0
        elapsed = 0
    return elapsed

fn time_format_ms ms
    return str(ms) + " ms"
end

// ── ৫. মনোটোনিক ক্লক (CLOCK_MONOTONIC = 1 via SYS_clock_gettime: Syscall 228) ──
// WHY: Immune to NTP / wall-clock jumps for accurate latency measurements & timeouts.

fn time_monotonic_ns
    ts_buf = malloc(16)
    syscall(228, 1, ts_buf, 0, 0, 0, 0)
    sec = mem_read(ts_buf, 0)
    nsec = mem_read(ts_buf, 8)
    free(ts_buf, 16)
    return (sec * 1000000000) + nsec
end

fn time_monotonic_us
    return time_monotonic_ns() / 1000
end

fn time_monotonic_ms
    return time_monotonic_ns() / 1000000
end

fn monotonic_timer_start
    return time_monotonic_ns()
end

fn monotonic_timer_elapsed_ns start_ns
    now = time_monotonic_ns()
    diff = now - start_ns
    if diff < 0
        diff = 0
    end
    return diff
end

fn monotonic_timer_elapsed_ms start_ns
    return monotonic_timer_elapsed_ns(start_ns) / 1000000
end

// ── ৬. সিভিল ক্যালেন্ডার, টাইমজোন ও ISO-8601 / RFC-3339 / HTTP-Date ───────────
// WHY: Pure-Lipi O(1) proleptic Gregorian calendar (Howard Hinnant algorithm) with
// Euclidean floor division for full pre-1970, leap-year, Y2038+, and timezone accuracy.

struct DateTime
    dt_year
    dt_month
    dt_day
    dt_hour
    dt_minute
    dt_second
    dt_nanosecond
    dt_tz_offset_min
    dt_weekday
    dt_yearday
    dt_valid
end

fn _time_floor_div a b
    q = a / b
    r = a % b
    if r < 0
        q = q - 1
    end
    return q
end

fn _time_floor_mod a b
    r = a % b
    if r < 0
        r = r + b
    end
    return r
end

fn time_is_leap_year y
    if _time_floor_mod(y, 4) != 0
        return 0
    end
    if _time_floor_mod(y, 100) != 0
        return 1
    end
    if _time_floor_mod(y, 400) == 0
        return 1
    end
    return 0
end

fn time_days_in_month y m
    if m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 or m == 12
        return 31
    end
    if m == 4 or m == 6 or m == 9 or m == 11
        return 30
    end
    if m == 2
        if time_is_leap_year(y) == 1
            return 29
        end
        return 28
    end
    return 0
end

fn time_days_from_civil y m d
    // WHY: Exact O(1) civil (Y, M, D) -> days since 1970-01-01 (works for all dates including negative years).
    yr = y
    if m <= 2
        yr = yr - 1
    end
    era = _time_floor_div(yr, 400)
    yoe = yr - (era * 400)
    mp = m + 9
    if m > 2
        mp = m - 3
    end
    doy = ((153 * mp) + 2) / 5 + d - 1
    doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy
    return (era * 146097) + doe - 719468
end

fn _time_yearday y m d
    acc = d
    mm = 1
    while mm < m
        acc = acc + time_days_in_month(y, mm)
        mm = mm + 1
    end
    return acc
end

fn time_datetime_new year month day hour minute second nanosecond tz_offset_min
    dt = DateTime()
    dt.dt_year = year
    dt.dt_month = month
    dt.dt_day = day
    dt.dt_hour = hour
    dt.dt_minute = minute
    dt.dt_second = second
    dt.dt_nanosecond = nanosecond
    dt.dt_tz_offset_min = tz_offset_min
    if month >= 1 and month <= 12 and day >= 1 and day <= time_days_in_month(year, month) and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 and second >= 0 and second <= 59 and nanosecond >= 0 and nanosecond < 1000000000 and tz_offset_min > (0 - 1440) and tz_offset_min < 1440
        days = time_days_from_civil(year, month, day)
        // 1970-01-01 was Thursday (4); Sunday = 0 .. Saturday = 6
        dt.dt_weekday = _time_floor_mod(days + 4, 7)
        dt.dt_yearday = _time_yearday(year, month, day)
        dt.dt_valid = 1
    else
        dt.dt_weekday = 0
        dt.dt_yearday = 0
        dt.dt_valid = 0
    end
    return dt
end

fn time_from_unix_offset unix_sec tz_offset_min
    // WHY: Converts Unix epoch seconds to civil DateTime in fixed offset (minutes east of UTC).
    local_sec = unix_sec + (tz_offset_min * 60)
    z = _time_floor_div(local_sec, 86400)
    sod = _time_floor_mod(local_sec, 86400)
    hour = sod / 3600
    rem = sod % 3600
    minute = rem / 60
    second = rem % 60

    z_shift = z + 719468
    era = _time_floor_div(z_shift, 146097)
    doe = z_shift - (era * 146097)
    yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365
    y = yoe + (era * 400)
    doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100))
    mp = ((5 * doy) + 2) / 153
    d = doy - (((153 * mp) + 2) / 5) + 1
    m = mp - 9
    if mp < 10
        m = mp + 3
    end
    if m <= 2
        y = y + 1
    end

    dt = DateTime()
    dt.dt_year = y
    dt.dt_month = m
    dt.dt_day = d
    dt.dt_hour = hour
    dt.dt_minute = minute
    dt.dt_second = second
    dt.dt_nanosecond = 0
    dt.dt_tz_offset_min = tz_offset_min
    dt.dt_weekday = _time_floor_mod(z + 4, 7)
    dt.dt_yearday = _time_yearday(y, m, d)
    dt.dt_valid = 1
    return dt
end

fn time_from_unix_utc unix_sec
    return time_from_unix_offset(unix_sec, 0)
end

fn time_to_unix dt: DateTime
    days = time_days_from_civil(dt.dt_year, dt.dt_month, dt.dt_day)
    local_sec = (days * 86400) + (dt.dt_hour * 3600) + (dt.dt_minute * 60) + dt.dt_second
    return local_sec - (dt.dt_tz_offset_min * 60)
end

fn time_convert_offset dt: DateTime new_tz_offset_min
    u = time_to_unix(dt)
    out = time_from_unix_offset(u, new_tz_offset_min)
    out.dt_nanosecond = dt.dt_nanosecond
    return out
end

fn time_now_offset tz_offset_min
    ts_buf = malloc(16)
    syscall(228, 0, ts_buf, 0, 0, 0, 0)
    sec = mem_read(ts_buf, 0)
    nsec = mem_read(ts_buf, 8)
    free(ts_buf, 16)
    dt = time_from_unix_offset(sec, tz_offset_min)
    dt.dt_nanosecond = nsec
    return dt
end

fn time_now_utc
    return time_now_offset(0)
end

fn _time_pad2 n
    v = n
    if v < 0
        v = 0 - v
    end
    if v < 10
        return "0" + str(v)
    end
    return str(v)
end

fn _time_pad4 n
    neg = 0
    v = n
    if v < 0
        neg = 1
        v = 0 - v
    end
    s = str(v)
    while len(s) < 4
        s = "0" + s
    end
    if neg == 1
        return "-" + s
    end
    return s
end

fn time_weekday_name wday
    if wday == 0 return "Sun" end
    if wday == 1 return "Mon" end
    if wday == 2 return "Tue" end
    if wday == 3 return "Wed" end
    if wday == 4 return "Thu" end
    if wday == 5 return "Fri" end
    if wday == 6 return "Sat" end
    return "Sun"
end

fn time_month_name month
    if month == 1 return "Jan" end
    if month == 2 return "Feb" end
    if month == 3 return "Mar" end
    if month == 4 return "Apr" end
    if month == 5 return "May" end
    if month == 6 return "Jun" end
    if month == 7 return "Jul" end
    if month == 8 return "Aug" end
    if month == 9 return "Sep" end
    if month == 10 return "Oct" end
    if month == 11 return "Nov" end
    if month == 12 return "Dec" end
    return "Jan"
end

fn _time_parse_month_name m3
    if m3 == "Jan" return 1 end
    if m3 == "Feb" return 2 end
    if m3 == "Mar" return 3 end
    if m3 == "Apr" return 4 end
    if m3 == "May" return 5 end
    if m3 == "Jun" return 6 end
    if m3 == "Jul" return 7 end
    if m3 == "Aug" return 8 end
    if m3 == "Sep" return 9 end
    if m3 == "Oct" return 10 end
    if m3 == "Nov" return 11 end
    if m3 == "Dec" return 12 end
    return 0
end

fn time_format_civil dt: DateTime
    return _time_pad4(dt.dt_year) + "-" + _time_pad2(dt.dt_month) + "-" + _time_pad2(dt.dt_day) + " " + _time_pad2(dt.dt_hour) + ":" + _time_pad2(dt.dt_minute) + ":" + _time_pad2(dt.dt_second)
end

fn time_format_iso8601 dt: DateTime
    base = _time_pad4(dt.dt_year) + "-" + _time_pad2(dt.dt_month) + "-" + _time_pad2(dt.dt_day) + "T" + _time_pad2(dt.dt_hour) + ":" + _time_pad2(dt.dt_minute) + ":" + _time_pad2(dt.dt_second)
    off = dt.dt_tz_offset_min
    if off == 0
        return base + "Z"
    end
    sign = "+"
    abs_off = off
    if abs_off < 0
        sign = "-"
        abs_off = 0 - abs_off
    end
    oh = abs_off / 60
    om = abs_off % 60
    return base + sign + _time_pad2(oh) + ":" + _time_pad2(om)
end

fn time_format_http_date dt: DateTime
    // WHY: RFC 7231 IMF-fixdate requires GMT (UTC): "Sun, 06 Nov 1994 08:49:37 GMT"
    utc = dt
    if dt.dt_tz_offset_min != 0
        utc = time_convert_offset(dt, 0)
    end
    return time_weekday_name(utc.dt_weekday) + ", " + _time_pad2(utc.dt_day) + " " + time_month_name(utc.dt_month) + " " + _time_pad4(utc.dt_year) + " " + _time_pad2(utc.dt_hour) + ":" + _time_pad2(utc.dt_minute) + ":" + _time_pad2(utc.dt_second) + " GMT"
end

fn _time_parse_digits s start count
    if start + count > len(s)
        return 0 - 1
    end
    val = 0
    i = 0
    while i < count
        b = mem_byte_read(s, start + i) & 255
        if b < 48 or b > 57
            return 0 - 1
        end
        val = (val * 10) + (b - 48)
        i = i + 1
    end
    return val
end

fn _time_invalid_dt
    dt = DateTime()
    dt.dt_year = 0
    dt.dt_month = 0
    dt.dt_day = 0
    dt.dt_hour = 0
    dt.dt_minute = 0
    dt.dt_second = 0
    dt.dt_nanosecond = 0
    dt.dt_tz_offset_min = 0
    dt.dt_weekday = 0
    dt.dt_yearday = 0
    dt.dt_valid = 0
    return dt
end

fn time_parse_iso8601 s
    // WHY: Parses RFC-3339 / ISO-8601 strings ("YYYY-MM-DDTHH:MM:SS[.fff][Z|+HH:MM|-HH:MM|+HHMM]")
    // as well as civil "YYYY-MM-DD HH:MM:SS" strings with strict field & calendar validation.
    n = len(s)
    if n < 19
        return _time_invalid_dt()
    end
    if (mem_byte_read(s, 4) & 255) != 45 or (mem_byte_read(s, 7) & 255) != 45
        return _time_invalid_dt()
    end
    sep = mem_byte_read(s, 10) & 255
    if sep != 84 and sep != 116 and sep != 32
        return _time_invalid_dt()
    end
    if (mem_byte_read(s, 13) & 255) != 58 or (mem_byte_read(s, 16) & 255) != 58
        return _time_invalid_dt()
    end
    yr = _time_parse_digits(s, 0, 4)
    mo = _time_parse_digits(s, 5, 2)
    dy = _time_parse_digits(s, 8, 2)
    hr = _time_parse_digits(s, 11, 2)
    mn = _time_parse_digits(s, 14, 2)
    sc = _time_parse_digits(s, 17, 2)
    if yr < 0 or mo < 1 or mo > 12 or dy < 1 or hr < 0 or hr > 23 or mn < 0 or mn > 59 or sc < 0 or sc > 59
        return _time_invalid_dt()
    end
    if dy > time_days_in_month(yr, mo)
        return _time_invalid_dt()
    end

    pos = 19
    nsec = 0
    if pos < n and (mem_byte_read(s, pos) & 255) == 46
        pos = pos + 1
        mul = 100000000
        saw_frac = 0
        while pos < n
            fb = mem_byte_read(s, pos) & 255
            if fb >= 48 and fb <= 57
                saw_frac = 1
                if mul > 0
                    nsec = nsec + ((fb - 48) * mul)
                    mul = mul / 10
                end
                pos = pos + 1
            else
                break
            end
        end
        if saw_frac == 0
            return _time_invalid_dt()
        end
    end

    tz_min = 0
    if pos < n
        tc = mem_byte_read(s, pos) & 255
        if tc == 90 or tc == 122
            pos = pos + 1
        elif tc == 43 or tc == 45
            tsign = 1
            if tc == 45
                tsign = 0 - 1
            end
            pos = pos + 1
            th = _time_parse_digits(s, pos, 2)
            if th < 0 or th > 23
                return _time_invalid_dt()
            end
            pos = pos + 2
            if pos < n and (mem_byte_read(s, pos) & 255) == 58
                pos = pos + 1
            end
            tm = _time_parse_digits(s, pos, 2)
            if tm < 0 or tm > 59
                return _time_invalid_dt()
            end
            pos = pos + 2
            tz_min = tsign * ((th * 60) + tm)
        else
            return _time_invalid_dt()
        end
    end
    if pos != n
        return _time_invalid_dt()
    end
    return time_datetime_new(yr, mo, dy, hr, mn, sc, nsec, tz_min)
end

fn _time_parse_weekday_name w3
    if w3 == "Sun" return 0 end
    if w3 == "Mon" return 1 end
    if w3 == "Tue" return 2 end
    if w3 == "Wed" return 3 end
    if w3 == "Thu" return 4 end
    if w3 == "Fri" return 5 end
    if w3 == "Sat" return 6 end
    return 0 - 1
end

fn time_parse_http_date s
    // WHY: Parses RFC 7231 IMF-fixdate: "Sun, 06 Nov 1994 08:49:37 GMT" (29 bytes),
    // strictly validating the weekday name against the computed Gregorian weekday.
    if len(s) != 29
        return _time_invalid_dt()
    end
    if (mem_byte_read(s, 3) & 255) != 44 or (mem_byte_read(s, 4) & 255) != 32 or (mem_byte_read(s, 7) & 255) != 32 or (mem_byte_read(s, 11) & 255) != 32 or (mem_byte_read(s, 16) & 255) != 32 or (mem_byte_read(s, 19) & 255) != 58 or (mem_byte_read(s, 22) & 255) != 58 or (mem_byte_read(s, 25) & 255) != 32
        return _time_invalid_dt()
    end
    if str_sub(s, 26, 29) != "GMT"
        return _time_invalid_dt()
    end
    exp_wd = _time_parse_weekday_name(str_sub(s, 0, 3))
    if exp_wd < 0
        return _time_invalid_dt()
    end
    dy = _time_parse_digits(s, 5, 2)
    mo = _time_parse_month_name(str_sub(s, 8, 11))
    yr = _time_parse_digits(s, 12, 4)
    hr = _time_parse_digits(s, 17, 2)
    mn = _time_parse_digits(s, 20, 2)
    sc = _time_parse_digits(s, 23, 2)
    if yr < 0 or mo < 1 or mo > 12 or dy < 1 or hr < 0 or hr > 23 or mn < 0 or mn > 59 or sc < 0 or sc > 59
        return _time_invalid_dt()
    end
    if dy > time_days_in_month(yr, mo)
        return _time_invalid_dt()
    end
    dt = time_datetime_new(yr, mo, dy, hr, mn, sc, 0, 0)
    if dt.dt_valid != 1 or dt.dt_weekday != exp_wd
        return _time_invalid_dt()
    end
    return dt
end
