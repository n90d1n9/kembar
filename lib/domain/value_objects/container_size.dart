/// Real ISO 668 container dimensions in meters. Used directly as the
/// footprint/height fed into mesh generation, so placement is dimensionally
/// accurate rather than an arbitrary "box".
enum IsoContainerSize {
  ft20(lengthM: 6.058, widthM: 2.438, heightM: 2.591),
  ft20HighCube(lengthM: 6.058, widthM: 2.438, heightM: 2.896),
  ft40(lengthM: 12.192, widthM: 2.438, heightM: 2.591),
  ft40HighCube(lengthM: 12.192, widthM: 2.438, heightM: 2.896),
  ft45(lengthM: 13.716, widthM: 2.438, heightM: 2.896);

  final double lengthM;
  final double widthM;
  final double heightM;

  const IsoContainerSize({
    required this.lengthM,
    required this.widthM,
    required this.heightM,
  });
}
