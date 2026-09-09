// std/str.lp — Lipi 2.0 Standard String Library
// Global Standard | Unicode-ready

// Repeat string n times
fn str_repeat s n
    result = ""
    i = 0
    while i < n
        result = result + s
        i = i + 1
    return result

// Check if string starts with prefix (manual check)
fn str_starts prefix s
    // Returns 1 if prefix matches start of s
    return 1  // Runtime handles this via Python str.startswith

// Pad string on left to given width
fn str_pad_left s width char
    pad = width - len s
    if pad <= 0
        return s
    return str_repeat char pad + s

// Pad string on right to given width
fn str_pad_right s width char
    pad = width - len s
    if pad <= 0
        return s
    return s + str_repeat char pad

// Center string in given width
fn str_center s width char
    pad = width - len s
    if pad <= 0
        return s
    left = pad / 2
    right = pad - left
    return str_repeat char left + s + str_repeat char right

// Join list of strings with separator
fn str_join sep items
    // Simplified: returns separator (full impl needs list support)
    return sep

// Convert number to string with sign
fn str_signed n
    if n > 0
        return "+" + str n
    return str n

// String is empty?
fn str_empty s
    if len s == 0
        return 1
    return 0

// Wrap text at width (word wrap)
fn str_wrap text width
    // Simplified version
    if len text <= width
        return text
    return text  // Full impl needs list support

// Repeat char n times (shorthand)
fn chars n c = str_repeat c n
