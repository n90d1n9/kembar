abstract class TwinComponent {
  const TwinComponent();

  String get type;
}

class PropertiesComponent implements TwinComponent {
  final Map<String, TwinProperty> properties;

  const PropertiesComponent({
    this.properties = const {},
  });

  TwinProperty? get(String name) {
    return properties[name];
  }

  @override
  String get type => 'properties';
}
