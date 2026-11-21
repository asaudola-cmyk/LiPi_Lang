import "utso/core/collections"
import "utso/core/string"

@struct ProfEntry
    pe_name: string
    pe_calls: i64
    pe_total_us: i64
    pe_min: i64
    pe_max: i64
@end

@struct Profiler
    prf_entries: array
    prf_active: string
    prf_start: i64
@end

@fn profiler_new()
    return Profiler(arr_new(), "", 0)
@end

@fn profiler_begin(pf, name)
    pf.prf_active = name
    pf.prf_start = clock_ms() * 1000
    return 1
@end

@fn profiler_end(pf, name)
    // WHY: Records real elapsed span into matching ProfEntry or appends a new metric entry.
    now_us = clock_ms() * 1000
    dt = now_us - pf.prf_start
    @if dt < 0 dt = 0 @end
    pf.prf_active = ""
    i = 0
    n = pf.prf_entries.len()
    @while i < n
        entry = pf.prf_entries[i]
        @if str_eq(entry.pe_name, name) == 1
            entry.pe_calls = entry.pe_calls + 1
            entry.pe_total_us = entry.pe_total_us + dt
            @if dt < entry.pe_min entry.pe_min = dt @end
            @if dt > entry.pe_max entry.pe_max = dt @end
            return 1
        @end
        i = i + 1
    @end
    pf.prf_entries.push(ProfEntry(name, 1, dt, dt, dt))
    return 1
@end

@fn profiler_report(pf)
    i = 0
    n = pf.prf_entries.len()
    @while i < n
        e = pf.prf_entries[i]
        println("[prof] " + e.pe_name + ": calls=" + to_str(e.pe_calls) + " total_us=" + to_str(e.pe_total_us))
        i = i + 1
    @end
    return n
@end

@fn profiler_reset(pf)
    pf.prf_entries = arr_new()
    return 1
@end

@fn profiler_find(pf, name)
    // WHY: Searches registered profiling entries for matching symbol name using canonical str_eq
    i = 0
    @while i < pf.prf_entries.len()
        entry = pf.prf_entries[i]
        @if str_eq(entry.pe_name, name) == 1
            return entry
        @end
        i = i + 1
    @end
    return 0
@end
