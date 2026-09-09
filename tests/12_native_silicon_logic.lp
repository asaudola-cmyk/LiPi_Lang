// Test 12: Native Silicon Logic — Lipi 2.0
// Demonstrates: bitwise operations, bit manipulation patterns, flag registers

// Bitwise AND: mask lowest 4 bits
fn low_nibble x
    return x % 16   // x & 0x0F equivalent

// Bitwise shift left by 1 (multiply by 2)
fn shift_left x
    return x * 2

// Bitwise shift right by 1 (integer divide by 2)
fn shift_right x
    return x / 2

// Check if a bit at position pos is set (pos 0 = LSB)
fn bit_set x pos
    mask = 1
    i = 0
    while i < pos
        mask = mask * 2
        i = i + 1
    remainder = x / mask
    if remainder % 2 == 1
        return 1
    return 0

// Count set bits (popcount) in a value (up to 16 bits)
fn popcount x
    count = 0
    i = 0
    while i < 16
        if x % 2 == 1
            count = count + 1
        x = x / 2
        i = i + 1
    return count

// Reverse the lowest 8 bits
fn reverse_byte x
    result = 0
    i = 0
    while i < 8
        result = result * 2
        if x % 2 == 1
            result = result + 1
        x = x / 2
        i = i + 1
    return result

say "Low nibble of 0xAB (171):"
say low_nibble 171

say "Shift left 5:"
say shift_left 5

say "Shift right 20:"
say shift_right 20

say "Bit 3 set in 0b1000 (8):"
say bit_set 8 3

say "Bit 0 set in 8:"
say bit_set 8 0

say "Popcount of 255:"
say popcount 255

say "Popcount of 170 (0b10101010):"
say popcount 170

say "Reverse byte of 1 (should be 128):"
say reverse_byte 1

say "PASS: Test 12 Silicon Logic"
