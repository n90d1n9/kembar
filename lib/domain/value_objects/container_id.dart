/// Identity of a physical container (typically an ISO 6346 number, e.g.
/// "MSCU1234565"). Kept as a thin value object rather than a raw String so
/// the domain layer can tighten validation later without touching callers.
class ContainerId {
  final String value;

  const ContainerId(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is ContainerId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
