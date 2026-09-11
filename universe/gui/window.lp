@! Window abstraction

@struct Window
    title
    width
    height
    is_open
@end

@struct Event
    kind
    key
    x
    y
@end

@fn window_new(title, width, height)
    win = Window()
    win.title = title
    win.width = width
    win.height = height
    win.is_open = 1
    return win
@end

@fn window_close(win)
    win.is_open = 0
    return win
@end

@fn window_poll_event(win)
    ev = Event()
    ev.kind = "none"
    ev.key = ""
    ev.x = 0
    ev.y = 0
    return ev
@end

@fn window_is_open(win)
    return win.is_open
@end

@fn window_clear(win, color)
    return 1
@end

@fn window_draw_rect(win, x, y, w, h, color)
    return 1
@end

@fn window_draw_text(win, text, x, y, color)
    return 1
@end

@fn window_present(win)
    return 1
@end
