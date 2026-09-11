@import "crypto_utils/crypto_utils"
@import "logger/logger"

@fn send_signed_request(endpoint: str, payload_id: i64) -> i64 {
    let sig: i64 = simple_hash(payload_id);
    log_info(endpoint);
    return sig;
}

