@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — 3D VECTOR MATH & PRIMITIVES
@! Module: universe/engine3d/vec3.maya
@! Milestone: 3D Raytracing & Physics Engine
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: Fixed-Point 3D Vectors (Scale: 1000), Ray, Sphere, Triangle & AABB
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"

@! ============================================================================
@! 1. 3D VECTOR STRUCTURE & BASIC MATH (Scale: 1000)
@! ============================================================================

@struct Vec3
  x: i64
  y: i64
  z: i64
@end

@struct Ray3D
  origin: Vec3
  direction: Vec3
@end

@struct Sphere3D
  center: Vec3
  radius: i64
  color: i64
@end

@struct Triangle3D
  v0: Vec3
  v1: Vec3
  v2: Vec3
  color: i64
@end

@struct AABB3D
  min_pt: Vec3
  max_pt: Vec3
@end

@fn vec3_new(x, y, z)
  return { x: x, y: y, z: z }
@end

@fn vec3_add(a, b)
  return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z }
@end

@fn vec3_sub(a, b)
  return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z }
@end

@fn vec3_mul_scalar(v, s)
  return { x: (v.x * s) / 1000, y: (v.y * s) / 1000, z: (v.z * s) / 1000 }
@end

@fn vec3_dot(a, b)
  return ((a.x * b.x) + (a.y * b.y) + (a.z * b.z)) / 1000
@end

@fn vec3_cross(a, b)
  cx = ((a.y * b.z) - (a.z * b.y)) / 1000
  cy = ((a.z * b.x) - (a.x * b.z)) / 1000
  cz = ((a.x * b.y) - (a.y * b.x)) / 1000
  return { x: cx, y: cy, z: cz }
@end

@fn vec3_length_sq(v)
  return vec3_dot(v, v)
@end

@fn vec3_sqrt_approx(n)
  @if n <= 0 return 0 @end
  x = n
  y = (x + 1) / 2
  @while y < x
    x = y
    y = (x + (n / x)) / 2
  @end
  return x
@end

@fn vec3_normalize(v)
  l_sq = vec3_length_sq(v)
  l = vec3_sqrt_approx(l_sq * 1000)
  @if l == 0
    return { x: 0, y: 0, z: 0 }
  @end
  return {
    x: (v.x * 1000) / l,
    y: (v.y * 1000) / l,
    z: (v.z * 1000) / l
  }
@end
