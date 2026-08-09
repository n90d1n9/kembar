import 'package:digital_twin_core/domain/twin/twin_state.dart';

/// Detects anomalies by comparing real-time performance against baselines.
class AnomalyDetector {
  final Map<String, BaselineMetrics> _baselines = {};
  final double defaultThreshold;

  AnomalyDetector({this.defaultThreshold = 2.0}); // 2 standard deviations

  /// Register a baseline for a specific metric
  void registerBaseline(String metricId, BaselineMetrics metrics) {
    _baselines[metricId] = metrics;
  }

  /// Check if a current value is anomalous compared to baseline
  AnomalyResult check(String metricId, double currentValue, {DateTime? timestamp}) {
    final baseline = _baselines[metricId];
    
    if (baseline == null) {
      return AnomalyResult(
        metricId: metricId,
        isAnomalous: false,
        reason: 'No baseline registered',
        severity: AnomalySeverity.info,
      );
    }

    final deviation = (currentValue - baseline.mean) / (baseline.standardDeviation > 0 ? baseline.standardDeviation : 1);
    final absDeviation = deviation.abs();

    AnomalySeverity severity;
    if (absDeviation > defaultThreshold * 2) {
      severity = AnomalySeverity.critical;
    } else if (absDeviation > defaultThreshold * 1.5) {
      severity = AnomalySeverity.high;
    } else if (absDeviation > defaultThreshold) {
      severity = AnomalySeverity.medium;
    } else if (absDeviation > defaultThreshold * 0.7) {
      severity = AnomalySeverity.low;
    } else {
      severity = AnomalySeverity.info;
    }

    final isAnomalous = absDeviation > defaultThreshold;

    return AnomalyResult(
      metricId: metricId,
      isAnomalous: isAnomalous,
      currentValue: currentValue,
      expectedValue: baseline.mean,
      deviation: deviation,
      severity: severity,
      timestamp: timestamp ?? DateTime.now(),
      reason: isAnomalous 
          ? 'Value deviates ${deviation.toStringAsFixed(2)}σ from mean'
          : 'Within normal range',
    );
  }

  /// Check multiple metrics at once
  List<AnomalyResult> checkAll(Map<String, double> currentValues, {DateTime? timestamp}) {
    return currentValues.entries
        .map((e) => check(e.key, e.value, timestamp: timestamp))
        .toList();
  }

  /// Get all registered baselines
  Map<String, BaselineMetrics> getBaselines() => Map.unmodifiable(_baselines);
}

/// Represents historical baseline metrics for anomaly detection.
class BaselineMetrics {
  final double mean;
  final double standardDeviation;
  final int sampleSize;
  final DateTime calculatedAt;
  final Map<String, dynamic>? metadata;

  BaselineMetrics({
    required this.mean,
    required this.standardDeviation,
    required this.sampleSize,
    DateTime? calculatedAt,
    this.metadata,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// Create baseline from a list of historical values
  factory BaselineMetrics.fromValues(List<double> values, {Map<String, dynamic>? metadata}) {
    if (values.isEmpty) {
      throw ArgumentError('Cannot create baseline from empty value list');
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.fold<double>(
      0.0,
      (sum, value) => sum + (value - mean) * (value - mean),
    ) / values.length;
    final stdDev = variance > 0 ? sqrt(variance) : 0.0;

    return BaselineMetrics(
      mean: mean,
      standardDeviation: stdDev,
      sampleSize: values.length,
      metadata: metadata,
    );
  }

  @override
  String toString() => 'BaselineMetrics(mean: ${mean.toStringAsFixed(2)}, stdDev: ${standardDeviation.toStringAsFixed(2)}, n=$sampleSize)';
}

/// Result of an anomaly detection check.
class AnomalyResult {
  final String metricId;
  final bool isAnomalous;
  final double? currentValue;
  final double? expectedValue;
  final double? deviation;
  final AnomalySeverity severity;
  final DateTime timestamp;
  final String reason;

  AnomalyResult({
    required this.metricId,
    required this.isAnomalous,
    this.currentValue,
    this.expectedValue,
    this.deviation,
    required this.severity,
    DateTime? timestamp,
    required this.reason,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'AnomalyResult($metricId: ${isAnomalous ? "ANOMALY" : "NORMAL"} [$severity])';
}

/// Severity levels for anomalies.
enum AnomalySeverity {
  info,
  low,
  medium,
  high,
  critical,
}

/// Simple square root implementation for environments without dart:math import.
double sqrt(double value) {
  if (value < 0) return double.nan;
  if (value == 0) return 0;
  
  var guess = value / 2;
  for (int i = 0; i < 20; i++) {
    guess = (guess + value / guess) / 2;
  }
  return guess;
}
