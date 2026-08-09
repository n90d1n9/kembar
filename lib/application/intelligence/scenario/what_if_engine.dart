import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/application/simulation/simulator.dart';

/// Represents a modified scenario for what-if analysis.
class ScenarioVariant {
  final String id;
  final String name;
  final Map<String, dynamic> modifications;
  final TwinState? initialState;

  ScenarioVariant({
    required this.id,
    required this.name,
    required this.modifications,
    this.initialState,
  });

  @override
  String toString() => 'ScenarioVariant($name, ${modifications.length} modifications)';
}

/// Runs parallel simulations with modified variables to compare outcomes.
class WhatIfEngine {
  final Simulator simulator;
  final int maxConcurrentSimulations;

  WhatIfEngine({
    required this.simulator,
    this.maxConcurrentSimulations = 3,
  });

  /// Run baseline simulation with current state
  Future<SimulationResult> runBaseline({
    Duration? simulationDuration,
    double? timeScale,
  }) async {
    // In a real implementation, this would run the actual simulation
    // For now, we return a placeholder result
    return SimulationResult(
      scenarioId: 'baseline',
      success: true,
      metrics: {},
      duration: simulationDuration ?? Duration.zero,
    );
  }

  /// Run a variant simulation with modifications
  Future<SimulationResult> runVariant(
    ScenarioVariant variant, {
    Duration? simulationDuration,
    double? timeScale,
  }) async {
    // Apply modifications to create variant state
    final modifiedState = _applyModifications(
      variant.initialState ?? simulator.context.entities.isEmpty 
        ? TwinState.empty() 
        : TwinState(entities: simulator.context.entities),
      variant.modifications,
    );

    // Run simulation with modified state
    // In a real implementation, this would clone the simulator and run in parallel
    return SimulationResult(
      scenarioId: variant.id,
      success: true,
      metrics: {},
      duration: simulationDuration ?? Duration.zero,
      appliedModifications: variant.modifications,
    );
  }

  /// Run multiple variants and compare results
  Future<ComparisonReport> compare({
    required List<ScenarioVariant> variants,
    Duration? simulationDuration,
  }) async {
    final baseline = await runBaseline(simulationDuration: simulationDuration);
    final variantResults = <SimulationResult>[];

    for (final variant in variants) {
      final result = await runVariant(variant, simulationDuration: simulationDuration);
      variantResults.add(result);
    }

    return ComparisonReport(
      baseline: baseline,
      variants: variantResults,
      comparedAt: DateTime.now(),
    );
  }

  /// Apply modifications to a twin state
  TwinState _applyModifications(TwinState original, Map<String, dynamic> modifications) {
    // Create a copy with modifications applied
    // This is a simplified implementation - real version would deeply clone and modify
    final newMetadata = Map<String, dynamic>.from(original.metadata);
    newMetadata['modifications'] = modifications;
    
    return original.copyWith(metadata: newMetadata);
  }
}

/// Result of a single simulation run.
class SimulationResult {
  final String scenarioId;
  final bool success;
  final Map<String, dynamic> metrics;
  final Duration duration;
  final Map<String, dynamic>? appliedModifications;
  final List<String> events;
  final DateTime completedAt;

  SimulationResult({
    required this.scenarioId,
    required this.success,
    Map<String, dynamic>? metrics,
    required this.duration,
    this.appliedModifications,
    List<String>? events,
    DateTime? completedAt,
  })  : metrics = metrics ?? {},
        events = events ?? [],
        completedAt = completedAt ?? DateTime.now();

  /// Get a specific metric value
  T? getMetric<T>(String key) {
    if (!metrics.containsKey(key)) return null;
    final value = metrics[key];
    if (value is T) return value;
    return null;
  }

  @override
  String toString() => 'SimulationResult($scenarioId: ${success ? "SUCCESS" : "FAILED"}, ${metrics.length} metrics)';
}

/// Structured report comparing baseline vs. alternative scenarios.
class ComparisonReport {
  final SimulationResult baseline;
  final List<SimulationResult> variants;
  final Map<String, MetricComparison> metricComparisons;
  final DateTime comparedAt;

  ComparisonReport({
    required this.baseline,
    required this.variants,
    DateTime? comparedAt,
  })  : comparedAt = comparedAt ?? DateTime.now(),
        metricComparisons = _buildComparisons(baseline, variants);

  static Map<String, MetricComparison> _buildComparisons(
    SimulationResult baseline,
    List<SimulationResult> variants,
  ) {
    final comparisons = <String, MetricComparison>{};
    
    // Collect all metric keys from baseline and variants
    final allKeys = <String>{};
    allKeys.addAll(baseline.metrics.keys);
    for (final variant in variants) {
      allKeys.addAll(variant.metrics.keys);
    }

    // Build comparison for each metric
    for (final key in allKeys) {
      final baselineValue = baseline.metrics[key];
      if (baselineValue is num) {
        final variantValues = variants
            .map((v) => v.metrics[key])
            .whereType<num>()
            .toList();
        
        if (variantValues.isNotEmpty) {
          comparisons[key] = MetricComparison(
            metricName: key,
            baselineValue: baselineValue.toDouble(),
            variantValues: variantValues.map((v) => v.toDouble()).toList(),
          );
        }
      }
    }

    return comparisons;
  }

  /// Get human-readable summary
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('=== What-If Analysis Report ===');
    buffer.writeln('Compared at: $comparedAt');
    buffer.writeln('Baseline: ${baseline.scenarioId}');
    buffer.writeln('Variants: ${variants.map((v) => v.scenarioId).join(", ")}');
    buffer.writeln();
    
    if (metricComparisons.isEmpty) {
      buffer.writeln('No comparable metrics found.');
    } else {
      buffer.writeln('Metric Comparisons:');
      for (final entry in metricComparisons.entries) {
        buffer.writeln('  - ${entry.value.summary}');
      }
    }
    
    return buffer.toString();
  }
}

/// Comparison of a single metric across baseline and variants.
class MetricComparison {
  final String metricName;
  final double baselineValue;
  final List<double> variantValues;

  MetricComparison({
    required this.metricName,
    required this.baselineValue,
    required this.variantValues,
  });

  /// Calculate percentage change for first variant
  double get percentChange {
    if (variantValues.isEmpty || baselineValue == 0) return 0.0;
    return ((variantValues.first - baselineValue) / baselineValue.abs()) * 100;
  }

  /// Get best variant value (max for positive metrics, min for negative)
  double get bestVariantValue {
    if (variantValues.isEmpty) return baselineValue;
    return variantValues.reduce((a, b) => a > b ? a : b);
  }

  String get summary {
    if (variantValues.isEmpty) return '$metricName: No variant data';
    final change = percentChange;
    final direction = change >= 0 ? '+' : '';
    return '$metricName: ${baselineValue.toStringAsFixed(2)} → ${variantValues.first.toStringAsFixed(2)} ($direction${change.toStringAsFixed(1)}%)';
  }
}
