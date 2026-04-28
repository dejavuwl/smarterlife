class DailySummary {
  const DailySummary({
    required this.date,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.calorieTarget,
    required this.deficitTarget,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.remainingCalories,
    required this.progressPercent,
    required this.bmr,
    required this.tdee,
  });

  final String date;
  final double currentWeightKg;
  final double targetWeightKg;
  final double calorieTarget;
  final double deficitTarget;
  final double caloriesConsumed;
  final double caloriesBurned;
  final double remainingCalories;
  final double progressPercent;
  final double bmr;
  final double tdee;

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] ?? 0).toDouble();
    return DailySummary(
      date: json['date'] as String? ?? '',
      currentWeightKg: read('current_weight_kg'),
      targetWeightKg: read('target_weight_kg'),
      calorieTarget: read('calorie_target'),
      deficitTarget: read('deficit_target'),
      caloriesConsumed: read('calories_consumed'),
      caloriesBurned: read('calories_burned'),
      remainingCalories: read('remaining_calories'),
      progressPercent: read('progress_percent'),
      bmr: read('bmr'),
      tdee: read('tdee'),
    );
  }
}
