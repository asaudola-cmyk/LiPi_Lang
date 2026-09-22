// ==============================================================================
// 👑 LIPI EXAMPLE: DATA STRUCTURES (examples/data_structures.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

struct ListNode
    val
    next_ptr

struct BSTNode
    bst_val
    bst_left
    bst_right

fn list_sum values
    total = 0
    i = 0
    vlen = len(values)
    while i < vlen
        total = total + get(values, i)
        i = i + 1
    return total

fn list_reverse arr
    result = list()
    alen = len(arr)
    i = alen - 1
    while i >= 0
        push(result, get(arr, i))
        i = i - 1
    return result

fn bst_insert bst val
    push(bst, val)
    return bst

fn bst_contains bst val
    i = 0
    blen = len(bst)
    while i < blen
        if get(bst, i) == val
            return 1
        i = i + 1
    return 0

fn print_list arr label
    s = label + ": "
    i = 0
    alen = len(arr)
    while i < alen
        if i > 0
            s = s + " -> "
        s = s + str(get(arr, i))
        i = i + 1
    say s

fn main
    say "=== Data Structures in Lipi ==="
    say ""
    
    lst = list()
    push(lst, 1)
    push(lst, 2)
    push(lst, 3)
    push(lst, 4)
    push(lst, 5)
    
    print_list(lst, "Original list")
    say "Sum: " + str(list_sum(lst))
    
    rev = list_reverse(lst)
    print_list(rev, "Reversed list")
    say ""
    
    bst = list()
    bst_insert(bst, 50)
    bst_insert(bst, 30)
    bst_insert(bst, 70)
    bst_insert(bst, 20)
    bst_insert(bst, 40)
    
    say "BST elements: 50, 30, 70, 20, 40"
    say "BST contains 30: " + str(bst_contains(bst, 30))
    say "BST contains 99: " + str(bst_contains(bst, 99))
    return 0

main()
