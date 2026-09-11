// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: PASS: large dynamic workload
// @! EXPECT_EXIT: 0

@infinity_rule "ACCUM_STEP" => "acc = acc + i ;" ;
@infinity_rule "STEP_LOOP" => "@while i < 100" ;
@infinity_rule "END_LOOP" => "@end" ;

@fn main()
  acc = 0
  i = 0
  STEP_LOOP
    ACCUM_STEP
    i = i + 1
  END_LOOP
  
  @if acc == 4950
    println("PASS: large dynamic workload")
    return 0
  @else
    println("FAIL: large dynamic workload")
    return 1
  @end
@end
