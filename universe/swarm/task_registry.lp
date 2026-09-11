@! ============================================================================
@! MAYA SWARM — TASK REGISTRY & INVOCATION DISPATCHER (universe/swarm/task_registry.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Maps String Identifiers to Executable Function Pointers Across Cluster Nodes
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/swarm/types"

@struct TaskEntry
  name: string
  func_ptr: i64
@end

@struct TaskRegistry
  tasks: array
@end

@fn task_registry_new()
  return { tasks: [] }
@end

@fn task_registry_register(reg, name, func_ptr)
  i = 0
  num_items = reg.tasks.len()
  updated = []
  found = 0
  @while i < num_items
    t = reg.tasks[i]
    @if t.name == name
      updated = updated.push({ name: name, func_ptr: func_ptr })
      found = 1
    @else
      updated = updated.push(t)
    @end
    i = i + 1
  @end
  @if found == 0
    updated = updated.push({ name: name, func_ptr: func_ptr })
  @end
  return { tasks: updated }
@end

@fn task_registry_get(reg, name)
  i = 0
  num_items = reg.tasks.len()
  @while i < num_items
    t = reg.tasks[i]
    @if t.name == name
      return { found: 1, func_ptr: t.func_ptr }
    @end
    i = i + 1
  @end
  return { found: 0, func_ptr: 0 }
@end

@fn task_registry_has(reg, name)
  i = 0
  num_items = reg.tasks.len()
  @while i < num_items
    t = reg.tasks[i]
    @if t.name == name
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn task_registry_invoke(reg, name, arg)
  res = task_registry_get(reg, name)
  @if res.found == 0
    msg = string_concat("[TaskRegistry] Error: Task not registered: ", name)
    println(msg)
    return 0
  @end
  fp = res.func_ptr
  return fp(arg)
@end

@struct GlobalTaskRegistryHolder
  instance: TaskRegistry
@end

@fn _get_global_holder()
  return { instance: task_registry_new() }
@end

@fn swarm_global_registry()
  return task_registry_new()
@end