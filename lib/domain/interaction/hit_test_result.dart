class HitTestResult {
  final String nodeId;

  final String? entityId;

  final double distance;

  const HitTestResult({
    required this.nodeId,
    this.entityId,
    this.distance = 0,
  });
}
