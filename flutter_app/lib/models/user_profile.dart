class UserProfile {
  const UserProfile({
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.targetDays,
    this.gender,
    this.age,
    this.planStartDate,
    this.planPaused = false,
  });

  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final int targetDays;
  final String? gender;
  final int? age;
  final String? planStartDate;
  final bool planPaused;

  Map<String, dynamic> toJson() {
    return {
      'height_cm': heightCm,
      'weight_kg': currentWeightKg,
      'target_weight_kg': targetWeightKg,
      'target_days': targetDays,
      'gender': gender,
      'age': age,
      'plan_paused': planPaused,
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> json) {
    return UserProfile(
      heightCm: (json['heightCm'] ?? 0).toDouble(),
      currentWeightKg: (json['currentWeightKg'] ?? 0).toDouble(),
      targetWeightKg: (json['targetWeightKg'] ?? 0).toDouble(),
      targetDays: (json['targetDays'] ?? 0) as int,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      planStartDate: json['planStartDate'] as String?,
      planPaused: json['planPaused'] as bool? ?? false,
    );
  }
}
