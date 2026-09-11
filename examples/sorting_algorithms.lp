@fn bubble_sort(arr)
  n = arr.len()
  i = 0
  @while i < n
    j = 0
    @while j < n - i - 1
      @if arr[j] > arr[j + 1]
        tmp = arr[j]
        arr[j] = arr[j + 1]
        arr[j + 1] = tmp
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return arr
@end

@fn selection_sort(arr)
  n = arr.len()
  i = 0
  @while i < n
    min_idx = i
    j = i + 1
    @while j < n
      @if arr[j] < arr[min_idx]
        min_idx = j
      @end
      j = j + 1
    @end
    @if min_idx != i
      tmp = arr[i]
      arr[i] = arr[min_idx]
      arr[min_idx] = tmp
    @end
    i = i + 1
  @end
  return arr
@end

@fn print_arr(arr, label)
  s = label + ": ["
  i = 0
  @while i < arr.len()
    @if i > 0
      s = s + ", "
    @end
    s = s + int_to_str(arr[i])
    i = i + 1
  @end
  println(s + "]")
@end

@fn main()
  println("=== Sorting Algorithms in Maya ===")
  data = [64, 34, 25, 12, 22, 11, 90]
  print_arr(data, "Original")
  print_arr(bubble_sort([64, 34, 25, 12, 22, 11, 90]), "Bubble Sort")
  print_arr(selection_sort([64, 34, 25, 12, 22, 11, 90]), "Selection Sort")
  return 0
@end
