class RecommendationResult {
  const RecommendationResult({
    required this.status,
    required this.recommendedCalorieTarget,
    required this.suggestedMessage,
  });

  final String status;
  final double recommendedCalorieTarget;
  final String suggestedMessage;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      status: json['status'] as String? ?? 'balanced',
      recommendedCalorieTarget:
          (json['recommendedCalorieTarget'] ?? 0).toDouble(),
      suggestedMessage: json['suggestedMessage'] as String? ?? '',
    );
  }
}
