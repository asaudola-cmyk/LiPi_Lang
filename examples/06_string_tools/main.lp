// String Tools — Lipi 2.0 Example
// Demonstrates string builtins: upper, lower, trim, split, contains, etc.

fn count_chars s ch
    count = 0
    i = 0
    while i < len(s)
        if char_at(s, i) == ch
            count = count + 1
        i = i + 1
    return count

fn reverse_str s
    result = ""
    i = len(s) - 1
    while i >= 0
        result = result + char_at(s, i)
        i = i - 1
    return result

fn is_palindrome s
    s = lower(s)
    rev = reverse_str(s)
    if s == rev
        return 1
    return 0

fn word_count s
    words = split(s)
    return len(words)

say "=== String Tools ==="
say ""
say "Basic operations:"
say upper("hello world")
say lower("LIPI IS AWESOME")
say trim("   spaces around   ")
say replace("I love Python", "Python", "Lipi")

say ""
say "Analysis of 'Hello World from Lipi':"
text = "Hello World from Lipi"
say "  Length:   " + len(text)
say "  Words:    " + word_count(text)
say "  Upper:    " + upper(text)
say "  Lower:    " + lower(text)
say "  Contains 'Lipi': " + contains(text, "Lipi")
say "  Starts 'Hello':  " + starts_with(text, "Hello")
say "  Ends 'Lipi':     " + ends_with(text, "Lipi")

say ""
say "Character operations:"
say "  char_at('hello', 1) = " + char_at("hello", 1)
say "  index_of('hello world', 'world') = " + index_of("hello world", "world")
say "  count 'l' in 'hello world' = " + count_chars("hello world", "l")

say ""
say "Palindrome check:"
words_to_check = list("racecar", "hello", "level", "lipi", "madam")
for w in words_to_check
    if is_palindrome(w) == 1
        say "  " + w + " → palindrome ✓"
    else
        say "  " + w + " → not palindrome"

say ""
say "Reverse strings:"
say "  " + reverse_str("Hello, World!")
say "  " + reverse_str("Lipi First 1.0")
say "  " + reverse_str("racecar")
