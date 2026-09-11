@struct Point
  px: 0
  py: 0
@end

@fn main()
  pt = {
    px: 10,
    py: 20
  }
  @if pt.px == 10 && pt.py == 20
    return 0
  @end
  return 1
@end
