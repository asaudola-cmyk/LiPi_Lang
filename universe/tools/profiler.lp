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
    pf.prf_start = 0
    return 1
@end

@fn profiler_end(pf, name)
    pf.prf_active = ""
    return 1
@end

@fn profiler_report(pf)
    return pf.prf_entries.len()
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
