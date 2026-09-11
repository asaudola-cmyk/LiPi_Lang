import "universe/core/collections"
import "universe/core/string"
import "universe/core/io"
import "universe/ai/tensor"
import "universe/swarm/types"
import "universe/swarm/actor"

@fn test_imports()
  q = queue_new()
  queue_enqueue(q, 42)
  dq = queue_dequeue(q)
  println("Queue dequeued: " + dq.dq_val.to_str())

  t = tensor_zeros([2, 2])
  println("Tensor size: " + t.size.to_str())

  p = pid_new("node_0", 1, 0)
  println("PID: " + pid_to_str(p))

  return 0
@end

@fn main()
  test_imports()
  return 0
@end
