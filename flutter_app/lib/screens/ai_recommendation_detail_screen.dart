import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';

class AiRecommendationDetailScreen extends StatefulWidget {
  const AiRecommendationDetailScreen({super.key, required this.date});

  final String date;

  @override
  State<AiRecommendationDetailScreen> createState() =>
      _AiRecommendationDetailScreenState();
}

class _AiRecommendationDetailScreenState
    extends State<AiRecommendationDetailScreen> with TickerProviderStateMixin {
  AiRecommendationDetail? _detail;
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    Future.microtask(_loadDetail);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await context
          .read<SessionState>()
          .loadAiRecommendationDetail(widget.date);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _tabController.dispose();
        _tabController =
            TabController(length: detail.meals.length + 1, vsync: this);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy年MM月dd日').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AmbientScaffold(
      appBar: AppBar(title: Text(_formatDate(widget.date))),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
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
                  onPressed: _loadDetail,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    final tabs = [
      ...detail.meals.map(
        (group) => Tab(
          icon: Icon(_mealIcon(group.mealType), size: 18),
          text: group.mealTypeLabel,
        ),
      ),
      Tab(
          icon: const Icon(Icons.fitness_center, size: 18),
          text: l10n.exerciseTab),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        // Status header
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
                      color:
                          _statusColor(detail.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _statusIcon(detail.status),
                      color: _statusColor(detail.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(detail.status, l10n),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(detail.summaryMessage),
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
                        '${detail.recommendedCalorieTarget.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.remainingLabel,
                    value:
                        '${detail.remainingCalories.toStringAsFixed(0)} kcal',
                    backgroundColor:
                        _statusColor(detail.status).withOpacity(0.12),
                    foregroundColor: _statusColor(detail.status),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Body snapshot
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.bodyStatusAtTime,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  InfoPill(
                    label: l10n.currentWeight,
                    value: '${detail.bodySnapshot.weightKg.toStringAsFixed(1)} kg',
                  ),
                  InfoPill(
                    label: l10n.targetWeightMetric,
                    value:
                        '${detail.bodySnapshot.targetWeightKg.toStringAsFixed(1)} kg',
                  ),
                  InfoPill(
                    label: l10n.heightLabel,
                    value:
                        '${detail.bodySnapshot.heightCm.toStringAsFixed(0)} cm',
                  ),
                  if (detail.bodySnapshot.gender != null)
                    InfoPill(
                      label: l10n.genderLabel,
                      value: detail.bodySnapshot.gender == 'male'
                          ? l10n.maleOption
                          : l10n.femaleOption,
                    ),
                  if (detail.bodySnapshot.age != null)
                    InfoPill(
                      label: l10n.ageLabel,
                      value: '${detail.bodySnapshot.age}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Plan snapshot
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.planProgressAtTime,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  InfoPill(
                    label: l10n.todayIntake,
                    value:
                        '${detail.planSnapshot.caloriesConsumed.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.todayBurn,
                    value:
                        '${detail.planSnapshot.caloriesBurned.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.remainingIntake,
                    value:
                        '${detail.planSnapshot.remainingCalories.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.deficitTarget,
                    value:
                        '${detail.planSnapshot.deficitTarget.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.targetIntakeLabel,
                    value:
                        '${detail.planSnapshot.calorieTarget.toStringAsFixed(0)} kcal',
                  ),
                  InfoPill(
                    label: l10n.bmrTdee,
                    value:
                        '${detail.planSnapshot.bmr.toStringAsFixed(0)} / ${detail.planSnapshot.tdee.toStringAsFixed(0)}',
                  ),
                  InfoPill(
                    label: l10n.planProgress,
                    value:
                        '${detail.planSnapshot.progressPercent.toStringAsFixed(1)}%',
                  ),
                  InfoPill(
                    label: l10n.daysElapsed,
                    value: '${detail.planSnapshot.daysElapsed}',
                  ),
                  InfoPill(
                    label: l10n.daysRemaining,
                    value: '${detail.planSnapshot.daysRemaining}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Meal/exercise tabs
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
              ...detail.meals.map(_buildMealGroupTab),
              _buildExerciseTab(detail.exercises),
            ],
          ),
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
              color:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                item.calories.toStringAsFixed(0),
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
