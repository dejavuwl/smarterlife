import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/plan_update_dialog.dart';
import 'ai_recommendation_history_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with TickerProviderStateMixin {
  LlmRecommendation? _rec;
  bool _isLoading = false;
  String? _error;
  final _prefsController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    Future.microtask(_initFromCacheOrLoad);
  }

  Future<void> _initFromCacheOrLoad() async {
    final cached = context.read<SessionState>().latestRecommendationDetail;
    if (cached != null) {
      // Restore from local cache instantly — no network call
      if (!mounted) return;
      setState(() {
        _rec = LlmRecommendation(
          status: cached.status,
          recommendedCalorieTarget: cached.recommendedCalorieTarget,
          remainingCalories: cached.remainingCalories,
          summaryMessage: cached.summaryMessage,
          meals: cached.meals,
          exercises: cached.exercises,
        );
        _tabController.dispose();
        _tabController =
            TabController(length: cached.meals.length + 1, vsync: this);
      });
    }
    await _load();
  }

  @override
  void dispose() {
    _prefsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({String? preferences}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<SessionState>()
          .loadLlmRecommendation(preferences: preferences);
      if (!mounted) return;
      if (result.recommendation != null) {
        final rec = result.recommendation!;
        setState(() {
          _rec = rec;
          _tabController.dispose();
          _tabController =
              TabController(length: rec.meals.length + 1, vsync: this);
        });
      } else if (result.planEvaluation != null) {
        await context.read<SessionState>().clearRecommendationCache();
        if (!mounted) return;
        setState(() => _rec = null);
        await _handlePlanAction(result.planEvaluation!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _regenerate() async {
    await _load(preferences: _prefsController.text.trim());
  }

  String _currentTargetDate(SessionState session) {
    final profile = session.profile;
    if (profile?.planStartDate == null) {
      return DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30)));
    }
    final start = DateTime.tryParse(profile!.planStartDate!);
    if (start == null) {
      return DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30)));
    }
    return DateFormat('yyyy-MM-dd')
        .format(start.add(Duration(days: profile.targetDays)));
  }

  Future<void> _applyPausedMode() async {
    await context.read<SessionState>().updatePlan(paused: true);
    if (!mounted) return;
    await _load(preferences: _prefsController.text.trim());
  }

  Future<void> _applyAiSuggestedPlan() async {
    final session = context.read<SessionState>();
    final suggestion = await session.fetchPlanAdjustmentSuggestion();
    await session.updatePlan(
      paused: false,
      targetWeightKg: suggestion.targetWeightKg,
      targetDate: suggestion.targetDate,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已应用 AI 建议：${suggestion.targetDate} / ${suggestion.targetWeightKg.toStringAsFixed(1)} kg',
        ),
      ),
    );
    await _load(preferences: _prefsController.text.trim());
  }

  Future<void> _showPlanEditor({required String title}) async {
    final session = context.read<SessionState>();
    final profile = session.profile;
    if (profile == null) return;
    final draft = await showDialog<PlanUpdateDraft>(
      context: context,
      builder: (_) => PlanUpdateDialog(
        title: title,
        initialTargetWeightKg: profile.targetWeightKg,
        initialTargetDate: _currentTargetDate(session),
        currentWeightKg: profile.currentWeightKg,
      ),
    );
    if (draft == null) return;
    await session.updatePlan(
      paused: false,
      targetWeightKg: draft.targetWeightKg,
      targetDate: draft.targetDate,
    );
    if (!mounted) return;
    await _load(preferences: _prefsController.text.trim());
  }

  Future<void> _handlePlanAction(PlanEvaluation evaluation) async {
    final actionType = evaluation.actionType;
    if (actionType == 'update_or_pause') {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('需要先调整计划'),
          content: Text(evaluation.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _applyPausedMode();
              },
              child: const Text('仅记录'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _applyAiSuggestedPlan();
              },
              child: const Text('AI建议并应用'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showPlanEditor(title: '更新计划');
              },
              child: const Text('更新计划'),
            ),
          ],
        ),
      );
    } else if (actionType == 'completed_or_record_only') {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('当前计划已完成'),
          content: Text(evaluation.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _applyPausedMode();
              },
              child: const Text('仅记录'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showPlanEditor(title: '开启新计划');
              },
              child: const Text('开启新计划'),
            ),
          ],
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'deficit':
        return const Color(0xFFD08743);
      case 'overweight_adjusted':
        return const Color(0xFFB55A52);
      default:
        return const Color(0xFF3E8F7C);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'deficit':
        return Icons.priority_high_rounded;
      case 'overweight_adjusted':
        return Icons.trending_down_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'deficit':
        return l10n.belowTargetStatus;
      case 'overweight_adjusted':
        return l10n.tighterControlStatus;
      default:
        return l10n.onTrackStatus;
    }
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.light_mode_outlined;
      case 'dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.cookie_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AmbientScaffold(
      appBar: AppBar(
        title: Text(l10n.dailyRecommendationTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.recommendationHistoryTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiRecommendationHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _load(),
            tooltip: l10n.reloadTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
          _ComposerBar(
            controller: _prefsController,
            isLoading: _isLoading,
            onSubmit: _regenerate,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading && _rec == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: Color(0xFFB55A52),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.failedLoadRecommendation,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _load(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rec = _rec;
    if (rec == null) {
      return const SizedBox.shrink();
    }

    final tabs = [
      ...rec.meals.map(
        (group) => Tab(
          icon: Icon(_mealIcon(group.mealType), size: 18),
          text: group.mealTypeLabel,
        ),
      ),
      Tab(
          icon: const Icon(Icons.fitness_center, size: 18),
          text: l10n.exerciseTab),
    ];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _statusColor(rec.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _statusIcon(rec.status),
                          color: _statusColor(rec.status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(rec.status, l10n),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(rec.summaryMessage),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      InfoPill(
                        label: l10n.targetIntakeLabel,
                        value:
                            '${rec.recommendedCalorieTarget.toStringAsFixed(0)} kcal',
                      ),
                      InfoPill(
                        label: l10n.remainingLabel,
                        value:
                            '${rec.remainingCalories.toStringAsFixed(0)} kcal',
                        backgroundColor:
                            _statusColor(rec.status).withOpacity(0.12),
                        foregroundColor: _statusColor(rec.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xCC123C36),
                tabs: tabs,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.52,
              child: TabBarView(
                controller: _tabController,
                children: [
                  ...rec.meals.map(_buildMealGroupTab),
                  _buildExerciseTab(rec.exercises),
                ],
              ),
            ),
          ],
        ),
        if (_isLoading)
          Container(
            color: const Color(0x26000000),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildMealGroupTab(LlmMealGroup group) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      child: ListView(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _mealIcon(group.mealType),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.mealTypeLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              InfoPill(
                label: l10n.total,
                value: '${group.totalCalories.toStringAsFixed(0)} kcal',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MealItemTile(item: item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTab(List<LlmExerciseItem> exercises) {
    final l10n = AppLocalizations.of(context)!;
    final totalBurned = exercises.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCaloriesBurned,
    );
    return GlassCard(
      child: ListView(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x14D08743),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFD08743),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.exerciseTab,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              InfoPill(
                label: l10n.estimatedBurnLabel,
                value: '${totalBurned.toStringAsFixed(0)} kcal',
                backgroundColor: const Color(0x14D08743),
                foregroundColor: const Color(0xFFD08743),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (exercises.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(l10n.noExerciseRecommended),
            )
          else
            ...exercises.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseTile(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.preferencesHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.regenerateButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealItemTile extends StatelessWidget {
  const _MealItemTile({required this.item});

  final LlmMealItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.56),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '${item.calories.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${item.quantity.toStringAsFixed(1)} ${item.unit}'),
              ],
            ),
          ),
          Text(
            '${item.calories.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.item});

  final LlmExerciseItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.56),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x14D08743),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_run,
              color: Color(0xFFD08743),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${item.durationMinutes} min'),
              ],
            ),
          ),
          Text(
            '${item.estimatedCaloriesBurned.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
