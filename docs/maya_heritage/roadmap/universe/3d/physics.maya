@! ============================================================================
@! MAYA UNIVERSE 3D - PHYSICS ENGINE
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! 3D Vector
@fn vec3_new(x, y, z)
  return { x: x, y: y, z: z }
@end

@fn vec3_add(v1, v2)
  return vec3_new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
@end

@fn vec3_scale(v, scalar)
  return vec3_new(v.x * scalar, v.y * scalar, v.z * scalar)
@end

@! Rigid Body
@fn rigid_body_new(mass, position)
  return {
    mass: mass,
    inv_mass: 1.0 / mass,
    position: position,
    velocity: vec3_new(0.0, 0.0, 0.0),
    force: vec3_new(0.0, 0.0, 0.0)
  }
@end

@! Apply Force
@fn physics_apply_force(body, force)
  body.force = vec3_add(body.force, force)
  return body
@end

@! Step simulation (Euler Integration)
@fn physics_step(body, dt)
  @! F = ma => a = F * inv_mass
  accel = vec3_scale(body.force, body.inv_mass)
  
  @! v = v + a*dt
  dv = vec3_scale(accel, dt)
  body.velocity = vec3_add(body.velocity, dv)
  
  @! p = p + v*dt
  dp = vec3_scale(body.velocity, dt)
  body.position = vec3_add(body.position, dp)
  
  @! Clear forces
  body.force = vec3_new(0.0, 0.0, 0.0)
  
  return body
@end

@! Physics World
@fn physics_world_new()
  return {
    gravity: vec3_new(0.0, -9.81, 0.0),
    bodies: []
  }
@end

@fn physics_world_step(world, dt)
  new_bodies = []
  @for body in world.bodies
    @! Apply gravity
    grav_force = vec3_scale(world.gravity, body.mass)
    body = physics_apply_force(body, grav_force)
    
    @! Step body
    body = physics_step(body, dt)
    new_bodies = new_bodies.push(body)
  @end
  
  world.bodies = new_bodies
  return world
@end
