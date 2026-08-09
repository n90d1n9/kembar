import 'package:digital_twin_core/domain/intelligence/i_predictor.dart';
import 'package:digital_twin_core/domains/port/container.dart';
import 'package:digital_twin_core/domains/port/terminal.dart';

/// Predictor for container terminal operations
class TerminalLoadPredictor implements IPredictor<int> {
  @override
  final String id;
  @override
  final String name = 'Terminal Load Predictor';
  @override
  final Type targetType = int;

  List<Map<String, dynamic>> _historicalData = [];
  double _lastConfidence = 0.0;
  
  // Seasonal patterns (hourly, daily, weekly)
  Map<int, double> _hourlyPattern = {};
  Map<int, double> _dailyPattern = {};
  Map<int, double> _weeklyPattern = {};

  TerminalLoadPredictor({String? id}) 
      : id = id ?? 'terminal_load_predictor_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<void> train(List<Map<String, dynamic>> trainingData) async {
    _historicalData = trainingData;
    _analyzePatterns();
  }

  void _analyzePatterns() {
    if (_historicalData.isEmpty) return;

    // Analyze hourly patterns
    final hourlyLoads = <int, List<num>>{};
    final dailyLoads = <int, List<num>>{};
    final weeklyLoads = <int, List<num>>{};

    for (final record in _historicalData) {
      final timestamp = record['timestamp'] as DateTime;
      final load = record['load'] as num;

      final hour = timestamp.hour;
      final dayOfWeek = timestamp.weekday;
      final dayOfMonth = timestamp.day;

      hourlyLoads[hour] ??= [];
      hourlyLoads[hour]!.add(load);

      dailyLoads[dayOfWeek] ??= [];
      dailyLoads[dayOfWeek]!.add(load);

      weeklyLoads[dayOfMonth ~/ 7] ??= [];
      weeklyLoads[dayOfMonth ~/ 7]!.add(load);
    }

    // Calculate averages
    _hourlyPattern = hourlyLoads.map((k, v) => 
      MapEntry(k, v.reduce((a, b) => a + b) / v.length));
    
    _dailyPattern = dailyLoads.map((k, v) => 
      MapEntry(k, v.reduce((a, b) => a + b) / v.length));
    
    _weeklyPattern = weeklyLoads.map((k, v) => 
      MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  @override
  Future<PredictionResult<int>> predict(Map<String, dynamic> inputData) async {
    final targetTime = inputData['target_time'] as DateTime? ?? DateTime.now();
    final currentLoad = inputData['current_load'] as int? ?? 0;
    final terminalCapacity = inputData['terminal_capacity'] as int? ?? 1000;

    // Base prediction from current load
    double predictedLoad = currentLoad.toDouble();

    // Apply hourly pattern
    if (_hourlyPattern.isNotEmpty) {
      final hour = targetTime.hour;
      final hourlyFactor = _hourlyPattern[hour] ?? 1.0;
      predictedLoad *= hourlyFactor;
    }

    // Apply daily pattern
    if (_dailyPattern.isNotEmpty) {
      final dayOfWeek = targetTime.weekday;
      final dailyFactor = _dailyPattern[dayOfWeek] ?? 1.0;
      predictedLoad *= dailyFactor;
    }

    // Consider incoming/outgoing containers
    final incomingContainers = inputData['incoming_containers'] as int? ?? 0;
    final outgoingContainers = inputData['outgoing_containers'] as int? ?? 0;
    predictedLoad += incomingContainers - outgoingContainers;

    // Clamp to capacity
    predictedLoad = predictedLoad.clamp(0, terminalCapacity).toDouble();

    // Calculate confidence
    _lastConfidence = _calculateConfidence(targetTime);

    return PredictionResult(
      predictedValue: predictedLoad.round(),
      confidence: _lastConfidence,
      predictedForTime: targetTime,
      metadata: {
        'hourly_factor': _hourlyPattern[targetTime.hour],
        'daily_factor': _dailyPattern[targetTime.weekday],
        'net_flow': incomingContainers - outgoingContainers,
      },
      contributingFactors: [
        'current_load',
        'hourly_pattern',
        'daily_pattern',
        'container_flow',
      ],
    );
  }

  double _calculateConfidence(DateTime targetTime) {
    final hoursAhead = targetTime.difference(DateTime.now()).inHours.abs();
    
    if (hoursAhead == 0) return 0.95;
    if (hoursAhead < 2) return 0.85;
    if (hoursAhead < 6) return 0.75;
    if (hoursAhead < 24) return 0.65;
    if (hoursAhead < 168) return 0.55; // Within a week
    return 0.45;
  }

  @override
  Future<List<PredictionResult<int>>> predictBatch(
    List<Map<String, dynamic>> inputDataList
  ) async {
    return Future.wait(
      inputDataList.map((input) => predict(input))
    );
  }

  @override
  double get lastConfidenceScore => _lastConfidence;

  @override
  Future<void> update(Map<String, dynamic> newData, int actualOutcome) async {
    _historicalData.add({...newData, 'load': actualOutcome});
    
    // Retrain if we have enough new data
    if (_historicalData.length % 10 == 0) {
      _analyzePatterns();
    }
    
    _lastConfidence = _calculateConfidence(newData['target_time'] as DateTime? ?? DateTime.now());
  }
}
