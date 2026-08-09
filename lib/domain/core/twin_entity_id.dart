class TwinEntityId {
  final String value;

  const TwinEntityId(this.value);

  bool get isEmpty => value.isEmpty;

  bool get isNotEmpty => value.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is TwinEntityId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
