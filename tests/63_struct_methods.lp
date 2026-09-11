// ==============================================================================
// 👑 LIPI ADVANCED LANGUAGE TEST: OBJECT-ORIENTED STRUCT METHODS & PEEPHOLE (63)
// ⚡ 100% Pure Lipi 2.0 | Zero Libc | Zero External Runtime | Direct Silicon
//
// WHY: Validates first-class OOP struct method declarations (fn Struct.method self args)
// and caller invocation (obj.method(args)) with direct AMD64 register passing.
// ==============================================================================

struct Point
    x
    y

// OOP Method on Point: translates to lipi_fn_Point_set_xy with self in rdi
fn Point.set_xy self new_x new_y
    self.x = new_x
    self.y = new_y
    return 1

// OOP Method to calculate squared Euclidean distance
fn Point.dist_sq self other
    dx = self.x - other.x
    dy = self.y - other.y
    return (dx * dx) + (dy * dy)

say "─── Testing Advanced Lipi Struct Methods & OOP ───"

p1 = Point()
p1.set_xy(10, 20)

p2 = Point()
p2.set_xy(13, 24)

// Calculate squared distance: (13-10)^2 + (24-20)^2 = 3^2 + 4^2 = 9 + 16 = 25
dsq = p1.dist_sq(p2)

say "P1 coordinates: x=" + str(p1.x) + " y=" + str(p1.y)
say "P2 coordinates: x=" + str(p2.x) + " y=" + str(p2.y)
say "Squared distance between P1 and P2: " + str(dsq)

if dsq == 25
    say "✔ PASS: Struct methods and OOP invocation verified (dsq == 25)"
else
    say "❌ FAIL: Expected dsq == 25, got " + str(dsq)
    exit(1)

say "🎉 TEST 63 STRUCT METHODS PASSED!"
