// ==============================================================================
// 👑 LIPI EXAMPLE: WORD COUNTER & TEXT ANALYZER (examples/word_count.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

import "universe/core/string"
import "universe/core/io"

fn count_chars text
    return len(text)

fn count_words text
    count = 0
    in_word = 0
    i = 0
    tlen = len(text)
    while i < tlen
        c = ord(char_at(text, i))
        if c == 32 or c == 10 or c == 9
            if in_word == 1
                count = count + 1
                in_word = 0
        else
            in_word = 1
        i = i + 1
    if in_word == 1
        count = count + 1
    return count

fn count_lines text
    count = 1
    i = 0
    tlen = len(text)
    while i < tlen
        if ord(char_at(text, i)) == 10
            count = count + 1
        i = i + 1
    return count

fn main
    text = "Lipi is Sovereign. Lipi is Pure Silicon.\nLipi speaks Bengali and English.\nEmpowering developers worldwide."
    
    say "=== Lipi Word Counter ==="
    say ""
    say "Text: " + text
    say ""
    say "Statistics:"
    say "  Characters: " + str(count_chars(text))
    say "  Words: " + str(count_words(text))
    say "  Lines: " + str(count_lines(text))
    say "  Uppercase: " + to_upper(text)
    return 0

main()
