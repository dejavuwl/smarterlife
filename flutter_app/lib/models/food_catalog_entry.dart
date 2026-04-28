class FoodCatalogEntry {
  const FoodCatalogEntry({
    required this.name,
    required this.caloriesPerUnit,
    required this.unit,
    required this.timesUsed,
  });

  final String name;
  /// kcal/100g when unit is "g"/"ml", otherwise kcal per unit
  final double caloriesPerUnit;
  /// e.g. "g", "ml", "个", "碗", "份"
  final String unit;
  final int timesUsed;

  factory FoodCatalogEntry.fromJson(Map<String, dynamic> json) {
    return FoodCatalogEntry(
      name: json['name'] as String? ?? '',
      caloriesPerUnit: (json['caloriesPerUnit'] ?? 0).toDouble(),
      unit: json['unit'] as String? ?? '份',
      timesUsed: (json['timesUsed'] ?? 1) as int,
    );
  }
}
