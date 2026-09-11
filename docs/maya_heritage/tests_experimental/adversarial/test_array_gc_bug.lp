import "universe/core/collections"
import "universe/core/string"

@struct Item
  name: string
@end

@fn make_items() -> array
  arr = []
  i = 0
  @while i < 10
    it = { name: "item_" + i.to_str() }
    arr = arr.push(it)
    i = i + 1
  @end
  return arr
@end

@fn pollute_heap()
  @! Allocate enough memory to trigger GC collection
  k = 0
  @while k < 5000
    tmp = "garbage_string_allocation_number_" + k.to_str()
    k = k + 1
  @end
@end

@fn main()
  println("Step 1: Create array of 10 items")
  items = make_items()

  println("Step 2: Pollute heap to trigger GC")
  pollute_heap()

  println("Step 3: Access items from array")
  j = 0
  @while j < 10
    item = items[j]
    println("Item " + j.to_str() + ": " + item.name)
    j = j + 1
  @end

  println("Success!")
  return 0
@end
