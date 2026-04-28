import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'recommendation_cache_service.dart';

class SessionState extends ChangeNotifier {
  SessionState({
    required this.authService,
    required this.apiService,
    required this.firestore,
    required this.recommendationCache,
  });

  final AuthService authService;
  final ApiService apiService;
  final FirebaseFirestore firestore;
  final RecommendationCacheService recommendationCache;

  UserProfile? profile;
  DailySummary? summary;
  RecommendationResult? recommendation;
  LlmRecommendation? llmRecommendation;
  AiRecommendationDetail? latestRecommendationDetail;
  List<FoodCatalogEntry> foodCatalog = [];
  bool loading = false;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    await authService.ensureSignedIn();
    await loadProfile();
    if (profile != null) {
      await refreshSummary();
    }
    try {
      latestRecommendationDetail = await recommendationCache.load();
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) {
      profile = null;
      notifyListeners();
      return;
    }
    profile = UserProfile.fromFirestore(doc.data()!);
    notifyListeners();
  }

  Future<void> createProfile(UserProfile value) async {
    loading = true;
    notifyListeners();
    await apiService.setupUser(value);
    await loadProfile();
    await refreshSummary();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshSummary() async {
    summary = await apiService.fetchDailySummary();
    notifyListeners();
  }

  Future<void> addMeal(MealDraft meal) async {
    await apiService.addMeal(meal);
    await refreshSummary();
  }

  Future<void> addWorkout(WorkoutDraft workout) async {
    await apiService.addWorkout(workout);
    await refreshSummary();
  }

  Future<PlanEvaluation?> updateWeight(double weightKg) async {
    final result = await apiService.updateWeight(weightKg);
    await loadProfile();
    await refreshSummary();
    await clearRecommendationCache();
    return result;
  }

  Future<RecommendationResult> loadRecommendation() async {
    recommendation = await apiService.fetchRecommendation();
    notifyListeners();
    return recommendation!;
  }

  /// Parse a natural-language food description into structured items.
  Future<List<ParsedFoodItem>> parseFoodInput(String input) async {
    return apiService.parseFoodInput(input);
  }

  /// Load (or reload) the user's food history catalog.
  Future<void> loadFoodCatalog() async {
    foodCatalog = await apiService.fetchFoodCatalog();
    notifyListeners();
  }

  /// Calls the backend to refine calorie estimate for a specific food item.
  Future<Map<String, dynamic>> refineCalories({
    required String name,
    required double currentEstimate,
    required String unit,
    required String context,
  }) async {
    return apiService.refineCalories(
      name: name,
      currentEstimate: currentEstimate,
      unit: unit,
      context: context,
    );
  }

  /// Fetch the meal and workout records for a specific [date] (YYYY-MM-DD).
  Future<DailyRecords> fetchDailyRecords(String date) async {
    return apiService.fetchDailyRecords(date);
  }

  /// Load an LLM-generated recommendation.
  /// Pass [preferences] to re-generate with custom constraints.
  /// On success, saves the recommendation locally and marks it in state.
  Future<LlmRecommendationResult> loadLlmRecommendation(
      {String? preferences}) async {
    final result =
        await apiService.fetchLlmRecommendation(preferences: preferences);
    if (result.recommendation != null) {
      llmRecommendation = result.recommendation;
      final detail = _buildDetailFromCurrentState(llmRecommendation!);
      latestRecommendationDetail = detail;
      notifyListeners();
      try {
        await recommendationCache.save(detail);
      } catch (_) {}
    }
    return result;
  }

  Future<PlanEvaluation?> updatePlan({
    double? targetWeightKg,
    String? targetDate,
    required bool paused,
  }) async {
    final result = await apiService.updatePlan(
      targetWeightKg: targetWeightKg,
      targetDate: targetDate,
      paused: paused,
    );
    await loadProfile();
    await refreshSummary();
    await clearRecommendationCache();
    return result;
  }

  Future<PlanAdjustmentSuggestion> fetchPlanAdjustmentSuggestion() {
    return apiService.fetchPlanAdjustmentSuggestion();
  }

  Future<void> clearRecommendationCache() async {
    llmRecommendation = null;
    latestRecommendationDetail = null;
    notifyListeners();
    try {
      await recommendationCache.clear();
    } catch (_) {}
  }

  /// Fetch history list from server (not cached locally).
  Future<List<AiRecommendationSummary>> loadAiRecommendationHistory() {
    return apiService.fetchAiRecommendationHistory();
  }

  /// Fetch a specific recommendation detail from server by date.
  Future<AiRecommendationDetail> loadAiRecommendationDetail(String date) {
    return apiService.fetchAiRecommendationDetail(date);
  }

  AiRecommendationDetail _buildDetailFromCurrentState(LlmRecommendation rec) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final p = profile;
    final s = summary;

    int daysElapsed = 0;
    int daysRemaining = 0;
    if (p != null && p.planStartDate != null) {
      try {
        final planStart = DateTime.parse(p.planStartDate!);
        final planEnd = planStart.add(Duration(days: p.targetDays));
        daysElapsed = now.difference(planStart).inDays.clamp(0, p.targetDays);
        daysRemaining = planEnd.difference(now).inDays.clamp(0, p.targetDays);
      } catch (_) {}
    }

    return AiRecommendationDetail(
      date: dateStr,
      savedAt: now.toIso8601String(),
      status: rec.status,
      summaryMessage: rec.summaryMessage,
      recommendedCalorieTarget: rec.recommendedCalorieTarget,
      remainingCalories: rec.remainingCalories,
      bodySnapshot: AiBodySnapshot(
        weightKg: p?.currentWeightKg ?? 0,
        heightCm: p?.heightCm ?? 0,
        targetWeightKg: p?.targetWeightKg ?? 0,
        gender: p?.gender,
        age: p?.age,
      ),
      planSnapshot: AiPlanSnapshot(
        caloriesConsumed: s?.caloriesConsumed ?? 0,
        caloriesBurned: s?.caloriesBurned ?? 0,
        remainingCalories: s?.remainingCalories ?? 0,
        deficitTarget: s?.deficitTarget ?? 0,
        calorieTarget: s?.calorieTarget ?? 0,
        bmr: s?.bmr ?? 0,
        tdee: s?.tdee ?? 0,
        progressPercent: s?.progressPercent ?? 0,
        daysElapsed: daysElapsed,
        daysRemaining: daysRemaining,
      ),
      meals: rec.meals,
      exercises: rec.exercises,
    );
  }
}
