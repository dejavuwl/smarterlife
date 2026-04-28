class ParsedFoodItem {
  ParsedFoodItem({
    required this.name,
    required this.caloriesPerUnit,
    required this.quantity,
    required this.unit,
  });

  final String name;
  double caloriesPerUnit;
  double quantity;
  final String unit;

  factory ParsedFoodItem.fromJson(Map<String, dynamic> json) {
    return ParsedFoodItem(
      name: json['name'] as String? ?? '',
      caloriesPerUnit: (json['caloriesPerUnit'] ?? 0).toDouble(),
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] as String? ?? '份',
    );
  }

  double get totalCalories => caloriesPerUnit * quantity;
}
