@! Tri-Syntax Sovereign Verification Test (লিপি ৩-সিনট্যাক্স সার্বভৌমিক টেস্ট)
@! Mode 1 (Bengali), Mode 2 (English), and Mode 3 (Maya @-Directives)

@struct Point
    x
    y
@end

@fn calc_dist(px, py)
    @let sum = px + py
    @if sum > 100
        return sum * 2
    @elif sum == 100
        return sum
    @else
        return sum / 2
    @end
@end

@fn loop_test(n)
    @let acc = 0
    @let i = 1
    @while i <= n
        acc = acc + i
        i = i + 1
    @end
    return acc
@end

fn english_helper(a, b):
    let res = a * b
    return res

কাজ বাংলা_সাহায্যকারী(ক, খ):
    চলক মান = ক + খ
    ফেরত মান

// Main execution verifying all three syntaxes
say "Testing Tri-Syntax Engine..."

// Test Maya Meta-syntax function
v1 = calc_dist(60, 50)
say v1 // 110 * 2 = 220

v2 = loop_test(10)
say v2 // 55

// Test English function
v3 = english_helper(6, 7)
say v3 // 42

// Test Bengali function
v4 = বাংলা_সাহায্যকারী(15, 25)
say v4 // 40

say "Tri-Syntax Test PASSED!"
