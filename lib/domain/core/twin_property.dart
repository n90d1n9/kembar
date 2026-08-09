sealed class TwinProperty {
  const TwinProperty();
}

class TwinString extends TwinProperty {
  final String value;

  const TwinString(this.value);
}

class TwinNumber extends TwinProperty {
  final double value;

  const TwinNumber(this.value);
}

class TwinBoolean extends TwinProperty {
  final bool value;

  const TwinBoolean(this.value);
}

class TwinEnum extends TwinProperty {
  final String value;

  const TwinEnum(this.value);
}

class TwinDateTime extends TwinProperty {
  final DateTime value;

  const TwinDateTime(this.value);
}
