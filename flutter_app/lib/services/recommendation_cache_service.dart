import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class RecommendationCacheService {
  static const String _key = 'latest_ai_recommendation';

  Future<void> save(AiRecommendationDetail detail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(detail.toJson()));
  }

  Future<AiRecommendationDetail?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AiRecommendationDetail.fromJson(json);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
