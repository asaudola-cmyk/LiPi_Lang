// Test 16: File I/O Pattern — Lipi 2.0
// Demonstrates: struct-based file records, path handling, copy/write simulation

// Simulate a file record (path, content, size)
struct FileRecord
    path
    size
    checksum

// Create a file record with a simple checksum (size mod 256)
fn make_file_record path size
    fr = FileRecord()
    fr.path = path
    fr.size = size
    fr.checksum = size % 256
    return fr

// Count lines: size / bytes_per_line
fn count_lines size bytes_per_line
    if bytes_per_line == 0
        return 0
    return size / bytes_per_line

// Simulate file copy (new file = src_size + overhead)
fn file_copy src_size overhead
    return src_size + overhead

// Simulate file write: return bytes written or -1 on error
fn file_write_safe content_size
    if content_size < 0
        return -1
    return content_size

// Create and inspect a file record
log = make_file_record("app.log", 4096)
say "File size:"
say log.size
say "Checksum:"
say log.checksum

// Count lines in a 1024-byte file with 32-byte lines
lines = count_lines(1024, 32)
say "Lines in 1024-byte file (32 bytes/line):"
say lines

// Simulate copy with 8-byte overhead
copied = file_copy(4096, 8)
say "Copied file size:"
say copied

// Write simulation
written = file_write_safe 2048
say "Bytes written:"
say written

// Error case: use variable for negative value
neg1 = 0 - 1
err = file_write_safe neg1
say "Write error code:"
say err

say "PASS: Test 16 File IO"
