library digital_twin_core;

// Core domain classes
export 'domain/entity.dart';
export 'domain/state.dart';
export 'domain/event.dart';
export 'domain/action.dart';

// Spatial classes
export 'domain/spatial/spatial_model.dart';
export 'domain/spatial/bounds.dart';
export 'domain/spatial/collision_shape.dart';
export 'domain/spatial/placement_request.dart';
export 'domain/spatial/placement_result.dart';
export 'domain/spatial/placement_surface.dart';
export 'domain/spatial/spatial_anchor.dart';
export 'domain/spatial/spatial_relation.dart';

export 'application/spatial/spatial_world.dart';
export 'application/spatial/placement_engine.dart';
export 'application/spatial/collision_detector.dart';
export 'application/spatial/placement_candidate.dart';
export 'application/spatial/surface_placement_strategy.dart';

// Rules engine
export 'domain/rules/i_rule.dart';
export 'domain/rules/rule_engine.dart';

// Simulation classes
export 'application/simulation/simulator.dart';
export 'application/simulation/time_controller.dart';
export 'application/simulation/simulation_context.dart';

// Visualization classes
export 'application/visualization/renderer.dart';
export 'application/visualization/interactive_handler.dart';

// Intelligence & Prediction
export 'domain/intelligence/i_predictor.dart';
export 'domain/intelligence/i_generator.dart';
export 'domain/intelligence/statistical_predictor.dart';

export 'application/intelligence/prediction_manager.dart';
export 'application/intelligence/generation_manager.dart';
export 'application/intelligence/terminal_load_predictor.dart';

// Generation
export 'application/generation/template_generator.dart';
export 'application/generation/port_terminal_generator.dart';

// Abstractions
export 'domain/abstractions/i_domain_entity.dart';
export 'domain/abstractions/i_simulation_object.dart';
export 'domain/abstractions/i_visualization_component.dart';

// Domain factories
export 'factories/domain_factory.dart';

// Domain-specific classes
export 'domains/port/container.dart';
export 'domains/port/terminal.dart';
export 'domains/parking/vehicle.dart';
export 'domains/parking/space.dart';
export 'domains/restaurant/customer.dart';
export 'domains/restaurant/table.dart';
export 'domains/warehouse/item.dart';
export 'domains/warehouse/storage.dart';

// Spatial Candidates (Step 10)
export 'application/spatial/candidates/candidate_generator.dart';
export 'application/spatial/candidates/surface_candidate_generator.dart';
export 'application/spatial/candidates/anchor_candidate_generator.dart';
export 'application/spatial/candidates/composite_candidate_generator.dart';
export 'application/spatial/candidates/neighbor_candidate_generator.dart';

// Spatial Scoring (Step 10 & 11)
export 'application/spatial/scoring/placement_scorer.dart';
export 'application/spatial/scoring/distance_scorer.dart';
export 'application/spatial/scoring/anchor_preference_scorer.dart';
export 'application/spatial/scoring/composite_placement_scorer.dart';
export 'application/spatial/scoring/neighbor_pattern_scorer.dart';

// Spatial Neighbors (Step 11 - Neighbor-Aware Placement)
export 'application/spatial/neighbors/spatial_neighbor.dart';
export 'application/spatial/neighbors/neighbor_analyzer.dart';

// Spatial Relations (Step 12)
export 'domain/spatial/relations/spatial_relationship.dart';
export 'application/spatial/relations/spatial_relation_query.dart';
export 'application/spatial/relations/relation_constraint_resolver.dart';
