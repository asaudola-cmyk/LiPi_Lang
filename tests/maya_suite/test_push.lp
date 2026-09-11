import "universe/core/collections"
import "universe/core/string"

@fn main()
  println("Creating map...")
  map = { agents: [] }
  println("Map created")
  
  println("Initial len:")
  print_int(map.agents.len())
  
  println("Pushing...")
  map.agents = map.agents.push(42)
  println("Pushed")
  
  println("Final len:")
  print_int(map.agents.len())
  return 0
@end
