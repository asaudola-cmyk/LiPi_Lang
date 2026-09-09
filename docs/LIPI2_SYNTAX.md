# 🌟 লিপি ২.০ — Syntax Design Specification
> **"Text এর মতো লেখো — Computer বুঝবে"**
> Version: 2.0 Draft | লিপি প্রথম ১.০ ভিত্তিক

---

## কেন নতুন Syntax দরকার?

| ভাষা | একটা function লিখতে | noise characters |
|------|---------------------|-----------------|
| **C** | `int add(int a, int b) { return a + b; }` | ৯টি |
| **Java** | `public static int add(int a, int b) { return a + b; }` | ১২টি |
| **Python** | `def add(a, b):\n    return a + b` | ৩টি |
| **Go** | `func add(a int, b int) int { return a + b }` | ৬টি |
| **লিপি ২.০** | `fn add a b\n    return a + b` | **০টি** |

লিপি ২.০ = Python থেকে **৩ গুণ কম** characters।

---

## ✅ মূল নিয়মগুলো (৭টি মাত্র!)

```
১. fn দিয়ে function — কোনো parens নেই, কোনো colon নেই
২. show দিয়ে output — কোনো parens নেই
৩. if/while/for — কোনো colon নেই
৪. Indentation দিয়ে block (Tab বা 4 spaces)
৫. loop N — N বার repeat
৬. for i in 1..10 — range loop
৭. "Hello {name}!" — built-in string interpolation
```

---

## 📖 সম্পূর্ণ Syntax Reference

### ১. Output — দেখানো

```lipi2
// Lipi 2.0                      // Python equivalent
show "Hello World"                // print("Hello World")
show x                            // print(x)
show "Name:" name                 // print("Name:", name)
show "Hello {name}!"              // print(f"Hello {name}!")
show "{x} + {y} = {x + y}"       // print(f"{x} + {y} = {x + y}")
```

### ২. Variables — চলক

```lipi2
// Lipi 2.0                      // Python / JS equivalent
let x = 42                        // x = 42 (Python) or let x = 42 (JS)
let name = "Lipi"                 // name = "Lipi"
let pi = 3.14                     // pi = 3.14
let active = true                 // active = True
let empty = null                  // empty = None

// Constants (immutable)
const MAX = 1000                  // MAX = 1000  (convention only in Python)
const PI = 3141592                // PI = 3.141592
```

### ৩. Functions — কাজ/ফাংশন

```lipi2
// ── Basic function ──
fn greet name                     // def greet(name):
    show "Hello" name             //     print("Hello", name)

// ── Multiple parameters ──
fn add a b                        // def add(a, b):
    return a + b                  //     return a + b

// ── No parameters ──
fn hello                          // def hello():
    show "Hi!"                    //     print("Hi!")

// ── Calling functions ──
greet "World"                     // greet("World")
let result = add 10 32            // result = add(10, 32)
hello                             // hello()
show add 5 7                      // print(add(5, 7))
```

### ৪. Conditions — শর্ত

```lipi2
// ── if / else ──
if age >= 18                      // if age >= 18:
    show "Adult"                  //     print("Adult")
else                              // else:
    show "Minor"                  //     print("Minor")

// ── elif chain ──
if score >= 90                    // if score >= 90:
    show "A+"                     //     print("A+")
elif score >= 80                  // elif score >= 80:
    show "A"                      //     print("A")
elif score >= 70                  // elif score >= 70:
    show "B"                      //     print("B")
else                              // else:
    show "C"                      //     print("C")

// ── Operators ──
if x > 0 and y > 0               // if x > 0 and y > 0:
if name == "Lipi" or x > 10     // if name == "Lipi" or x > 10:
if not active                    // if not active:
```

### ৫. Loops — লুপ

```lipi2
// ── loop N — repeat N times ──
loop 5                            // for _ in range(5):    ← Python verbose!
    show "Hello"                  //     print("Hello")

// ── for i in range ──
for i in 1..10                   // for i in range(1, 11): ← Python confusing!
    show i                        //     print(i)

// ── for with step ──
for i in 0..100 step 10          // for i in range(0, 101, 10):
    show i                        //     print(i)

// ── while loop ──
let i = 0                         // i = 0
while i < 10                      // while i < 10:
    show i                        //     print(i)
    i = i + 1                     //     i += 1

// ── each item in list (foreach) ──
each item in fruits               // for item in fruits:
    show item                     //     print(item)
```

### ৬. Structs — গঠন/Structure

```lipi2
// ── Define ──
struct Point                      // class Point:  (in Python)
    x                             //     x: int
    y                             //     y: int

struct Person
    name
    age
    email

// ── Use ──
let p = Point{}
p.x = 10
p.y = 20
show "Point:" p.x p.y
```

### ৭. Include / Import

```lipi2
include "std/http"                // import std.http  (Python)
include "std/math"                // import math
include "mylib"                   // import mylib
```

### ৮. Comments

```lipi2
// Single line comment             # Python uses #
/* Multi-line
   comment */
```

---

## 🔢 Numbers — সংখ্যা

লিপি ২.০ তে বাংলা এবং ASCII দুই ধরনের সংখ্যাই চলে:

```lipi2
let x = 42          // ASCII digits
let y = ৪২          // Bengali digits — same value!
let z = ৫ + 5       // Mix works too = 10

// Large numbers (readable with underscore)
let population = 1_700_000_000    // 1.7 billion
```

---

## 🌍 Unicode Identifiers

Variable এবং function এর নাম যেকোনো ভাষায় দেওয়া যায়:

```lipi2
// Bengali identifiers
let আমার_নাম = "লিপি"
let বয়স = ২৫

fn স্বাগত নাম
    show "হ্যালো" নাম

// Arabic identifiers (future)
// Chinese identifiers (future)

// Mix is fine too
let userAge = বয়স
```

---

## 🔄 Syntax Comparison — ৬টি ভাষার সাথে তুলনা

### "Hello World" + গুণ + লুপ:

````carousel
```
// 🌟 Lipi 2.0
show "Hello World"
fn multiply a b
    return a * b
loop 5
    show multiply 3 4
```
<!-- slide -->
```python
# Python
print("Hello World")
def multiply(a, b):
    return a * b
for _ in range(5):
    print(multiply(3, 4))
```
<!-- slide -->
```javascript
// JavaScript
console.log("Hello World");
function multiply(a, b) {
    return a * b;
}
for (let i = 0; i < 5; i++) {
    console.log(multiply(3, 4));
}
```
<!-- slide -->
```rust
// Rust
fn main() {
    println!("Hello World");
    fn multiply(a: i32, b: i32) -> i32 { a * b }
    for _ in 0..5 {
        println!("{}", multiply(3, 4));
    }
}
```
<!-- slide -->
```go
// Go
package main
import "fmt"
func multiply(a, b int) int { return a * b }
func main() {
    fmt.Println("Hello World")
    for i := 0; i < 5; i++ {
        fmt.Println(multiply(3, 4))
    }
}
```
<!-- slide -->
```java
// Java
public class Main {
    static int multiply(int a, int b) { return a * b; }
    public static void main(String[] args) {
        System.out.println("Hello World");
        for (int i = 0; i < 5; i++) {
            System.out.println(multiply(3, 4));
        }
    }
}
```
````

---

## 📊 Noise Character Count

| ভাষা | Hello+fn+loop code | `(` `)` `;` `:` `{` `}` count |
|------|-------------------|-------------------------------|
| Java | ~120 chars | **22** |
| JavaScript | ~95 chars | **16** |
| Go | ~110 chars | **10** |
| Rust | ~100 chars | **10** |
| Python | ~70 chars | **6** |
| **লিপি ২.০** | **45 chars** | **0** |

---

## 🛠️ কীভাবে ব্যবহার করবে

```bash
# Install (once)
./scripts/install.sh

# Write code
nano myapp.lp2

# Run with Lipi 2.0 transpiler
python3 /path/to/lipi2.py myapp.lp2 -o myapp

# Or see what it translates to
python3 /path/to/lipi2.py myapp.lp2 --show

# Run directly
./myapp
```

### `scripts/lipi` wrapper এ automatically:
```bash
lipi run myapp.lp      # auto-detects syntax version
lipi run myapp.lp2     # Lipi 2.0 clean syntax
```

---

## 🌐 Multilingual Keywords (Future)

একই program বিভিন্ন ভাষায়:

```lipi2
// English (v2.0)
fn greet name
    show "Hello" name

// Bengali (v1.0, current)
কাজ স্বাগত নাম
    দেখাও "হ্যালো" নাম

// Hindi (v2.0 planned)
// काम स्वागत नाम
//     दिखाओ "नमस्ते" नाम

// Arabic (v2.1 planned)
// دالة ترحيب اسم
//     أظهر "مرحبا" اسم
```

---

## ✅ Design Goals

```
✅ Python থেকে সহজ — কম characters, কম rules
✅ Global — English keywords, ASCII বা Unicode
✅ Zero noise — কোনো unnecessary parens/colons নেই
✅ Readable — যেন English sentence পড়ছি
✅ Universal — বাংলা OR English OR মিশ্র — সবই চলে
✅ Same binary — লিপি ১.০ এর মতো native ELF (not interpreted)
✅ Zero dependency — Python/Node/JVM দরকার নেই runtime এ
```

---

> **লিপি ২.০** — প্রথমে ভাবো, তারপর লেখো। Machine এর জন্য নয়, মানুষের জন্য।
