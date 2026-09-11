@! ============================================================================
@! MAYA UNIVERSE 3D - VULKAN BINDINGS
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! Vulkan Instance
@fn vk_create_instance(app_name)
  return {
    app_name: app_name,
    api_version: "1.3",
    handle: "VK_INSTANCE_HANDLE_MOCK"
  }
@end

@! Physical Device
@fn vk_pick_physical_device(instance)
  return {
    name: "Maya Quantum GPU",
    type: "DISCRETE_GPU",
    handle: "VK_PHYSICAL_DEVICE_HANDLE_MOCK"
  }
@end

@! Logical Device
@fn vk_create_device(physical_device)
  return {
    handle: "VK_DEVICE_HANDLE_MOCK",
    graphics_queue: "QUEUE_0"
  }
@end

@! Command Buffer Recording
@fn vk_begin_command_buffer(cmd_buffer)
  return 1
@end

@fn vk_cmd_draw(cmd_buffer, vertex_count, instance_count, first_vertex, first_instance)
  return 1
@end

@fn vk_end_command_buffer(cmd_buffer)
  return 1
@end
