// ==============================================================================
// 👑 LIPI EXAMPLE: TODO APPLICATION (examples/todo_app.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

struct Todo
    td_id
    td_title
    td_done
    td_priority

fn todo_new id title prio
    t = Todo()
    t.td_id = id
    t.td_title = title
    t.td_done = 0
    t.td_priority = prio
    return t

fn todo_display t
    status = "[ ]"
    if t.td_done == 1
        status = "[x]"
    prio_str = "medium"
    if t.td_priority == 1
        prio_str = "high"
    elif t.td_priority == 3
        prio_str = "low"
    return status + " #" + str(t.td_id) + " [" + prio_str + "] " + t.td_title

struct TodoList
    tl_todos
    tl_next_id
    tl_name

fn todolist_new name
    tl = TodoList()
    tl.tl_todos = list()
    tl.tl_next_id = 1
    tl.tl_name = name
    return tl

fn todolist_add list title priority
    todo = todo_new(list.tl_next_id, title, priority)
    list.tl_next_id = list.tl_next_id + 1
    push(list.tl_todos, todo)
    return todo

fn todolist_complete list id
    i = 0
    tlen = len(list.tl_todos)
    while i < tlen
        t = get(list.tl_todos, i)
        if t.td_id == id
            t.td_done = 1
            return 1
        i = i + 1
    return 0

fn todolist_print list
    say "=== " + list.tl_name + " ==="
    say ""
    i = 0
    tlen = len(list.tl_todos)
    while i < tlen
        t = get(list.tl_todos, i)
        say "  " + todo_display(t)
        i = i + 1
    say ""

fn main
    app = todolist_new("Sprint 1 Tasks")
    
    todolist_add(app, "Implement Pure Silicon ELF emitter", 1)
    todolist_add(app, "Create Lipi standard library", 1)
    todolist_add(app, "Build CLI runner and REPL", 2)
    todolist_add(app, "Write comprehensive test suites", 1)
    todolist_add(app, "Deploy documentation website", 3)
    
    todolist_print(app)
    
    say "Completing tasks #1 and #2..."
    say ""
    todolist_complete(app, 1)
    todolist_complete(app, 2)
    
    todolist_print(app)
    say "All systems operational."
    return 0

main()
