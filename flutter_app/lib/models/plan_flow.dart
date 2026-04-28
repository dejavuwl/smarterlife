import 'llm_recommendation.dart';

class PlanEvaluation {
  const PlanEvaluation({
    required this.actionRequired,
    required this.message,
    required this.rawRequiredDeficit,
    required this.maxHealthyDeficit,
    required this.currentTargetWeightKg,
    required this.currentTargetDate,
    required this.planPaused,
    this.actionType,
  });

  final bool actionRequired;
  final String? actionType;
  final String message;
  final double rawRequiredDeficit;
  final double maxHealthyDeficit;
  final double currentTargetWeightKg;
  final String currentTargetDate;
  final bool planPaused;

  factory PlanEvaluation.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) => (json[key] ?? 0).toDouble();
    return PlanEvaluation(
      actionRequired: json['actionRequired'] as bool? ?? false,
      actionType: json['actionType'] as String?,
      message: json['message'] as String? ?? '',
      rawRequiredDeficit: readDouble('rawRequiredDeficit'),
      maxHealthyDeficit: readDouble('maxHealthyDeficit'),
      currentTargetWeightKg: readDouble('currentTargetWeightKg'),
      currentTargetDate: json['currentTargetDate'] as String? ?? '',
      planPaused: json['planPaused'] as bool? ?? false,
    );
  }
}

class PlanAdjustmentSuggestion {
  const PlanAdjustmentSuggestion({
    required this.targetWeightKg,
    required this.targetDate,
    required this.reason,
  });

  final double targetWeightKg;
  final String targetDate;
  final String reason;

  factory PlanAdjustmentSuggestion.fromJson(Map<String, dynamic> json) {
    return PlanAdjustmentSuggestion(
      targetWeightKg: (json['targetWeightKg'] ?? 0).toDouble(),
      targetDate: json['targetDate'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class LlmRecommendationResult {
  const LlmRecommendationResult({
    required this.kind,
    this.recommendation,
    this.planEvaluation,
  });

  final String kind;
  final LlmRecommendation? recommendation;
  final PlanEvaluation? planEvaluation;

  bool get isRecommendation =>
      kind == 'recommendation' && recommendation != null;
  bool get requiresPlanAction =>
      kind == 'plan_action_required' && planEvaluation != null;

  factory LlmRecommendationResult.fromJson(Map<String, dynamic> json) {
    return LlmRecommendationResult(
      kind: json['kind'] as String? ?? 'recommendation',
      recommendation: json['kind'] == 'recommendation'
          ? LlmRecommendation.fromJson(json)
          : null,
      planEvaluation: json['planEvaluation'] is Map<String, dynamic>
          ? PlanEvaluation.fromJson(
              json['planEvaluation'] as Map<String, dynamic>)
          : null,
    );
  }
}
