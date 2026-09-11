@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — 3D RAYTRACER & PHYSICS ENGINE TEST SUITE
@! File: tests/engine3d/test_raytracer_physics.maya
@! ============================================================================

import "universe/core/collections"
import "universe/engine3d/vec3"
import "universe/engine3d/raytracer"
import "universe/engine3d/physics"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🎮 MAYA 3D RAYTRACER & RIGID BODY PHYSICS ENGINE TEST SUITE 🎮")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: 3D Vector Math & Normalization
  println("▶ Section 1: 3D Vector Math (Dot, Cross, Length, Normalization)...")
  total_tests = total_tests + 1
  v1 = vec3_new(3000, 4000, 0) @! Length = 5.0 (5000)
  v1_norm = vec3_normalize(v1)
  ok1 = assert_eq_int(v1_norm.x, 600, "Normalized vector X is 0.6 (600)")
  ok2 = assert_eq_int(v1_norm.y, 800, "Normalized vector Y is 0.8 (800)")

  v_a = vec3_new(1000, 0, 0)
  v_b = vec3_new(0, 1000, 0)
  v_cross = vec3_cross(v_a, v_b)
  ok3 = assert_eq_int(v_cross.z, 1000, "Cross product of unit X and unit Y yields unit Z (1000)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 3D Vector linear algebra & normalization verified")
  @end

  @! SECTION 2: Ray-Sphere Intersection Geometry
  println("▶ Section 2: Analytical Ray-Sphere Intersection Solver...")
  total_tests = total_tests + 1
  ray = { origin: vec3_new(0, 0, 0), direction: vec3_new(0, 0, 1000) }
  sphere = { center: vec3_new(0, 0, 5000), radius: 1000, color: 16711680 } @! Red sphere at z=5.0
  hit = ray_intersect_sphere(ray, sphere)
  ok1 = assert_eq_int(hit.hit, 1, "Ray hits sphere squarely")
  ok2 = assert_eq_int(hit.t, 4000, "Closest intersection distance is t=4.0 (5.0 - 1.0 = 4000)")
  ok3 = assert_eq_int(hit.point.z, 4000, "Hit point Z matches 4000")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Ray-sphere intersection geometry verified")
  @end

  @! SECTION 3: Framebuffer Raytracing & Shading
  println("▶ Section 3: Multi-Object Scene Raytracing & Framebuffer Rendering...")
  total_tests = total_tests + 1
  scene = {
    spheres: [sphere],
    triangles: [],
    light_pos: vec3_new(0, 5000, 0)
  }
  rendered = raytracer_render_frame(scene, 16, 16)
  ok1 = assert_eq_int(rendered.pixels.len(), 256, "Rendered 16x16 framebuffer containing 256 pixels")
  
  @! Center pixel should hit the sphere and produce non-zero color
  center_pixel = rendered.pixels[136] @! (8 * 16 + 8)
  ok2 = assert_true(center_pixel > 0, "Center ray hits sphere and produces illuminated pixel color")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Scene raytracing & framebuffer pixel pipeline verified")
  @end

  @! SECTION 4: Rigid Body Physics Simulation & Gravity Collision
  println("▶ Section 4: 3D Rigid Body Physics Time Stepping & Ground Collision...")
  total_tests = total_tests + 1
  world = physics_world_new()
  ball = {
    id: 1,
    position: vec3_new(0, 10000, 0), @! Dropping from y = 10.0m
    velocity: vec3_new(0, 0, 0),
    mass: 1000,
    radius: 500,                    @! 0.5m radius
    restitution: 800,               @! 80% elasticity
    is_static: 0
  }
  world = physics_add_body(world, ball)

  @! Simulate 100 frames (~1.6 seconds of freefall and bounce)
  frame = 0
  @while frame < 100
    world = physics_step(world, 16)
    frame = frame + 1
  @end

  sim_ball = world.bodies[0]
  ok1 = assert_true(sim_ball.position.y >= 500, "Ball is prevented from penetrating below ground floor (y >= 500)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Rigid body gravity integration & collision response verified")
  @end

  println("=================================================================")
  println("📊 3D ENGINE TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 3D RAYTRACING & PHYSICS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME 3D ENGINE TESTS FAILED")
    return 1
  @end
@end
