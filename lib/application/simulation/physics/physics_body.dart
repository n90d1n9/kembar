import 'package:digital_twin_core/domain/spatial/spatial_model.dart';

/// Represents a physical body in the simulation with mass, velocity, and material properties.
class PhysicsBody {
  final String entityId;
  
  /// Mass in kilograms (0 for static/kinematic bodies)
  final double mass;
  
  /// Current linear velocity (m/s)
  SpatialVector3 velocity;
  
  /// Current angular velocity (rad/s)
  SpatialVector3 angularVelocity;
  
  /// Coefficient of friction (0.0 - 1.0)
  final double friction;
  
  /// Coefficient of restitution (bounciness, 0.0 - 1.0)
  final double restitution;
  
  /// Whether this body is static (immovable)
  final bool isStatic;
  
  /// Whether this body is kinematic (moved by animation/script, not physics)
  final bool isKinematic;
  
  PhysicsBody({
    required this.entityId,
    this.mass = 1.0,
    SpatialVector3? velocity,
    SpatialVector3? angularVelocity,
    this.friction = 0.5,
    this.restitution = 0.3,
    this.isStatic = false,
    this.isKinematic = false,
  })  : velocity = velocity ?? SpatialVector3.zero(),
        angularVelocity = angularVelocity ?? SpatialVector3.zero();
  
  /// Check if this body is affected by physics
  bool get isDynamic => !isStatic && !isKinematic && mass > 0;
  
  /// Apply an impulse to this body
  void applyImpulse(SpatialVector3 impulse) {
    if (!isDynamic) return;
    
    // F = ma, so a = F/m
    // Impulse changes velocity directly: Δv = impulse / mass
    velocity = SpatialVector3(
      velocity.x + impulse.x / mass,
      velocity.y + impulse.y / mass,
      velocity.z + impulse.z / mass,
    );
  }
  
  /// Apply a force over time (accumulates until next step)
  void applyForce(SpatialVector3 force, double deltaTime) {
    if (!isDynamic) return;
    
    // F = ma, so a = F/m
    // Δv = a * Δt = (F/m) * Δt
    final acceleration = SpatialVector3(
      force.x / mass,
      force.y / mass,
      force.z / mass,
    );
    
    velocity = SpatialVector3(
      velocity.x + acceleration.x * deltaTime,
      velocity.y + acceleration.y * deltaTime,
      velocity.z + acceleration.z * deltaTime,
    );
  }
  
  /// Reset velocities
  void resetVelocities() {
    velocity = SpatialVector3.zero();
    angularVelocity = SpatialVector3.zero();
  }
  
  @override
  String toString() => 'PhysicsBody(entity: $entityId, mass: $mass, dynamic: $isDynamic)';
}
