// Lipi 2.0 — Hello World Example
// Global Standard Minimal Syntax
// Run: python3 -m src.runtime main.lp

// Basic output
say "Hello, World!"
say "Welcome to Lipi 2.0"

// Variables
name = "Lipi"
version = 2
say "Language: " + name + " " + version + ".0"
say "Simpler than Python!"

// Functions
fn greet who
    say "Hello, " + who + "!"

greet "World"
greet "Developer"
greet "Universe"

// Loops
repeat 3
    say "Lipi rocks!"

for i in 1..5
    say i

// Conditions
x = 42
if x > 40
    say "x is greater than 40"
elif x > 20
    say "x is greater than 20"
else
    say "x is 20 or less"
