import "universe/mobile/mobile"

@fn dump_array_ints(name: string, arr: array)
  println("BEGIN_" + name)
  i = 0
  len = arr.len()
  line = ""
  @while i < len
    b = arr[i] & 255
    line = line + b.to_str() + " "
    @if (i % 64) == 63
      println(line)
      line = ""
    @end
    i = i + 1
  @end
  @if str_len(line) > 0
    println(line)
  @end
  println("END_" + name)
@end

@fn main()
  apk = mobile_build_android_apk("com.maya.mobiletest", "MayaMobileApp")
  dump_array_ints("SO", apk.libmaya_so_bytes)
  dump_array_ints("APK", apk.apk_raw_bytes)
  return 0
@end
