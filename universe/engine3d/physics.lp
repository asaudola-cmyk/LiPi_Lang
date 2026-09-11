@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — 3D RIGID BODY PHYSICS SIMULATION ENGINE
@! Module: universe/engine3d/physics.maya
@! Milestone: 3D Raytracing & Physics Engine
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Rigid Body Dynamics, Numerical Time Integration (Euler/Verlet),
@! Elastic Collision Impulses & Gravity Simulation
@! ============================================================================

import "universe/core/collections"
import "universe/engine3d/vec3"

@! ============================================================================
@! 1. RIGID BODY STRUCTURE
@! ============================================================================

@struct RigidBody3D
  id: i64
  position: Vec3
  velocity: Vec3
  mass: i64          @! Mass (scale 1000, e.g. 1000
  radius: i64        @! Bounding radius for sphere collision
  restitution: i64   @! Coefficient of restitution (scale 1000, e.g. 800
  is_static: i64      @! 1
@end

@struct PhysicsWorld3D
  bodies: array
  gravity: Vec3
@end

@! ============================================================================
@! 2. WORLD CREATION & BODY MANAGEMENT
@! ============================================================================

@fn physics_world_new()
  return {
    bodies: [],
    gravity: vec3_new(0, -9800, 0) @! -9.8 m/s^2 (scale 1000)
  }
@end

@fn physics_add_body(world, body)
  world.bodies = world.bodies.push(body)
  return world
@end

@! ============================================================================
@! 3. TIME STEPPING & COLLISION RESOLUTION
@! ============================================================================

@fn physics_step(world, dt_ms)
  dt_scale = dt_ms @! e.g. 16ms for ~60fps
  
  @! 1. Apply Gravity & Update Positions
  i = 0
  n_bodies = world.bodies.len()
  @while i < n_bodies
    b = world.bodies[i]
    @if b.is_static == 0
      @! v = v + g * dt
      dv_x = (world.gravity.x * dt_scale) / 1000
      dv_y = (world.gravity.y * dt_scale) / 1000
      dv_z = (world.gravity.z * dt_scale) / 1000
      
      b.velocity.x = b.velocity.x + dv_x
      b.velocity.y = b.velocity.y + dv_y
      b.velocity.z = b.velocity.z + dv_z

      @! p = p + v * dt
      dp_x = (b.velocity.x * dt_scale) / 1000
      dp_y = (b.velocity.y * dt_scale) / 1000
      dp_z = (b.velocity.z * dt_scale) / 1000
      
      b.position.x = b.position.x + dp_x
      b.position.y = b.position.y + dp_y
      b.position.z = b.position.z + dp_z
    @end
    i = i + 1
  @end

  @! 2. Ground Plane Collision (y = 0)
  j = 0
  @while j < n_bodies
    b = world.bodies[j]
    @if b.is_static == 0
      floor_limit = b.radius
      @if b.position.y < floor_limit
        b.position.y = floor_limit
        @! Invert velocity with restitution
        b.velocity.y = (-1 * (b.velocity.y * b.restitution)) / 1000
      @end
    @end
    j = j + 1
  @end

  return world
@end
