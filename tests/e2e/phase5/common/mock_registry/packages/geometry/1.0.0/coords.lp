@struct Point {
    x: i64,
    y: i64,
}

@fn make_point(px: i64, py: i64) -> {
    return { x: px, y: py };
}

@fn manhattan_dist(p1: Point, p2: Point) -> i64 {
    let dx: i64 = p1.x - p2.x;
    if dx < 0 { dx = -dx; }
    let dy: i64 = p1.y - p2.y;
    if dy < 0 { dy = -dy; }
    return dx + dy;
}

