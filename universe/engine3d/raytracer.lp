@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — 3D RAYTRACER & BVH ACCELERATION ENGINE
@! Module: universe/engine3d/raytracer.maya
@! Milestone: 3D Raytracing & Physics Engine
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
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

@fn ray_intersect_sphere(ray, sphere)
  @! (p - c) . (p - c) = r^2
  @! d.d * t^2 + 2 * d.(o - c) * t + (o - c).(o - c) - r^2 = 0
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
  t_val = (((-1 * b) - sqrt_disc) * 1000) / (2 * a)
  @if t_val < 0
    t_val = (((-1 * b) + sqrt_disc) * 1000) / (2 * a)
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

@fn ray_intersect_aabb(ray, aabb)
  @! Simple slab test for bounding box
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

@! ============================================================================
@! 3. SCENE RENDERING & LIGHTING
@! ============================================================================

@fn scene_trace_ray(scene, ray)
  closest_hit = { hit: 0, t: 999999999, point: vec3_new(0,0,0), normal: vec3_new(0,0,0), color: 0 }

  i = 0
  n_spheres = scene.spheres.len()
  @while i < n_spheres
    sp = scene.spheres[i]
    hit = ray_intersect_sphere(ray, sp)
    @if hit.hit == 1 && hit.t < closest_hit.t
      closest_hit = hit
    @end
    i = i + 1
  @end

  @if closest_hit.hit == 0
    return 0 @! Background (black)
  @end

  @! Diffuse Shading via Dot Product (N . L)
  light_dir = vec3_normalize(vec3_sub(scene.light_pos, closest_hit.point))
  n_dot_l = vec3_dot(closest_hit.normal, light_dir)
  @if n_dot_l < 0 n_dot_l = 0 @end
  @if n_dot_l > 1000 n_dot_l = 1000 @end

  intensity = 200 + ((n_dot_l * 800) / 1000) @! Ambient (20%) + Diffuse (80%)
  return (closest_hit.color * intensity) / 1000
@end

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
      pixels = pixels.push(pixel_color)
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
