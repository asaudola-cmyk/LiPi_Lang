@fn json_serialize(obj)
  return "{ \"status\": \"ok\" }"
@end

@fn json_validate(str)
  @if str == "{}"
    return 1
  @else
    return 0
  @end
@end

@fn json_query(str, path)
  return "result"
@end
