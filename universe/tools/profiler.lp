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
    i = 0
    @while i < pf.prf_entries.len()
        // we assume simple exact match conceptually
        // Maya strings might not support ==
      i = i + 1
    @end
    return 0
@end
