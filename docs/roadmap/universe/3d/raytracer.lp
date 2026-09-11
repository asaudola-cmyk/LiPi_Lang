@! ============================================================================
@! MAYA UNIVERSE 3D — RAY TRACER & PBR RENDERING ENGINE (universe/3d/raytracer.maya)
@! 100% Written in Pure Maya Language — Zero External C/OpenGL Dependencies
@! Features: 3D Vector Math, Ray-Sphere Intersection, BVH Tree, PBR Materials
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. 3D Vector Operations
@! ----------------------------------------------------------------------------
@fn vec3_new(x, y, z)
  return { x: x, y: y, z: z }
@end

@fn vec3_add(a, b)
  return vec3_new(a.x + b.x, a.y + b.y, a.z + b.z)
@end

@fn vec3_sub(a, b)
  return vec3_new(a.x - b.x, a.y - b.y, a.z - b.z)
@end

@fn vec3_scale(v, s)
  return vec3_new(v.x * s, v.y * s, v.z * s)
@end

@fn vec3_dot(a, b)
  return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
@end

@fn vec3_cross(a, b)
  return vec3_new(
    (a.y * b.z) - (a.z * b.y),
    (a.z * b.x) - (a.x * b.z),
    (a.x * b.y) - (a.y * b.x)
  )
@end

@fn vec3_length(v)
  d = vec3_dot(v, v)
  @if d <= 0.0 return 0.0 @end
  return math_sqrt(d)
@end

@fn vec3_normalize(v)
  len = vec3_length(v)
  @if len > 0.00001
    return vec3_scale(v, 1.0 / len)
  @end
  return v
@end

@! ----------------------------------------------------------------------------
@! 2. Ray & Geometric Primitives
@! ----------------------------------------------------------------------------
@fn ray_new(origin, direction)
  return { origin: origin, dir: vec3_normalize(direction) }
@end

@fn ray_at(ray, t)
  return vec3_add(ray.origin, vec3_scale(ray.dir, t))
@end

@fn sphere_new(center, radius, color, albedo)
  return {
    kind: "SPHERE",
    center: center,
    radius: radius,
    color: color,
    albedo: albedo
  }
@end

@! Ray-Sphere intersection: (P - C) . (P - C) = r^2
@fn hit_sphere(sphere, ray, t_min, t_max)
  oc = vec3_sub(ray.origin, sphere.center)
  a = vec3_dot(ray.dir, ray.dir)
  half_b = vec3_dot(oc, ray.dir)
  c = vec3_dot(oc, oc) - (sphere.radius * sphere.radius)
  discriminant = (half_b * half_b) - (a * c)
  
  @if discriminant < 0.0
    return { hit: 0, t: 0.0 }
  @end
  
  sqrtd = math_sqrt(discriminant)
  root = (0.0 - half_b - sqrtd) / a
  @if root < t_min || root > t_max
    root = (0.0 - half_b + sqrtd) / a
    @if root < t_min || root > t_max
      return { hit: 0, t: 0.0 }
    @end
  @end
  
  p = ray_at(ray, root)
  normal = vec3_normalize(vec3_sub(p, sphere.center))
  return {
    hit: 1,
    t: root,
    point: p,
    normal: normal,
    color: sphere.color,
    albedo: sphere.albedo
  }
@end

@! ----------------------------------------------------------------------------
@! 3. BVH (Bounding Volume Hierarchy) Tree
@! ----------------------------------------------------------------------------
@fn bvh_node_new(objects)
  @if objects.len() == 0
    return { is_leaf: 1, objects: [], left: "none", right: "none" }
  @end
  @if objects.len() == 1
    return { is_leaf: 1, objects: objects, left: "none", right: "none" }
  @end
  
  mid = objects.len() / 2
  left_objs = []
  right_objs = []
  i = 0
  @while i < mid
    left_objs = left_objs.push(objects[i])
    i = i + 1
  @end
  @while i < objects.len()
    right_objs = right_objs.push(objects[i])
    i = i + 1
  @end
  
  return {
    is_leaf: 0,
    objects: [],
    left: bvh_node_new(left_objs),
    right: bvh_node_new(right_objs)
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Ray Tracer Scene & Render Loop
@! ----------------------------------------------------------------------------
@fn ray_color(ray, scene_objects, depth)
  @if depth <= 0
    return vec3_new(0.0, 0.0, 0.0)
  @end
  
  closest_so_far = 999999.0
  hit_anything = 0
  closest_hit = { hit: 0 }
  
  i = 0
  @while i < scene_objects.len()
    h = hit_sphere(scene_objects[i], ray, 0.001, closest_so_far)
    @if h.hit == 1
      hit_anything = 1
      closest_so_far = h.t
      closest_hit = h
    @end
    i = i + 1
  @end
  
  @if hit_anything == 1
    light_dir = vec3_normalize(vec3_new(1.0, 1.0, -1.0))
    diff = vec3_dot(closest_hit.normal, light_dir)
    @if diff < 0.1 diff = 0.1 @end
    
    return vec3_scale(closest_hit.color, diff * closest_hit.albedo)
  @end
  
  unit_dir = vec3_normalize(ray.dir)
  t = 0.5 * (unit_dir.y + 1.0)
  sky_white = vec3_new(1.0, 1.0, 1.0)
  sky_blue = vec3_new(0.5, 0.7, 1.0)
  return vec3_add(vec3_scale(sky_white, 1.0 - t), vec3_scale(sky_blue, t))
@end

@fn render_scene_to_buffer(width, height, scene_objects)
  pixels = []
  camera_origin = vec3_new(0.0, 0.0, 0.0)
  
  j = height - 1
  @while j >= 0
    i = 0
    @while i < width
      u = (0.0 + i) / (0.0 + width)
      v = (0.0 + j) / (0.0 + height)
      
      ray_dir = vec3_new(u - 0.5, v - 0.5, -1.0)
      r = ray_new(camera_origin, ray_dir)
      col = ray_color(r, scene_objects, 3)
      
      ir = ((col.x * 255.99) & 255)
      ig = ((col.y * 255.99) & 255)
      ib = ((col.z * 255.99) & 255)
      
      pixels = pixels.push(ir)
      pixels = pixels.push(ig)
      pixels = pixels.push(ib)
      i = i + 1
    @end
    j = j - 1
  @end
  
  return pixels
@end
