// ==============================================================================
// 📜 লিপি সময় ও টাইমস্ট্যাম্প লাইব্রেরি (Pure Lipi Standard Time Library)
// 🏛️ Direct লিনাক্স কার্নেল ক্লক ও হাই-রেজোলিউশন স্লিপ (Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — Direct SYS_nanosleep ও SYS_clock_gettime
// File: std/time.lp
// ==============================================================================

include "utso/core/memory.lp"

// ── ১. মিলিসেকেন্ড স্লিপ (High-Resolution Sleep via SYS_nanosleep: Syscall 35) ──
// WHY: Retries SYS_nanosleep on EINTR (-4) using Linux's `rem` timespec output so
// STW GC SIGURG signals never truncate sleep duration prematurely.
// Linux struct timespec: { int64_t tv_sec (offset 0), int64_t tv_nsec (offset 8) }
fn _time_nanosleep_eintr sec nsec
    if sec < 0 or (sec == 0 and nsec <= 0)
        return 0
    end
    buf = malloc(32)
    if buf <= 0
        return -1
    end
    // WHY: Pass `buf` and `buf + 16` directly without aliasing `buf` into another variable
    // so `utso/core/time.lp` stays 100% clean under `--kavach --strict-ownership`.
    mem_write(buf, 0, sec)
    mem_write(buf, 8, nsec)
    mem_write(buf, 16, 0)
    mem_write(buf, 24, 0)
    res = syscall(35, buf, buf + 16, 0, 0, 0, 0)
    while res == (0 - 4)
        r_sec = mem_read(buf, 16)
        r_nsec = mem_read(buf, 24)
        if r_sec <= 0 and r_nsec <= 0
            res = 0
            break
        end
        mem_write(buf, 0, r_sec)
        mem_write(buf, 8, r_nsec)
        mem_write(buf, 16, 0)
        mem_write(buf, 24, 0)
        res = syscall(35, buf, buf + 16, 0, 0, 0, 0)
    end
    free(buf, 32)
    return res
end

fn মিলিসেকেন্ড_ঘুম মিলি
    if মিলি <= 0
        return 0
    end
    sec = মিলি / 1000
    rem_ms = মিলি % 1000
    nsec = rem_ms * 1000000
    return _time_nanosleep_eintr(sec, nsec)
end

fn sleep_ms ms
    return মিলিসেকেন্ড_ঘুম(ms)
end

// ── ২. সেকেন্ড স্লিপ (Standard Sleep in Seconds via SYS_nanosleep: Syscall 35) ──
// WHY: নির্দিষ্ট পূর্ণ সেকেন্ডের জন্য এক্সিকিউশন পজ করা (EINTR-safe)।
fn ঘুম সেকেন্ড
    return _time_nanosleep_eintr(সেকেন্ড, 0)
end

fn sleep sec
    return ঘুম(sec)
end

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

// ── ৭. RFC 8536 TZif v1/v2/v3 Binary Timezone Database Parser ─────────────────
// WHY: Enables genuine IANA timezone & DST resolution directly from `/etc/localtime`
// and `/usr/share/zoneinfo/*` in 100% Pure LiPi (0% libc `localtime_r`, 0% external deps).

struct TzInfo
    tz_valid
    tz_name
    tz_version
    tz_trans_times
    tz_trans_types
    tz_tt_utoff
    tz_tt_isdst
    tz_tt_abbrs
    tz_posix_tz
    tz_default_off
end

fn _tzif_invalid name
    tz = TzInfo()
    tz.tz_valid = 0
    tz.tz_name = name
    tz.tz_version = 0
    tz.tz_trans_times = list()
    tz.tz_trans_types = list()
    tz.tz_tt_utoff = list()
    tz.tz_tt_isdst = list()
    tz.tz_tt_abbrs = list()
    tz.tz_posix_tz = ""
    tz.tz_default_off = 0
    return tz
end

fn _tzif_u32_be ptr off
    b0 = mem_byte_read(ptr, off) & 255
    b1 = mem_byte_read(ptr, off + 1) & 255
    b2 = mem_byte_read(ptr, off + 2) & 255
    b3 = mem_byte_read(ptr, off + 3) & 255
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
end

fn _tzif_i32_be ptr off
    u = _tzif_u32_be(ptr, off)
    if u >= 2147483648
        return u - 4294967296
    end
    return u
end

fn _tzif_i64_be ptr off
    hi = _tzif_i32_be(ptr, off)
    lo = _tzif_u32_be(ptr, off + 4)
    return (hi * 4294967296) + lo
end

fn _tzif_read_cstr ptr base max_len start_idx
    if start_idx < 0 or start_idx >= max_len
        return ""
    end
    e = start_idx
    while e < max_len and (mem_byte_read(ptr, base + e) & 255) != 0
        e = e + 1
    end
    if e <= start_idx
        return ""
    end
    return bytes_to_str(ptr + base + start_idx, e - start_idx)
end

fn _tzif_check_magic ptr off total_len
    if off + 44 > total_len
        return 0
    end
    if (mem_byte_read(ptr, off) & 255) != 84 or (mem_byte_read(ptr, off + 1) & 255) != 90 or (mem_byte_read(ptr, off + 2) & 255) != 105 or (mem_byte_read(ptr, off + 3) & 255) != 102
        return 0
    end
    return 1
end

fn _tzif_parse_raw_buf ptr total_len name
    // WHY: RFC 8536 specifies v1 (32-bit transitions) followed by an optional 64-bit
    // v2/v3 header + data block + trailing POSIX TZ footer (`\n<rule>\n`).
    if _tzif_check_magic(ptr, 0, total_len) != 1
        return _tzif_invalid(name)
    end
    ver_b = mem_byte_read(ptr, 4) & 255
    isut1 = _tzif_u32_be(ptr, 20)
    isstd1 = _tzif_u32_be(ptr, 24)
    leap1 = _tzif_u32_be(ptr, 28)
    time1 = _tzif_u32_be(ptr, 32)
    type1 = _tzif_u32_be(ptr, 36)
    char1 = _tzif_u32_be(ptr, 40)
    if type1 <= 0 or char1 <= 0
        return _tzif_invalid(name)
    end

    v1_body_sz = (time1 * 5) + (type1 * 6) + char1 + (leap1 * 8) + isstd1 + isut1
    v2_off = 44 + v1_body_sz
    if v2_off > total_len
        return _tzif_invalid(name)
    end

    use_64 = 0
    hdr_off = 0
    ver_num = 1
    if ver_b >= 50 and _tzif_check_magic(ptr, v2_off, total_len) == 1
        use_64 = 1
        hdr_off = v2_off
        if ver_b == 50
            ver_num = 2
        elif ver_b == 51
            ver_num = 3
        else
            ver_num = 4
        end
    end

    isut = _tzif_u32_be(ptr, hdr_off + 20)
    isstd = _tzif_u32_be(ptr, hdr_off + 24)
    leap = _tzif_u32_be(ptr, hdr_off + 28)
    timecnt = _tzif_u32_be(ptr, hdr_off + 32)
    typecnt = _tzif_u32_be(ptr, hdr_off + 36)
    charcnt = _tzif_u32_be(ptr, hdr_off + 40)
    if typecnt <= 0 or charcnt <= 0
        return _tzif_invalid(name)
    end

    tsize = 4
    lsize = 8
    if use_64 == 1
        tsize = 8
        lsize = 12
    end
    pos = hdr_off + 44
    need_end = pos + (timecnt * (tsize + 1)) + (typecnt * 6) + charcnt + (leap * lsize) + isstd + isut
    if need_end > total_len
        return _tzif_invalid(name)
    end

    trans_times = list()
    i = 0
    while i < timecnt
        if use_64 == 1
            push(trans_times, _tzif_i64_be(ptr, pos + (i * 8)))
        else
            push(trans_times, _tzif_i32_be(ptr, pos + (i * 4)))
        end
        i = i + 1
    end
    pos = pos + (timecnt * tsize)

    trans_types = list()
    i = 0
    while i < timecnt
        tidx = mem_byte_read(ptr, pos + i) & 255
        if tidx >= typecnt
            return _tzif_invalid(name)
        end
        push(trans_types, tidx)
        i = i + 1
    end
    pos = pos + timecnt

    tt_off_base = pos
    char_base = pos + (typecnt * 6)

    tt_utoff = list()
    tt_isdst = list()
    tt_abbrs = list()
    default_off = 0
    found_std = 0
    i = 0
    while i < typecnt
        rec = tt_off_base + (i * 6)
        uoff = _tzif_i32_be(ptr, rec)
        isd = mem_byte_read(ptr, rec + 4) & 255
        didx = mem_byte_read(ptr, rec + 5) & 255
        push(tt_utoff, uoff)
        push(tt_isdst, isd)
        push(tt_abbrs, _tzif_read_cstr(ptr, char_base, charcnt, didx))
        if i == 0
            default_off = uoff
        end
        if found_std == 0 and isd == 0
            default_off = uoff
            found_std = 1
        end
        i = i + 1
    end

    // Extract optional RFC 8536 §3.3.1 POSIX TZ footer (`\n<tz_str>\n`) for v2/v3
    posix_tz = ""
    if use_64 == 1 and need_end + 2 <= total_len and (mem_byte_read(ptr, need_end) & 255) == 10
        fstart = need_end + 1
        fend = fstart
        while fend < total_len and (mem_byte_read(ptr, fend) & 255) != 10
            fend = fend + 1
        end
        if fend > fstart
            posix_tz = bytes_to_str(ptr + fstart, fend - fstart)
        end
    end

    tz = TzInfo()
    tz.tz_valid = 1
    tz.tz_name = name
    tz.tz_version = ver_num
    tz.tz_trans_times = trans_times
    tz.tz_trans_types = trans_types
    tz.tz_tt_utoff = tt_utoff
    tz.tz_tt_isdst = tt_isdst
    tz.tz_tt_abbrs = tt_abbrs
    tz.tz_posix_tz = posix_tz
    tz.tz_default_off = default_off
    return tz
end

fn time_parse_tzif_bytes byte_list name
    // WHY: Parses a TZif v1/v2/v3 binary payload supplied as a list of byte values.
    n = len(byte_list)
    if n < 44
        return _tzif_invalid(name)
    end
    buf = malloc(n)
    if buf <= 0
        return _tzif_invalid(name)
    end
    i = 0
    while i < n
        mem_byte_write(buf, i, get(byte_list, i) & 255)
        i = i + 1
    end
    tz = _tzif_parse_raw_buf(buf, n, name)
    free(buf, n)
    return tz
end

fn time_load_tzif path
    // WHY: Reads raw binary TZif file via Linux SYS_open/SYS_lseek/SYS_read (NUL-byte safe!).
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return _tzif_invalid(path)
    end
    sz = syscall(8, fd, 0, 2, 0, 0, 0) // SYS_lseek(fd, 0, SEEK_END)
    if sz < 44 or sz > 1048576
        syscall(3, fd, 0, 0, 0, 0, 0)
        return _tzif_invalid(path)
    end
    syscall(8, fd, 0, 0, 0, 0, 0) // SEEK_SET
    buf = malloc(sz)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return _tzif_invalid(path)
    end
    got = 0
    while got < sz
        r = syscall(0, fd, buf + got, sz - got, 0, 0, 0)
        if r == (0 - 4)
            continue
        end
        if r <= 0
            break
        end
        got = got + r
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    if got < 44
        free(buf, sz)
        return _tzif_invalid(path)
    end
    tz = _tzif_parse_raw_buf(buf, got, path)
    free(buf, sz)
    return tz
end

fn _tzif_parse_posix_name s pos
    // Returns [name_str, next_pos]
    n = len(s)
    if pos >= n return ["", pos] end
    if (mem_byte_read(s, pos) & 255) == 60 // '<' quoted name
        q = pos + 1
        while q < n and (mem_byte_read(s, q) & 255) != 62
            q = q + 1
        end
        nm = str_sub(s, pos + 1, q)
        if q < n q = q + 1 end
        return [nm, q]
    end
    q = pos
    while q < n
        c = mem_byte_read(s, q) & 255
        if (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
            q = q + 1
        else
            break
        end
    end
    return [str_sub(s, pos, q), q]
end

fn _tzif_parse_posix_hms s pos invert_sign
    // Parses [+|-]hh[:mm[:ss]] returning [ok, seconds, next_pos]
    n = len(s)
    if pos >= n return [0, 0, pos] end
    sign = 1
    c0 = mem_byte_read(s, pos) & 255
    if c0 == 45
        sign = 0 - 1
        pos = pos + 1
    elif c0 == 43
        pos = pos + 1
    end
    if invert_sign == 1
        sign = 0 - sign
    end
    if pos >= n return [0, 0, pos] end
    ch = mem_byte_read(s, pos) & 255
    if ch < 48 or ch > 57 return [0, 0, pos] end
    hh = 0
    while pos < n
        d = mem_byte_read(s, pos) & 255
        if d >= 48 and d <= 57
            hh = (hh * 10) + (d - 48)
            pos = pos + 1
        else
            break
        end
    end
    mm = 0
    ss = 0
    if pos < n and (mem_byte_read(s, pos) & 255) == 58
        pos = pos + 1
        while pos < n
            d = mem_byte_read(s, pos) & 255
            if d >= 48 and d <= 57
                mm = (mm * 10) + (d - 48)
                pos = pos + 1
            else
                break
            end
        end
        if pos < n and (mem_byte_read(s, pos) & 255) == 58
            pos = pos + 1
            while pos < n
                d = mem_byte_read(s, pos) & 255
                if d >= 48 and d <= 57
                    ss = (ss * 10) + (d - 48)
                    pos = pos + 1
                else
                    break
                end
            end
        end
    end
    return [1, sign * ((hh * 3600) + (mm * 60) + ss), pos]
end

fn _tzif_parse_posix_mrule s pos year
    // Parses `Mm.w.d[/time]` returning [ok, local_sec_in_year_from_epoch, next_pos]
    n = len(s)
    if pos >= n or (mem_byte_read(s, pos) & 255) != 77
        return [0, 0, pos]
    end
    pos = pos + 1
    mo = 0
    while pos < n
        d = mem_byte_read(s, pos) & 255
        if d >= 48 and d <= 57
            mo = (mo * 10) + (d - 48)
            pos = pos + 1
        else
            break
        end
    end
    if pos >= n or (mem_byte_read(s, pos) & 255) != 46 return [0, 0, pos] end
    pos = pos + 1
    wk = 0
    while pos < n
        d = mem_byte_read(s, pos) & 255
        if d >= 48 and d <= 57
            wk = (wk * 10) + (d - 48)
            pos = pos + 1
        else
            break
        end
    end
    if pos >= n or (mem_byte_read(s, pos) & 255) != 46 return [0, 0, pos] end
    pos = pos + 1
    dow = 0
    while pos < n
        d = mem_byte_read(s, pos) & 255
        if d >= 48 and d <= 57
            dow = (dow * 10) + (d - 48)
            pos = pos + 1
        else
            break
        end
    end
    t_sec = 7200 // POSIX default transition time: 02:00:00
    if pos < n and (mem_byte_read(s, pos) & 255) == 47
        tp = _tzif_parse_posix_hms(s, pos + 1, 0)
        if get(tp, 0) == 1
            t_sec = get(tp, 1)
            pos = get(tp, 2)
        end
    end
    if mo < 1 or mo > 12 or wk < 1 or wk > 5 or dow < 0 or dow > 6
        return [0, 0, pos]
    end
    dim = time_days_in_month(year, mo)
    d1_days = time_days_from_civil(year, mo, 1)
    d1_wd = _time_floor_mod(d1_days + 4, 7)
    delta = dow - d1_wd
    if delta < 0 delta = delta + 7 end
    day = 1 + delta + ((wk - 1) * 7)
    while day > dim
        day = day - 7
    end
    trans_local = (time_days_from_civil(year, mo, day) * 86400) + t_sec
    return [1, trans_local, pos]
end

fn _tzif_eval_posix_footer posix_str unix_sec
    // WHY: Evaluates RFC 8536 §3.3.1 POSIX TZ footer for timestamps beyond the last
    // explicit transition table entry (e.g., Y2038+ DST rules like `EST5EDT,M3.2.0,M11.1.0`).
    // Returns [ok, utoff_sec, is_dst, abbr].
    if len(posix_str) == 0 return [0, 0, 0, ""] end
    p1 = _tzif_parse_posix_name(posix_str, 0)
    std_abbr = get(p1, 0)
    pos = get(p1, 1)
    if len(std_abbr) == 0 return [0, 0, 0, ""] end
    o1 = _tzif_parse_posix_hms(posix_str, pos, 1) // POSIX sign is west-positive, invert to east-positive!
    if get(o1, 0) != 1 return [0, 0, 0, ""] end
    std_off = get(o1, 1)
    pos = get(o1, 2)
    if pos >= len(posix_str)
        return [1, std_off, 0, std_abbr]
    end
    p2 = _tzif_parse_posix_name(posix_str, pos)
    dst_abbr = get(p2, 0)
    pos = get(p2, 1)
    if len(dst_abbr) == 0
        return [1, std_off, 0, std_abbr]
    end
    dst_off = std_off + 3600
    if pos < len(posix_str) and (mem_byte_read(posix_str, pos) & 255) != 44
        o2 = _tzif_parse_posix_hms(posix_str, pos, 1)
        if get(o2, 0) == 1
            dst_off = get(o2, 1)
            pos = get(o2, 2)
        end
    end
    if pos >= len(posix_str) or (mem_byte_read(posix_str, pos) & 255) != 44
        return [1, std_off, 0, std_abbr]
    end
    dt_u = time_from_unix_utc(unix_sec)
    yr = dt_u.dt_year
    r1 = _tzif_parse_posix_mrule(posix_str, pos + 1, yr)
    if get(r1, 0) != 1 return [1, std_off, 0, std_abbr] end
    pos2 = get(r1, 2)
    if pos2 >= len(posix_str) or (mem_byte_read(posix_str, pos2) & 255) != 44
        return [1, std_off, 0, std_abbr]
    end
    r2 = _tzif_parse_posix_mrule(posix_str, pos2 + 1, yr)
    if get(r2, 0) != 1 return [1, std_off, 0, std_abbr] end
    // Start transition occurs in standard time; end transition occurs in DST time.
    start_utc = get(r1, 1) - std_off
    end_utc = get(r2, 1) - dst_off
    in_dst = 0
    if start_utc < end_utc
        // Northern hemisphere
        if unix_sec >= start_utc and unix_sec < end_utc
            in_dst = 1
        end
    else
        // Southern hemisphere
        if unix_sec >= start_utc or unix_sec < end_utc
            in_dst = 1
        end
    end
    if in_dst == 1
        return [1, dst_off, 1, dst_abbr]
    end
    return [1, std_off, 0, std_abbr]
end

fn _tzif_lookup_info tz: TzInfo unix_sec
    // Returns [utoff_sec, is_dst, abbr] at unix_sec.
    if tz == 0 or tz.tz_valid != 1
        return [0, 0, "UTC"]
    end
    tcnt = len(tz.tz_trans_times)
    if tcnt == 0
        if len(tz.tz_posix_tz) > 0
            pf = _tzif_eval_posix_footer(tz.tz_posix_tz, unix_sec)
            if get(pf, 0) == 1
                return [get(pf, 1), get(pf, 2), get(pf, 3)]
            end
        end
        if len(tz.tz_tt_utoff) > 0
            return [get(tz.tz_tt_utoff, 0), get(tz.tz_tt_isdst, 0), get(tz.tz_tt_abbrs, 0)]
        end
        return [tz.tz_default_off, 0, ""]
    end
    if unix_sec < get(tz.tz_trans_times, 0)
        // RFC 8536 §3.2: timestamps before first transition use the first non-DST ttinfo
        i = 0
        while i < len(tz.tz_tt_utoff)
            if get(tz.tz_tt_isdst, i) == 0
                return [get(tz.tz_tt_utoff, i), 0, get(tz.tz_tt_abbrs, i)]
            end
            i = i + 1
        end
        return [get(tz.tz_tt_utoff, 0), get(tz.tz_tt_isdst, 0), get(tz.tz_tt_abbrs, 0)]
    end
    if unix_sec >= get(tz.tz_trans_times, tcnt - 1) and len(tz.tz_posix_tz) > 0
        pf2 = _tzif_eval_posix_footer(tz.tz_posix_tz, unix_sec)
        if get(pf2, 0) == 1
            return [get(pf2, 1), get(pf2, 2), get(pf2, 3)]
        end
    end
    // Binary search for largest idx with trans_times[idx] <= unix_sec
    lo = 0
    hi = tcnt - 1
    while lo < hi
        mid = lo + ((hi - lo + 1) / 2)
        if get(tz.tz_trans_times, mid) <= unix_sec
            lo = mid
        else
            hi = mid - 1
        end
    end
    tidx = get(tz.tz_trans_types, lo)
    return [get(tz.tz_tt_utoff, tidx), get(tz.tz_tt_isdst, tidx), get(tz.tz_tt_abbrs, tidx)]
end

fn time_tzif_offset_at tz: TzInfo unix_sec
    // WHY: Returns signed UTC offset in seconds east of UTC (e.g. -18000 EST, -14400 EDT, +21600 +06).
    info = _tzif_lookup_info(tz, unix_sec)
    return get(info, 0)
end

fn time_tzif_is_dst_at tz: TzInfo unix_sec
    info = _tzif_lookup_info(tz, unix_sec)
    return get(info, 1)
end

fn time_tzif_abbr_at tz: TzInfo unix_sec
    info = _tzif_lookup_info(tz, unix_sec)
    return get(info, 2)
end

fn time_from_unix_tz unix_sec tz: TzInfo
    // WHY: Converts Unix epoch seconds into local civil DateTime using parsed TZif DST rules.
    off_sec = time_tzif_offset_at(tz, unix_sec)
    off_min = off_sec / 60
    rem_sec = off_sec - (off_min * 60)
    dt = time_from_unix_offset(unix_sec + rem_sec, off_min)
    return dt
end
