@import "logger/logger"

@fn http_get(url: str) -> i64 {
    log_info(url);
    return 200;
}

