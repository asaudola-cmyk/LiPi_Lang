@! Todo list application in Lipi

@struct Todo
  td_id: i64
  td_title: string
  td_done: i64
  td_priority: i64
@end

@impl Todo
  @fn display(self)
    status = "[ ]"
    @if self.td_done == 1
      status = "[x]"
    @end
    priority_str = "medium"
    @if self.td_priority == 1
      priority_str = "high"
    @elif self.td_priority == 3
      priority_str = "low"
    @end
    return status + " #" + int_to_str(self.td_id) + " [" + priority_str + "] " + self.td_title
  @end
  @fn complete(self)
    return Todo { td_id: self.td_id, td_title: self.td_title, td_done: 1, td_priority: self.td_priority }
  @end
@end

@struct TodoList
  tl_todos: array
  tl_next_id: i64
  tl_name: string
@end

@fn todolist_new(name)
  return TodoList { tl_todos: [], tl_next_id: 1, tl_name: name }
@end

@fn todolist_add(list, title, priority)
  todo = Todo { td_id: list.tl_next_id, td_title: title, td_done: 0, td_priority: priority }
  list.tl_todos = list.tl_todos.push(todo)
  list.tl_next_id = list.tl_next_id + 1
  return list
@end

@fn todolist_complete(list, id)
  i = 0
  @while i < list.tl_todos.len()
    todo = list.tl_todos[i]
    @if todo.td_id == id
      list.tl_todos[i] = todo.complete()
    @end
    i = i + 1
  @end
  return list
@end

@fn todolist_display(list)
  println("=== " + list.tl_name + " ===")
  done_count = 0
  i = 0
  @while i < list.tl_todos.len()
    todo = list.tl_todos[i]
    println(todo.display())
    @if todo.td_done == 1
      done_count = done_count + 1
    @end
    i = i + 1
  @end
  println("Progress: " + int_to_str(done_count) + "/" + int_to_str(list.tl_todos.len()))
@end

@fn main()
  list = todolist_new("Lipi Development Tasks")
  
  list = todolist_add(list, "Implement @enum support", 1)
  list = todolist_add(list, "Add @impl struct methods", 1)
  list = todolist_add(list, "Build self-hosted compiler", 1)
  list = todolist_add(list, "Create universe library", 2)
  list = todolist_add(list, "Add TCP socket support", 2)
  list = todolist_add(list, "Build package registry", 3)
  list = todolist_add(list, "Write documentation", 3)
  
  list = todolist_complete(list, 1)
  list = todolist_complete(list, 2)
  list = todolist_complete(list, 3)
  list = todolist_complete(list, 4)
  
  todolist_display(list)
  return 0
@end
