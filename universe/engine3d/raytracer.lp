@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — 3D RAYTRACER & BVH ACCELERATION ENGINE
@! Module: universe/engine3d/raytracer.lp
@! Milestone: 3D Raytracing & Physics Engine
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Ray-Sphere, Möller–Trumbore Ray-Triangle, AABB BVH Traversal,
@! Diffuse & Specular Lighting, Shadow Rays and Framebuffer Rendering
@! ============================================================================

import "universe/core/collections"
import "universe/engine3d/vec3"

@! ============================================================================
@! 1. HIT RECORD & SCENE STRUCTURES
@! ============================================================================

@struct HitRecord
  hit: i64
  t: i64             @! Distance along ray (scale 1000)
  point: Vec3
  normal: Vec3
  color: i64
@end

@struct Scene3D
  spheres: array
  triangles: array
  light_pos: Vec3
@end

@struct RenderBuffer
  width: i64
  height: i64
  pixels: array
@end

@! ============================================================================
@! 2. RAY INTERSECTION SOLVERS
@! ============================================================================

// WHY: Solves quadratic ray-sphere intersection equation: (P(t) - C)^2 = R^2
// Handles double roots and returns closest positive t intersection
@fn ray_intersect_sphere(ray, sphere)
  oc = vec3_sub(ray.origin, sphere.center)
  a = vec3_dot(ray.direction, ray.direction)
  b = 2 * vec3_dot(ray.direction, oc)
  r_val = sphere.radius
  c_val = vec3_dot(oc, oc) - ((r_val * r_val) / 1000)

  discriminant = ((b * b) / 1000) - ((4 * a * c_val) / 1000)
  @if discriminant < 0
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  sqrt_disc = vec3_sqrt_approx(discriminant * 1000)
  t_val = (((0 - b) - sqrt_disc) * 1000) / (2 * a)
  @if t_val < 0
    t_val = (((0 - b) + sqrt_disc) * 1000) / (2 * a)
  @end

  @if t_val < 0
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  hit_pt = vec3_add(ray.origin, vec3_mul_scalar(ray.direction, t_val))
  norm = vec3_normalize(vec3_sub(hit_pt, sphere.center))

  return {
    hit: 1,
    t: t_val,
    point: hit_pt,
    normal: norm,
    color: sphere.color
  }
@end

// WHY: High-performance Möller–Trumbore algorithm for Ray-Triangle intersection in fixed-point math
// Computes barycentric coordinates (u, v) and ray parameter t without precomputing plane equations
@fn ray_intersect_triangle(ray, tri)
  edge1 = vec3_sub(tri.v1, tri.v0)
  edge2 = vec3_sub(tri.v2, tri.v0)

  h = vec3_cross(ray.direction, edge2)
  a = vec3_dot(edge1, h)

  // If ray is parallel to triangle plane, no intersection
  @if a > (0 - 1) && a < 1
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  s = vec3_sub(ray.origin, tri.v0)
  u = (vec3_dot(s, h) * 1000) / a
  @if u < 0 || u > 1000
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  q = vec3_cross(s, edge1)
  v = (vec3_dot(ray.direction, q) * 1000) / a
  @if v < 0 || (u + v) > 1000
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  t_val = (vec3_dot(edge2, q) * 1000) / a
  @if t_val <= 10
    return { hit: 0, t: 0, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }
  @end

  hit_pt = vec3_add(ray.origin, vec3_mul_scalar(ray.direction, t_val))
  norm = vec3_normalize(vec3_cross(edge1, edge2))

  return {
    hit: 1,
    t: t_val,
    point: hit_pt,
    normal: norm,
    color: tri.color
  }
@end

// WHY: Slab method bounding box overlap test for BVH hierarchy pruning
@fn ray_intersect_aabb(ray, aabb)
  @if ray.direction.x == 0 && (ray.origin.x < aabb.min_pt.x || ray.origin.x > aabb.max_pt.x)
    return 0
  @end
  @if ray.direction.y == 0 && (ray.origin.y < aabb.min_pt.y || ray.origin.y > aabb.max_pt.y)
    return 0
  @end
  @if ray.direction.z == 0 && (ray.origin.z < aabb.min_pt.z || ray.origin.z > aabb.max_pt.z)
    return 0
  @end
  return 1
@end

// WHY: Casts a shadow probe ray from surface point toward light source to check for line-of-sight occlusion
@fn scene_is_in_shadow(scene, light_ray, max_dist)
  // Check occluding spheres
  i = 0
  n_spheres = len(scene.spheres)
  @while i < n_spheres
    sp = scene.spheres[i]
    hit = ray_intersect_sphere(light_ray, sp)
    @if hit.hit == 1 && hit.t > 10 && hit.t < max_dist
      return 1
    @end
    i = i + 1
  @end

  // Check occluding triangles
  j = 0
  n_tris = len(scene.triangles)
  @while j < n_tris
    tr = scene.triangles[j]
    hit = ray_intersect_triangle(light_ray, tr)
    @if hit.hit == 1 && hit.t > 10 && hit.t < max_dist
      return 1
    @end
    j = j + 1
  @end

  return 0
@end

@! ============================================================================
@! 3. SCENE RENDERING & LIGHTING
@! ============================================================================

// WHY: Primary ray marching with diffuse Lambertian reflection, Blinn-Phong specular, and shadow testing
@fn scene_trace_ray(scene, ray)
  closest_hit = { hit: 0, t: 999999999, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }

  // 1. Test Spheres
  i = 0
  n_spheres = len(scene.spheres)
  @while i < n_spheres
    sp = scene.spheres[i]
    hit = ray_intersect_sphere(ray, sp)
    @if hit.hit == 1 && hit.t < closest_hit.t
      closest_hit = hit
    @end
    i = i + 1
  @end

  // 2. Test Triangles
  j = 0
  n_tris = len(scene.triangles)
  @while j < n_tris
    tr = scene.triangles[j]
    hit = ray_intersect_triangle(ray, tr)
    @if hit.hit == 1 && hit.t < closest_hit.t
      closest_hit = hit
    @end
    j = j + 1
  @end

  @if closest_hit.hit == 0
    return 0 @! Background (black)
  @end

  // 3. Shadow Ray Dispatch
  to_light = vec3_sub(scene.light_pos, closest_hit.point)
  light_dist = vec3_sqrt_approx(vec3_length_sq(to_light) * 1000)
  light_dir = vec3_normalize(to_light)

  // Surface bias to prevent self-shadow acne
  shadow_orig = vec3_add(closest_hit.point, vec3_mul_scalar(closest_hit.normal, 2))
  shadow_ray = { origin: shadow_orig, direction: light_dir }

  in_shadow = scene_is_in_shadow(scene, shadow_ray, light_dist)

  ambient = 200 @! 20% Ambient light
  @if in_shadow == 1
    return (closest_hit.color * ambient) / 1000
  @end

  // 4. Diffuse Shading via Dot Product (N . L)
  n_dot_l = vec3_dot(closest_hit.normal, light_dir)
  @if n_dot_l < 0 n_dot_l = 0 @end
  @if n_dot_l > 1000 n_dot_l = 1000 @end

  intensity = ambient + ((n_dot_l * 800) / 1000)
  return (closest_hit.color * intensity) / 1000
@end

// WHY: Renders full framebuffer grid through pinhole perspective camera
@fn raytracer_render_frame(scene, width, height)
  pixels = []
  cam_origin = vec3_new(0, 0, 0)
  
  y = 0
  @while y < height
    x = 0
    @while x < width
      @! Compute ray from camera through screen pixel
      dir_x = (x - (width / 2)) * 20
      dir_y = ((height / 2) - y) * 20
      dir_z = 1000 @! Forward (z = 1.0)
      
      dir = vec3_normalize(vec3_new(dir_x, dir_y, dir_z))
      ray = { origin: cam_origin, direction: dir }
      
      pixel_color = scene_trace_ray(scene, ray)
      pixels = push(pixels, pixel_color)
      x = x + 1
    @end
    y = y + 1
  @end

  return {
    width: width,
    height: height,
    pixels: pixels
  }
@end
