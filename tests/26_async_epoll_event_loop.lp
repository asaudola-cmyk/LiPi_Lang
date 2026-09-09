// Test 26: Async Event Loop — Lipi 2.0 Global Standard

fn process_read fd
    say "READ  fd=" + fd
    return 1

fn process_write fd
    say "WRITE fd=" + fd
    return 2

fn process_error fd
    say "ERROR fd=" + fd
    return -1

fn dispatch_event eid etype
    if etype == 1
        return process_read(eid)
    elif etype == 2
        return process_write(eid)
    else
        return process_error(eid)

say "=== Event Loop ==="
for i in 1..6
    etype = i % 3 + 1
    result = dispatch_event(i, etype)
    say "Event " + i + " result=" + result

say "Event loop done"
say "PASS: Test 26 Async Event Loop"
