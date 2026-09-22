include "universe/core/io.lp"
include "universe/core/string.lp"

fn str_sub_s s start_i end_i
    if start_i < 0
        start_i = 0
    slen = len(s)
    if end_i > slen
        end_i = slen
    if start_i >= end_i
        return ""
    res = ""
    i = start_i
    while i < end_i
        res = res + char_at(s, i)
        i = i + 1
    return res

fn str_trim_start s
    i = 0
    slen = len(s)
    while i < slen and (char_at(s, i) == " " or char_at(s, i) == "\t" or char_at(s, i) == "\r")
        i = i + 1
    if i == 0
        return s
    return str_sub_s(s, i, slen)

fn str_trim_end s
    slen = len(s)
    if slen == 0
        return ""
    i = slen
    while i > 0 and (char_at(s, i - 1) == " " or char_at(s, i - 1) == "\t" or char_at(s, i - 1) == "\r")
        i = i - 1
    return str_sub_s(s, 0, i)

fn str_trim s
    return str_trim_end(str_trim_start(s))

fn starts_with_keyword s word
    wlen = len(word)
    slen = len(s)
    if slen < wlen
        return 0
    i = 0
    while i < wlen
        if char_at(s, i) != char_at(word, i)
            return 0
        i = i + 1
    if slen == wlen
        return 1
    c = char_at(s, wlen)
    if c == " " or c == "(" or c == "{" or c == ":" or c == "\n" or c == "\t" or c == "="
        return 1
    return 0

fn find_symbol_definition_in_text text symbol
    if len(symbol) == 0
        return -1
    tlen = len(text)
    cur_line = 0
    line_start = 0
    i = 0
    while i <= tlen
        is_eol = 0
        if i == tlen
            is_eol = 1
        elif char_at(text, i) == "\n"
            is_eol = 1
            
        if is_eol == 1
            line = str_sub_s(text, line_start, i)
            trimmed = str_trim(line)
            t_len = len(trimmed)
            s_len = len(symbol)
            matched = 0
            
            if starts_with_keyword(trimmed, "fn") == 1
                rem = str_trim(str_sub_s(trimmed, 2, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@fn") == 1
                rem = str_trim(str_sub_s(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "কাজ") == 1
                rem = str_trim(str_sub_s(trimmed, len("কাজ"), t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "struct") == 1
                rem = str_trim(str_sub_s(trimmed, 6, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@struct") == 1
                rem = str_trim(str_sub_s(trimmed, 7, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "let") == 1
                rem = str_trim(str_sub_s(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@let") == 1
                rem = str_trim(str_sub_s(trimmed, 4, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, symbol) == 1
                rem = str_trim(str_sub_s(trimmed, s_len, t_len))
                if len(rem) > 0 and char_at(rem, 0) == "="
                    matched = 1

            if matched == 1
                return cur_line
                
            cur_line = cur_line + 1
            line_start = i + 1
        i = i + 1
        
    return -1

fn main
    source = "let x = 10\nfn calculate_tax rate\n    return rate * 15\nstruct UserProfile\n    id: 1\n    name: \"admin\"\n@fn vector_add_256 a b\n    return a + b\n"
    
    line_x = find_symbol_definition_in_text(source, "x")
    line_tax = find_symbol_definition_in_text(source, "calculate_tax")
    line_user = find_symbol_definition_in_text(source, "UserProfile")
    line_vec = find_symbol_definition_in_text(source, "vector_add_256")
    
    say "x: " + str(line_x)
    say "tax: " + str(line_tax)
    say "user: " + str(line_user)
    say "vec: " + str(line_vec)
    
    if line_x == 0 and line_tax == 1 and line_user == 3 and line_vec == 6
        say "PASS: LSP Go-to-Definition symbol index verified"
    else
        say "FAIL: Mismatch in LSP line indexing"
    return 0

main()
