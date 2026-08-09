import 'package:digital_twin_core/application/intelligence/scenario/what_if_engine.dart';

/// Structured report comparing baseline vs. alternative scenarios (standalone file).
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
    
    final allKeys = <String>{};
    allKeys.addAll(baseline.metrics.keys);
    for (final variant in variants) {
      allKeys.addAll(variant.metrics.keys);
    }

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

class MetricComparison {
  final String metricName;
  final double baselineValue;
  final List<double> variantValues;

  MetricComparison({
    required this.metricName,
    required this.baselineValue,
    required this.variantValues,
  });

  double get percentChange {
    if (variantValues.isEmpty || baselineValue == 0) return 0.0;
    return ((variantValues.first - baselineValue) / baselineValue.abs()) * 100;
  }

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
