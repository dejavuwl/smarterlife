import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models.dart';
import 'auth_service.dart';
// ParsedFoodItem, FoodCatalogEntry, LlmRecommendation re-exported via models.dart

class ApiService {
  ApiService({
    required this.baseUrl,
    required this.authService,
  });

  final String baseUrl;
  final AuthService authService;

  /// Returns today's date in the device's local timezone as "YYYY-MM-DD".
  /// This is sent to the backend so meal/workout/summary documents are
  /// always written to the correct day for users outside UTC.
  String _localDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _log(String message) {
    developer.log(message, name: 'ApiService');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = '$baseUrl$path';
    final encodedBody = jsonEncode(body);
    _log('[REQUEST] POST $url\n  body: $encodedBody');

    final token = await authService.idToken();
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: encodedBody,
    );

    _log(
      '[RESPONSE] POST $url\n'
      '  status: ${response.statusCode}\n'
      '  body: ${response.body}',
    );

    final jsonBody = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(jsonBody['error'] ?? 'Request failed.');
    }
    return jsonBody;
  }

  Future<void> setupUser(UserProfile profile) async {
    _log('[setupUser] params: ${jsonEncode(profile.toJson())}');
    final result = await _post('/setupUser', profile.toJson());
    _log('[setupUser] result: ${jsonEncode(result)}');
  }

  Future<void> addMeal(MealDraft meal) async {
    final params = {...meal.toJson(), 'date': _localDateString()};
    _log('[addMeal] params: ${jsonEncode(params)}');
    final result = await _post('/addMeal', params);
    _log('[addMeal] result: ${jsonEncode(result)}');
  }

  Future<void> addWorkout(WorkoutDraft workout) async {
    final params = {...workout.toJson(), 'date': _localDateString()};
    _log('[addWorkout] params: ${jsonEncode(params)}');
    final result = await _post('/addWorkout', params);
    _log('[addWorkout] result: ${jsonEncode(result)}');
  }

  Future<PlanEvaluation?> updateWeight(double weightKg) async {
    final params = {'weight_kg': weightKg, 'date': _localDateString()};
    _log('[updateWeight] params: ${jsonEncode(params)}');
    final result = await _post('/updateWeight', params);
    _log('[updateWeight] result: ${jsonEncode(result)}');
    final eval = result['planEvaluation'];
    if (eval is Map<String, dynamic>) {
      return PlanEvaluation.fromJson(eval);
    }
    return null;
  }

  Future<PlanEvaluation?> updatePlan({
    double? targetWeightKg,
    String? targetDate,
    required bool paused,
  }) async {
    final params = {
      'paused': paused,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (targetDate != null) 'target_date': targetDate,
    };
    _log('[updatePlan] params: ${jsonEncode(params)}');
    final result = await _post('/updatePlan', params);
    _log('[updatePlan] result: ${jsonEncode(result)}');
    final eval = result['planEvaluation'];
    if (eval is Map<String, dynamic>) {
      return PlanEvaluation.fromJson(eval);
    }
    return null;
  }

  Future<PlanAdjustmentSuggestion> fetchPlanAdjustmentSuggestion() async {
    final params = {'date': _localDateString()};
    _log('[fetchPlanAdjustmentSuggestion] params: ${jsonEncode(params)}');
    final json = await _post('/planAdjustmentSuggestion', params);
    _log('[fetchPlanAdjustmentSuggestion] result: ${jsonEncode(json)}');
    return PlanAdjustmentSuggestion.fromJson(json);
  }

  Future<DailySummary> fetchDailySummary() async {
    final params = {'date': _localDateString()};
    _log('[fetchDailySummary] params: ${jsonEncode(params)}');
    final json = await _post('/dailySummary', params);
    _log('[fetchDailySummary] result: ${jsonEncode(json)}');
    return DailySummary.fromJson(json);
  }

  Future<RecommendationResult> fetchRecommendation() async {
    final params = {'date': _localDateString()};
    _log('[fetchRecommendation] params: ${jsonEncode(params)}');
    final json = await _post('/recommendation', params);
    _log('[fetchRecommendation] result: ${jsonEncode(json)}');
    return RecommendationResult.fromJson(json);
  }

  /// Sends a natural-language food description to the backend for AI parsing.
  /// Returns a list of [ParsedFoodItem] with estimated calories and quantities.
  Future<List<ParsedFoodItem>> parseFoodInput(String input) async {
    _log('[parseFoodInput] input: $input');
    final json = await _post('/parseFood', {'input': input});
    _log('[parseFoodInput] result: ${jsonEncode(json)}');
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((i) => ParsedFoodItem.fromJson((i as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Fetches the user's confirmed food history (catalog).
  Future<List<FoodCatalogEntry>> fetchFoodCatalog() async {
    _log('[fetchFoodCatalog]');
    final json = await _post('/getFoodCatalog', {});
    _log('[fetchFoodCatalog] result: ${jsonEncode(json)}');
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((i) =>
            FoodCatalogEntry.fromJson((i as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Refines the calorie estimate for a specific food item using LLM.
  /// Returns a map with `caloriesPerUnit` (double) and `explanation` (String).
  Future<Map<String, dynamic>> refineCalories({
    required String name,
    required double currentEstimate,
    required String unit,
    required String context,
  }) async {
    final params = {
      'name': name,
      'current_estimate': currentEstimate,
      'unit': unit,
      'context': context,
    };
    _log('[refineCalories] params: ${jsonEncode(params)}');
    final result = await _post('/refineCalories', params);
    _log('[refineCalories] result: ${jsonEncode(result)}');
    return result;
  }

  /// Fetches the meals and workouts logged for [date].
  Future<DailyRecords> fetchDailyRecords(String date) async {
    _log('[fetchDailyRecords] date: $date');
    final json = await _post('/getDailyRecords', {'date': date});
    _log('[fetchDailyRecords] result: ${jsonEncode(json)}');
    return DailyRecords.fromJson(json);
  }

  /// Calls the LLM to generate a structured daily recommendation
  /// grouped by meal type and exercise, optionally guided by [preferences].
  Future<LlmRecommendationResult> fetchLlmRecommendation({
    String? preferences,
  }) async {
    final params = {
      'date': _localDateString(),
      if (preferences != null && preferences.isNotEmpty)
        'preferences': preferences,
    };
    _log('[fetchLlmRecommendation] params: ${jsonEncode(params)}');
    final json = await _post('/llmRecommendation', params);
    _log('[fetchLlmRecommendation] result: ${jsonEncode(json)}');
    return LlmRecommendationResult.fromJson(json);
  }

  Future<List<AiRecommendationSummary>> fetchAiRecommendationHistory({
    int limit = 30,
  }) async {
    _log('[fetchAiRecommendationHistory] limit: $limit');
    final json = await _post('/getAiRecommendationHistory', {'limit': limit});
    _log('[fetchAiRecommendationHistory] result: ${jsonEncode(json)}');
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((i) => AiRecommendationSummary.fromJson(
            (i as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AiRecommendationDetail> fetchAiRecommendationDetail(
      String date) async {
    _log('[fetchAiRecommendationDetail] date: $date');
    final json = await _post('/getAiRecommendationDetail', {'date': date});
    _log('[fetchAiRecommendationDetail] result: ${jsonEncode(json)}');
    return AiRecommendationDetail.fromJson(json);
  }
}
