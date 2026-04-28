class MealDraft {
  const MealDraft({
    required this.name,
    required this.caloriesPerUnit,
    required this.quantity,
    this.unit = '份',
  });

  final String name;
  /// kcal/100g when unit is "g"/"ml", otherwise kcal per unit
  final double caloriesPerUnit;
  /// actual quantity in grams, ml, or count
  final double quantity;
  /// display unit: "g", "ml", "个", "碗", etc.
  final String unit;

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': caloriesPerUnit,
        'quantity': quantity,
        'unit': unit,
      };
}
