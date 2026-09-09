// Test 23: Database Query Pattern — Lipi 2.0
// Demonstrates: record structs, filter/select simulation, join pattern

struct Record
    id
    value
    category

// Create a record
fn make_record id value category
    r = Record()
    r.id = id
    r.value = value
    r.category = category
    return r

// SELECT: return value if id matches, else -1
fn select_by_id records_id records_value target_id
    if records_id == target_id
        return records_value
    return -1

// WHERE: return 1 if value > threshold (filter condition)
fn where_gt value threshold
    if value > threshold
        return 1
    return 0

// Aggregate: sum of values that pass a filter threshold
fn aggregate_sum_gt threshold
    total = 0
    // Simulate a 10-row table: row i has value i * 7
    for i in 1..10
        val = i * 7
        if val > threshold
            total = total + val
    return total

// COUNT: how many rows have value > threshold
fn count_gt threshold
    count = 0
    for i in 1..10
        val = i * 7
        if val > threshold
            count = count + 1
    return count

// JOIN: combine two records by matching id
fn join_records id1 val1 id2 val2
    if id1 == id2
        return val1 + val2
    return -1

// === Queries ===
say "=== Database Query Demo ==="

// Create some records
r1 = make_record 1 100 1
r2 = make_record 2 250 2
r3 = make_record 3 80 1
r4 = make_record 4 400 3

say "Record 1 value:"
say r1.value
say "Record 2 value:"
say r2.value

// SELECT by id simulation
say "Select id=2 (expect 250):"
say select_by_id r2.id r2.value 2

say "Select id=2 from r1 (expect -1):"
say select_by_id r1.id r1.value 2

// WHERE filter
say "Where r2.value > 200:"
say where_gt r2.value 200

say "Where r3.value > 200:"
say where_gt r3.value 200

// Aggregate SUM WHERE value > 35
say "SUM(value) WHERE value > 35 (table: i*7, i=1..10):"
say aggregate_sum_gt 35

// COUNT WHERE value > 35
say "COUNT WHERE value > 35:"
say count_gt 35

// JOIN
say "JOIN id=1 val=100 WITH id=1 val=50 (expect 150):"
say join_records 1 100 1 50

say "JOIN id=1 val=100 WITH id=2 val=50 (expect -1):"
say join_records 1 100 2 50

say "PASS: Test 23 Database Query"
