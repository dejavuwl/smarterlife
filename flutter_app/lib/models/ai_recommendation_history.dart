import 'llm_recommendation.dart';

class AiBodySnapshot {
  const AiBodySnapshot({
    required this.weightKg,
    required this.heightCm,
    required this.targetWeightKg,
    this.gender,
    this.age,
  });

  final double weightKg;
  final double heightCm;
  final double targetWeightKg;
  final String? gender;
  final int? age;

  factory AiBodySnapshot.fromJson(Map<String, dynamic> json) {
    return AiBodySnapshot(
      weightKg: (json['weightKg'] ?? 0).toDouble(),
      heightCm: (json['heightCm'] ?? 0).toDouble(),
      targetWeightKg: (json['targetWeightKg'] ?? 0).toDouble(),
      gender: json['gender'] as String?,
      age: json['age'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'heightCm': heightCm,
    'targetWeightKg': targetWeightKg,
    if (gender != null) 'gender': gender,
    if (age != null) 'age': age,
  };
}

class AiPlanSnapshot {
  const AiPlanSnapshot({
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.remainingCalories,
    required this.deficitTarget,
    required this.calorieTarget,
    required this.bmr,
    required this.tdee,
    required this.progressPercent,
    required this.daysElapsed,
    required this.daysRemaining,
  });

  final double caloriesConsumed;
  final double caloriesBurned;
  final double remainingCalories;
  final double deficitTarget;
  final double calorieTarget;
  final double bmr;
  final double tdee;
  final double progressPercent;
  final int daysElapsed;
  final int daysRemaining;

  factory AiPlanSnapshot.fromJson(Map<String, dynamic> json) {
    return AiPlanSnapshot(
      caloriesConsumed: (json['caloriesConsumed'] ?? 0).toDouble(),
      caloriesBurned: (json['caloriesBurned'] ?? 0).toDouble(),
      remainingCalories: (json['remainingCalories'] ?? 0).toDouble(),
      deficitTarget: (json['deficitTarget'] ?? 0).toDouble(),
      calorieTarget: (json['calorieTarget'] ?? 0).toDouble(),
      bmr: (json['bmr'] ?? 0).toDouble(),
      tdee: (json['tdee'] ?? 0).toDouble(),
      progressPercent: (json['progressPercent'] ?? 0).toDouble(),
      daysElapsed: (json['daysElapsed'] ?? 0) as int,
      daysRemaining: (json['daysRemaining'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'caloriesConsumed': caloriesConsumed,
    'caloriesBurned': caloriesBurned,
    'remainingCalories': remainingCalories,
    'deficitTarget': deficitTarget,
    'calorieTarget': calorieTarget,
    'bmr': bmr,
    'tdee': tdee,
    'progressPercent': progressPercent,
    'daysElapsed': daysElapsed,
    'daysRemaining': daysRemaining,
  };
}

class AiRecommendationSummary {
  const AiRecommendationSummary({
    required this.date,
    required this.savedAt,
    required this.status,
    required this.summaryMessage,
    required this.recommendedCalorieTarget,
    required this.weightKg,
  });

  final String date;
  final String savedAt;
  final String status;
  final String summaryMessage;
  final double recommendedCalorieTarget;
  final double weightKg;

  factory AiRecommendationSummary.fromJson(Map<String, dynamic> json) {
    return AiRecommendationSummary(
      date: json['date'] as String? ?? '',
      savedAt: json['savedAt'] as String? ?? '',
      status: json['status'] as String? ?? 'balanced',
      summaryMessage: json['summaryMessage'] as String? ?? '',
      recommendedCalorieTarget:
          (json['recommendedCalorieTarget'] ?? 0).toDouble(),
      weightKg: (json['weightKg'] ?? 0).toDouble(),
    );
  }
}

class AiRecommendationDetail {
  const AiRecommendationDetail({
    required this.date,
    required this.savedAt,
    required this.status,
    required this.summaryMessage,
    required this.recommendedCalorieTarget,
    required this.remainingCalories,
    required this.bodySnapshot,
    required this.planSnapshot,
    required this.meals,
    required this.exercises,
  });

  final String date;
  final String savedAt;
  final String status;
  final String summaryMessage;
  final double recommendedCalorieTarget;
  final double remainingCalories;
  final AiBodySnapshot bodySnapshot;
  final AiPlanSnapshot planSnapshot;
  final List<LlmMealGroup> meals;
  final List<LlmExerciseItem> exercises;

  factory AiRecommendationDetail.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    return AiRecommendationDetail(
      date: json['date'] as String? ?? '',
      savedAt: json['savedAt'] as String? ?? '',
      status: json['status'] as String? ?? 'balanced',
      summaryMessage: json['summaryMessage'] as String? ?? '',
      recommendedCalorieTarget:
          (json['recommendedCalorieTarget'] ?? 0).toDouble(),
      remainingCalories: (json['remainingCalories'] ?? 0).toDouble(),
      bodySnapshot: AiBodySnapshot.fromJson(
          (json['bodySnapshot'] as Map?)?.cast<String, dynamic>() ?? {}),
      planSnapshot: AiPlanSnapshot.fromJson(
          (json['planSnapshot'] as Map?)?.cast<String, dynamic>() ?? {}),
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
    'date': date,
    'savedAt': savedAt,
    'status': status,
    'summaryMessage': summaryMessage,
    'recommendedCalorieTarget': recommendedCalorieTarget,
    'remainingCalories': remainingCalories,
    'bodySnapshot': bodySnapshot.toJson(),
    'planSnapshot': planSnapshot.toJson(),
    'meals': meals.map((g) => g.toJson()).toList(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}
