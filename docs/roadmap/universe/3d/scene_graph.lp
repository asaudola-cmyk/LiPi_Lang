@! ============================================================================
@! MAYA UNIVERSE 3D - SCENE GRAPH & ANIMATION SYSTEM
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/3d/physics"

@! Scene Graph Node
@fn scene_node_new(name)
  return {
    name: name,
    parent: 0,
    children: [],
    transform: {
      position: vec3_new(0,0,0),
      rotation: vec3_new(0,0,0), @! Euler angles for simplicity
      scale: vec3_new(1,1,1)
    },
    mesh: 0,
    material: 0,
    physics_body: 0
  }
@end

@fn scene_add_child(parent, child)
  child.parent = parent
  parent.children = parent.children.push(child)
  return parent
@end

@! Compute world transform recursively
@fn scene_compute_world_transform(node, parent_world_matrix)
  @! Compute local matrix from node.transform
  local_matrix = "computed_local_matrix"
  
  @! world_matrix = parent_world_matrix * local_matrix
  world_matrix = "computed_world_matrix"
  
  node.world_matrix = world_matrix
  
  @for child in node.children
    scene_compute_world_transform(child, world_matrix)
  @end
  
  return node
@end

@! Animation Keyframe System
@fn animation_track_new(node, property_path)
  return {
    node: node,
    property: property_path,
    keyframes: [] @! Array of { time: t, value: v }
  }
@end

@fn animation_evaluate(track, current_time)
  @! Linear interpolation between keyframes
  @! find keyframes k1, k2 such that k1.time <= current_time < k2.time
  @! t = (current_time - k1.time) / (k2.time - k1.time)
  @! val = lerp(k1.value, k2.value, t)
  @! apply val to track.node[track.property]
  return 1
@end
