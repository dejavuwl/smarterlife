class WorkoutDraft {
  const WorkoutDraft({
    required this.type,
    required this.durationMinutes,
    required this.intensity,
  });

  final String type;
  final int durationMinutes;
  final String intensity;

  Map<String, dynamic> toJson() => {
        'workout_type': type,
        'duration_minutes': durationMinutes,
        'intensity': intensity,
      };
}
