import "universe/engine3d/vec3"
import "universe/engine3d/raytracer"
import "universe/engine3d/physics"

@fn main()
  println("--- 3D Engine & Raytracer Test Suite ---")

  // 1. Vector Operations
  v1 = vec3_new(1000, 0, 0)
  v2 = vec3_new(0, 1000, 0)
  v_cross = vec3_cross(v1, v2)
  @if v_cross.z != 1000
    println("FAIL: vec3_cross")
    return 1
  @end
  println("PASS: vec3_cross")

  v_dot = vec3_dot(v1, v2)
  @if v_dot != 0
    println("FAIL: vec3_dot")
    return 1
  @end
  println("PASS: vec3_dot")

  // 2. Ray-Sphere Intersection
  ray = { origin: vec3_new(0, 0, 0), direction: vec3_new(0, 0, 1000) }
  sphere = { center: vec3_new(0, 0, 5000), radius: 1000, color: 255 }
  hit_s = ray_intersect_sphere(ray, sphere)
  @if hit_s.hit != 1 || hit_s.t != 4000
    println("FAIL: ray_intersect_sphere")
    return 1
  @end
  println("PASS: ray_intersect_sphere")

  // 3. Möller–Trumbore Ray-Triangle Intersection
  tri = {
    v0: vec3_new(0 - 1000, 0 - 1000, 3000),
    v1: vec3_new(1000, 0 - 1000, 3000),
    v2: vec3_new(0, 1000, 3000),
    color: 500
  }
  hit_t = ray_intersect_triangle(ray, tri)
  @if hit_t.hit != 1 || hit_t.t != 3000
    println("FAIL: ray_intersect_triangle")
    return 1
  @end
  println("PASS: ray_intersect_triangle (Möller–Trumbore)")

  // 4. Shadow Ray & Scene Shading
  scene = {
    spheres: [sphere],
    triangles: [tri],
    light_pos: vec3_new(0, 5000, 0)
  }
  color_val = scene_trace_ray(scene, ray)
  @if color_val <= 0
    println("FAIL: scene_trace_ray")
    return 1
  @end
  println("PASS: scene_trace_ray")

  // 5. Framebuffer Rendering
  frame = raytracer_render_frame(scene, 4, 4)
  @if len(frame.pixels) != 16
    println("FAIL: raytracer_render_frame")
    return 1
  @end
  println("PASS: raytracer_render_frame")

  println("=== ALL 3D ENGINE TESTS PASSED ===")
  return 0
@end
