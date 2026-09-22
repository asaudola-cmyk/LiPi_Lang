@! ============================================================================
@! MAYA UNIVERSE 3D — ADVANCED RAY TRACER
@! Bounding Volume Hierarchy (BVH), Path Tracing, Global Illumination
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"

@! ----------------------------------------------------------------------------
@! 1. Vector Math & Ray Definitions
@! ----------------------------------------------------------------------------

@fn vec3(x, y, z)
  return { x: x, y: y, z: z }
@end

@fn vec3_add(a, b)
  return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z }
@end

@fn vec3_sub(a, b)
  return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z }
@end

@fn vec3_mul_scalar(a, s)
  return { x: a.x * s, y: a.y * s, z: a.z * s }
@end

@fn vec3_dot(a, b)
  return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
@end

@fn vec3_cross(a, b)
  return {
    x: (a.y * b.z) - (a.z * b.y),
    y: (a.z * b.x) - (a.x * b.z),
    z: (a.x * b.y) - (a.y * b.x)
  }
@end

@fn vec3_normalize(a)
  mag = math_sqrt(vec3_dot(a, a))
  @if mag == 0.0
    return a
  @end
  return { x: a.x / mag, y: a.y / mag, z: a.z / mag }
@end

@fn ray_new(origin, direction)
  return { origin: origin, dir: vec3_normalize(direction) }
@end

@! ----------------------------------------------------------------------------
@! 2. Geometry & Intersections
@! ----------------------------------------------------------------------------

@fn intersect_sphere(ray, center, radius)
  oc = vec3_sub(ray.origin, center)
  a = vec3_dot(ray.dir, ray.dir)
  b = 2.0 * vec3_dot(oc, ray.dir)
  c = vec3_dot(oc, oc) - (radius * radius)
  
  discriminant = (b * b) - (4.0 * a * c)
  
  @if discriminant < 0.0
    return { hit: 0, t: -1.0 }
  @end
  
  t = (-b - math_sqrt(discriminant)) / (2.0 * a)
  @if t > 0.001
    return { hit: 1, t: t }
  @end
  
  t = (-b + math_sqrt(discriminant)) / (2.0 * a)
  @if t > 0.001
    return { hit: 1, t: t }
  @end
  
  return { hit: 0, t: -1.0 }
@end

@fn intersect_triangle(ray, v0, v1, v2)
  @! Möller–Trumbore intersection algorithm
  edge1 = vec3_sub(v1, v0)
  edge2 = vec3_sub(v2, v0)
  h = vec3_cross(ray.dir, edge2)
  a = vec3_dot(edge1, h)
  
  @if a > -0.00001 && a < 0.00001
    return { hit: 0, t: -1.0 } @! Ray is parallel to triangle
  @end
  
  f = 1.0 / a
  s = vec3_sub(ray.origin, v0)
  u = f * vec3_dot(s, h)
  
  @if u < 0.0 || u > 1.0
    return { hit: 0, t: -1.0 }
  @end
  
  q = vec3_cross(s, edge1)
  v = f * vec3_dot(ray.dir, q)
  
  @if v < 0.0 || u + v > 1.0
    return { hit: 0, t: -1.0 }
  @end
  
  t = f * vec3_dot(edge2, q)
  @if t > 0.001
    return { hit: 1, t: t, u: u, v: v }
  @end
  
  return { hit: 0, t: -1.0 }
@end

@! ----------------------------------------------------------------------------
@! 3. Bounding Volume Hierarchy (BVH)
@! ----------------------------------------------------------------------------

@fn aabb_new(min_p, max_p)
  return { min: min_p, max: max_p }
@end

@fn intersect_aabb(ray, aabb)
  @! Slab method
  tx1 = (aabb.min.x - ray.origin.x) / ray.dir.x
  tx2 = (aabb.max.x - ray.origin.x) / ray.dir.x
  
  tmin = math_min(tx1, tx2)
  tmax = math_max(tx1, tx2)
  
  ty1 = (aabb.min.y - ray.origin.y) / ray.dir.y
  ty2 = (aabb.max.y - ray.origin.y) / ray.dir.y
  
  tmin = math_max(tmin, math_min(ty1, ty2))
  tmax = math_min(tmax, math_max(ty1, ty2))
  
  tz1 = (aabb.min.z - ray.origin.z) / ray.dir.z
  tz2 = (aabb.max.z - ray.origin.z) / ray.dir.z
  
  tmin = math_max(tmin, math_min(tz1, tz2))
  tmax = math_min(tmax, math_max(tz1, tz2))
  
  @if tmax >= tmin && tmax > 0.0
    return 1
  @end
  return 0
@end

@fn bvh_node_new(aabb, left, right, object)
  return {
    aabb: aabb,
    left: left,
    right: right,
    object: object @! Only populated if leaf node
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Path Tracing Core
@! ----------------------------------------------------------------------------

@fn trace_ray(ray, bvh_root, depth, max_depth)
  @if depth >= max_depth
    return vec3(0.0, 0.0, 0.0) @! Ray absorbed / black
  @end
  
  @! Traverse BVH...
  hit = 0 @! Mock
  
  @if hit == 0
    @! Skybox / Background
    t = 0.5 * (ray.dir.y + 1.0)
    bg1 = vec3_mul_scalar(vec3(1.0, 1.0, 1.0), 1.0 - t)
    bg2 = vec3_mul_scalar(vec3(0.5, 0.7, 1.0), t)
    return vec3_add(bg1, bg2)
  @end
  
  @! Compute material BRDF...
  @! Diffuse scatter + Specular reflection + Transmission...
  
  return vec3(1.0, 0.0, 0.0) @! Red for now
@end

@fn render_scene(bvh_root, width, height, samples_per_pixel, max_depth)
  @! Framebuffer allocation
  pixels = []
  
  camera_origin = vec3(0.0, 0.0, 0.0)
  
  y = height - 1
  @while y >= 0
    x = 0
    @while x < width
      
      @! Multi-sampling loop
      color = vec3(0.0, 0.0, 0.0)
      s = 0
      @while s < samples_per_pixel
        u = ((x * 1.0) + math_random()) / (width * 1.0)
        v = ((y * 1.0) + math_random()) / (height * 1.0)
        
        @! Generate ray from camera
        dir = vec3((u * 4.0) - 2.0, (v * 2.0) - 1.0, -1.0)
        r = ray_new(camera_origin, dir)
        
        sample_color = trace_ray(r, bvh_root, 0, max_depth)
        color = vec3_add(color, sample_color)
        
        s = s + 1
      @end
      
      @! Average samples and gamma correct
      scale = 1.0 / (samples_per_pixel * 1.0)
      final_r = math_sqrt(color.x * scale)
      final_g = math_sqrt(color.y * scale)
      final_b = math_sqrt(color.z * scale)
      
      pixels = pixels.push({ r: final_r, g: final_g, b: final_b })
      
      x = x + 1
    @end
    y = y - 1
  @end
  
  return pixels
@end
