import "tests/fixtures/helpers"

@fn main()
  result = add_numbers(15, 25)
  println(result)

  product = multiply_numbers(6, 7)
  println(product)

  @if result == 40
    println("Import add: PASS")
  @else
    println("Import add: FAIL")
  @end

  @if product == 42
    println("Import multiply: PASS")
  @else
    println("Import multiply: FAIL")
  @end

  return 0
@end
