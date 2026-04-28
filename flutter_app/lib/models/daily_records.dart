class MealRecord {
  const MealRecord({
    required this.name,
    required this.caloriesPerUnit,
    required this.unit,
    required this.quantity,
    required this.totalCalories,
    this.loggedAt,
  });

  final String name;
  final double caloriesPerUnit;
  final String unit;
  final double quantity;
  final double totalCalories;
  final String? loggedAt;

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] ?? 0).toDouble();
    return MealRecord(
      name: json['name'] as String? ?? '',
      caloriesPerUnit: read('caloriesPerUnit'),
      unit: json['unit'] as String? ?? '',
      quantity: read('quantity'),
      totalCalories: read('totalCalories'),
      loggedAt: json['loggedAt'] as String?,
    );
  }
}

class WorkoutRecord {
  const WorkoutRecord({
    required this.type,
    required this.durationMinutes,
    required this.intensity,
    required this.estimatedCaloriesBurned,
    this.loggedAt,
  });

  final String type;
  final int durationMinutes;
  final String intensity;
  final double estimatedCaloriesBurned;
  final String? loggedAt;

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      type: json['type'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num? ?? 0).toInt(),
      intensity: json['intensity'] as String? ?? '',
      estimatedCaloriesBurned:
          (json['estimatedCaloriesBurned'] as num? ?? 0).toDouble(),
      loggedAt: json['loggedAt'] as String?,
    );
  }
}

class DailyRecords {
  const DailyRecords({
    required this.date,
    required this.meals,
    required this.workouts,
  });

  final String date;
  final List<MealRecord> meals;
  final List<WorkoutRecord> workouts;

  factory DailyRecords.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    final rawWorkouts = json['workouts'] as List<dynamic>? ?? [];
    return DailyRecords(
      date: json['date'] as String? ?? '',
      meals: rawMeals
          .map((m) => MealRecord.fromJson((m as Map).cast<String, dynamic>()))
          .toList(),
      workouts: rawWorkouts
          .map((w) =>
              WorkoutRecord.fromJson((w as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
