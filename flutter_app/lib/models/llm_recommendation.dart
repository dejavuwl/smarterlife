class LlmMealItem {
  const LlmMealItem({
    required this.name,
    required this.calories,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double calories;
  final double quantity;
  final String unit;

  factory LlmMealItem.fromJson(Map<String, dynamic> json) {
    return LlmMealItem(
      name: json['name'] as String? ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] as String? ?? '份',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'calories': calories,
    'quantity': quantity,
    'unit': unit,
  };
}

class LlmMealGroup {
  const LlmMealGroup({
    required this.mealType,
    required this.mealTypeLabel,
    required this.totalCalories,
    required this.items,
  });

  final String mealType;
  final String mealTypeLabel;
  final double totalCalories;
  final List<LlmMealItem> items;

  factory LlmMealGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return LlmMealGroup(
      mealType: json['mealType'] as String? ?? '',
      mealTypeLabel: json['mealTypeLabel'] as String? ?? '',
      totalCalories: (json['totalCalories'] ?? 0).toDouble(),
      items: rawItems
          .map((i) => LlmMealItem.fromJson((i as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mealType': mealType,
    'mealTypeLabel': mealTypeLabel,
    'totalCalories': totalCalories,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class LlmExerciseItem {
  const LlmExerciseItem({
    required this.name,
    required this.durationMinutes,
    required this.estimatedCaloriesBurned,
  });

  final String name;
  final int durationMinutes;
  final double estimatedCaloriesBurned;

  factory LlmExerciseItem.fromJson(Map<String, dynamic> json) {
    return LlmExerciseItem(
      name: json['name'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] ?? 30) as int,
      estimatedCaloriesBurned:
          (json['estimatedCaloriesBurned'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'durationMinutes': durationMinutes,
    'estimatedCaloriesBurned': estimatedCaloriesBurned,
  };
}

class LlmRecommendation {
  const LlmRecommendation({
    required this.status,
    required this.recommendedCalorieTarget,
    required this.remainingCalories,
    required this.summaryMessage,
    required this.meals,
    required this.exercises,
  });

  final String status;
  final double recommendedCalorieTarget;
  final double remainingCalories;
  final String summaryMessage;
  final List<LlmMealGroup> meals;
  final List<LlmExerciseItem> exercises;

  factory LlmRecommendation.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    return LlmRecommendation(
      status: json['status'] as String? ?? 'balanced',
      recommendedCalorieTarget:
          (json['recommendedCalorieTarget'] ?? 0).toDouble(),
      remainingCalories: (json['remainingCalories'] ?? 0).toDouble(),
      summaryMessage: json['summaryMessage'] as String? ?? '',
      meals: rawMeals
          .map((g) => LlmMealGroup.fromJson((g as Map).cast<String, dynamic>()))
          .toList(),
      exercises: rawExercises
          .map((e) =>
              LlmExerciseItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'recommendedCalorieTarget': recommendedCalorieTarget,
    'remainingCalories': remainingCalories,
    'summaryMessage': summaryMessage,
    'meals': meals.map((g) => g.toJson()).toList(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}
