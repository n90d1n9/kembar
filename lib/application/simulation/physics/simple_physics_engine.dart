import 'package:digital_twin_core/application/simulation/physics/physics_body.dart';
import 'package:digital_twin_core/domain/spatial/spatial_model.dart';
import 'package:digital_twin_core/domain/spatial/bounds.dart';

/// Simple Euler integration physics engine for real-time simulation.
/// Handles gravity, collision response, friction, and restitution.
class SimplePhysicsEngine {
  /// Gravity vector (default: Earth gravity -9.8 m/s² on Y axis)
  final SpatialVector3 gravity;
  
  /// Map of entity IDs to their physics bodies
  final Map<String, PhysicsBody> _bodies = {};
  
  /// Damping factor for velocity (air resistance, 0.0-1.0)
  final double damping;
  
  SimplePhysicsEngine({
    SpatialVector3? gravity,
    this.damping = 0.99,
  }) : gravity = gravity ?? SpatialVector3(0, -9.8, 0);
  
  /// Register a physics body
  void addBody(PhysicsBody body) {
    _bodies[body.entityId] = body;
  }
  
  /// Remove a physics body
  void removeBody(String entityId) {
    _bodies.remove(entityId);
  }
  
  /// Get a physics body by entity ID
  PhysicsBody? getBody(String entityId) => _bodies[entityId];
  
  /// Get all dynamic bodies
  Iterable<PhysicsBody> get dynamicBodies => 
      _bodies.values.where((b) => b.isDynamic);
  
  /// Step the physics simulation forward by deltaTime seconds
  void step(double deltaTime, List<SpatialBounds> collidables) {
    // 1. Apply forces (gravity)
    for (final body in _bodies.values) {
      if (!body.isDynamic) continue;
      
      // Apply gravity
      body.applyForce(
        SpatialVector3(
          gravity.x * body.mass,
          gravity.y * body.mass,
          gravity.z * body.mass,
        ),
        deltaTime,
      );
      
      // Apply damping (air resistance)
      body.velocity = SpatialVector3(
        body.velocity.x * damping,
        body.velocity.y * damping,
        body.velocity.z * damping,
      );
    }
    
    // 2. Integrate velocities to update positions
    for (final body in _bodies.values) {
      if (!body.isDynamic && !body.isKinematic) continue;
      
      // Update position based on velocity
      // Note: This would normally update the entity's spatial model
      // For now, we just track the velocity state
    }
    
    // 3. Detect and resolve collisions
    _resolveCollisions(deltaTime, collidables);
  }
  
  /// Resolve collisions between bodies
  void _resolveCollisions(double deltaTime, List<SpatialBounds> collidables) {
    final dynamics = dynamicBodies.toList();
    
    for (int i = 0; i < dynamics.length; i++) {
      final bodyA = dynamics[i];
      final boundsA = _getBoundsForBody(bodyA, collidables);
      if (boundsA == null) continue;
      
      // Check against static/kinematic bodies
      for (final bodyB in _bodies.values) {
        if (bodyB.entityId == bodyA.entityId) continue;
        if (!bodyB.isStatic && !bodyB.isKinematic) continue;
        
        final boundsB = _getBoundsForBody(bodyB, collidables);
        if (boundsB == null) continue;
        
        if (boundsA.intersects(boundsB)) {
          _resolveCollision(bodyA, bodyB, boundsA, boundsB, deltaTime);
        }
      }
      
      // Check against other dynamic bodies
      for (int j = i + 1; j < dynamics.length; j++) {
        final bodyB = dynamics[j];
        final boundsB = _getBoundsForBody(bodyB, collidables);
        if (boundsB == null) continue;
        
        if (boundsA.intersects(boundsB)) {
          _resolveDynamicCollision(bodyA, bodyB, boundsA, boundsB, deltaTime);
        }
      }
    }
  }
  
  /// Resolve collision between dynamic and static/kinematic body
  void _resolveCollision(
    PhysicsBody bodyA,
    PhysicsBody bodyB,
    SpatialBounds boundsA,
    SpatialBounds boundsB,
    double deltaTime,
  ) {
    // Calculate collision normal (simplified - assumes AABB)
    final centerA = boundsA.center;
    final centerB = boundsB.center;
    
    // Determine collision direction
    final dx = centerA.x - centerB.x;
    final dy = centerA.y - centerB.y;
    final dz = centerA.z - centerB.z;
    
    // Find the axis of least penetration
    final overlapX = (boundsA.halfSize.x + boundsB.halfSize.x) - dx.abs();
    final overlapY = (boundsA.halfSize.y + boundsB.halfSize.y) - dy.abs();
    final overlapZ = (boundsA.halfSize.z + boundsB.halfSize.z) - dz.abs();
    
    SpatialVector3 normal;
    double overlap;
    
    if (overlapX < overlapY && overlapX < overlapZ) {
      normal = SpatialVector3(dx > 0 ? 1 : -1, 0, 0);
      overlap = overlapX;
    } else if (overlapY < overlapZ) {
      normal = SpatialVector3(0, dy > 0 ? 1 : -1, 0);
      overlap = overlapY;
    } else {
      normal = SpatialVector3(0, 0, dz > 0 ? 1 : -1);
      overlap = overlapZ;
    }
    
    // Apply restitution (bounciness)
    final restitution = bodyA.restitution * bodyB.restitution;
    
    // Reflect velocity along normal
    final dot = bodyA.velocity.x * normal.x + 
                bodyA.velocity.y * normal.y + 
                bodyA.velocity.z * normal.z;
    
    if (dot < 0) {
      bodyA.velocity = SpatialVector3(
        bodyA.velocity.x - (1 + restitution) * dot * normal.x,
        bodyA.velocity.y - (1 + restitution) * dot * normal.y,
        bodyA.velocity.z - (1 + restitution) * dot * normal.z,
      );
      
      // Apply friction
      final friction = bodyA.friction * bodyB.friction;
      bodyA.velocity = SpatialVector3(
        bodyA.velocity.x * (1 - friction),
        bodyA.velocity.y * (1 - friction),
        bodyA.velocity.z * (1 - friction),
      );
    }
    
    // Separate bodies to prevent interpenetration
    // (In a real implementation, this would update the entity's position)
  }
  
  /// Resolve collision between two dynamic bodies
  void _resolveDynamicCollision(
    PhysicsBody bodyA,
    PhysicsBody bodyB,
    SpatialBounds boundsA,
    SpatialBounds boundsB,
    double deltaTime,
  ) {
    // Similar to above but affects both bodies
    final centerA = boundsA.center;
    final centerB = boundsB.center;
    
    final dx = centerA.x - centerB.x;
    final dy = centerA.y - centerB.y;
    final dz = centerA.z - centerB.z;
    
    final overlapX = (boundsA.halfSize.x + boundsB.halfSize.x) - dx.abs();
    final overlapY = (boundsA.halfSize.y + boundsB.halfSize.y) - dy.abs();
    final overlapZ = (boundsA.halfSize.z + boundsB.halfSize.z) - dz.abs();
    
    SpatialVector3 normal;
    
    if (overlapX < overlapY && overlapX < overlapZ) {
      normal = SpatialVector3(dx > 0 ? 1 : -1, 0, 0);
    } else if (overlapY < overlapZ) {
      normal = SpatialVector3(0, dy > 0 ? 1 : -1, 0);
    } else {
      normal = SpatialVector3(0, 0, dz > 0 ? 1 : -1);
    }
    
    // Calculate relative velocity
    final relVel = SpatialVector3(
      bodyA.velocity.x - bodyB.velocity.x,
      bodyA.velocity.y - bodyB.velocity.y,
      bodyA.velocity.z - bodyB.velocity.z,
    );
    
    final dot = relVel.x * normal.x + relVel.y * normal.y + relVel.z * normal.z;
    
    if (dot < 0) {
      final restitution = bodyA.restitution * bodyB.restitution;
      final totalMass = bodyA.mass + bodyB.mass;
      
      // Impulse scalar
      final impulse = -(1 + restitution) * dot / (1/bodyA.mass + 1/bodyB.mass);
      
      // Apply impulse to both bodies
      final impulseVec = SpatialVector3(
        impulse * normal.x / totalMass,
        impulse * normal.y / totalMass,
        impulse * normal.z / totalMass,
      );
      
      bodyA.applyImpulse(SpatialVector3(
        impulseVec.x * bodyB.mass,
        impulseVec.y * bodyB.mass,
        impulseVec.z * bodyB.mass,
      ));
      
      bodyB.applyImpulse(SpatialVector3(
        -impulseVec.x * bodyA.mass,
        -impulseVec.y * bodyA.mass,
        -impulseVec.z * bodyA.mass,
      ));
    }
  }
  
  SpatialBounds? _getBoundsForBody(PhysicsBody body, List<SpatialBounds> collidables) {
    // In a real implementation, this would look up the entity's current bounds
    // For now, return null (would need entity-to-bounds mapping)
    return null;
  }
}
