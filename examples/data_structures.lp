@! Linked list and binary tree in Maya

@struct ListNode
  val: i64
  next_ptr: i64
@end

@struct BSTNode
  bst_val: i64
  bst_left: i64
  bst_right: i64
@end

@fn list_sum(values)
  total = 0
  i = 0
  @while i < values.len()
    total = total + values[i]
    i = i + 1
  @end
  return total
@end

@fn list_reverse(arr)
  result = []
  i = arr.len() - 1
  @while i >= 0
    result = result.push(arr[i])
    i = i - 1
  @end
  return result
@end

@fn bst_insert(bst, val)
  bst = bst.push(val)
  return bst
@end

@fn bst_contains(bst, val)
  return array_contains(bst, val)
@end

@fn print_list(arr, label)
  s = label + ": "
  i = 0
  @while i < arr.len()
    @if i > 0
      s = s + " -> "
    @end
    s = s + int_to_str(arr[i])
    i = i + 1
  @end
  println(s)
@end

@fn main()
  println("=== Data Structures in Lipi ===")
  println("")
  
  list = [1, 2, 3, 4, 5]
  print_list(list, "List")
  println("Sum: " + int_to_str(list_sum(list)))
  
  rev = list_reverse(list)
  print_list(rev, "Reversed")
  
  println("")
  bst = []
  bst = bst_insert(bst, 5)
  bst = bst_insert(bst, 3)
  bst = bst_insert(bst, 7)
  bst = bst_insert(bst, 1)
  bst = bst_insert(bst, 4)
  println("BST contains 3: " + int_to_str(bst_contains(bst, 3)))
  println("BST contains 9: " + int_to_str(bst_contains(bst, 9)))
  
  return 0
@end
