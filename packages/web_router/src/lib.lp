@struct Route
  path: string
  handler_id: i64
@end

@fn route_add(path, id)
  return Route { path: path, handler_id: id }
@end

@fn middleware_chain(req)
  return 1
@end
