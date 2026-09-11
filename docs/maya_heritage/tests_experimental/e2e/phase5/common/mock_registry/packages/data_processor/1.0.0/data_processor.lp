@import "math_stats/math_stats"
@import "logger/logger"

@fn process_data_points(p1: i64, p2: i64) -> i64 {
    log_info("Processing dataset points");
    return variance_2(p1, p2);
}

