import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import 'app_surfaces.dart';
import 'metric_card.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.summary,
    this.onTapIntake,
    this.onTapBurn,
  });

  final DailySummary summary;
  final VoidCallback? onTapIntake;
  final VoidCallback? onTapBurn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = DateTime.tryParse(summary.date);
    final formattedDate = date == null ? l10n.today : DateFormat('M月d日').format(date);
    final remainingColor = summary.remainingCalories >= 0
        ? const Color(0xFF2E7D5B)
        : const Color(0xFFB55A52);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionLabel(
                  eyebrow: l10n.dailyOverviewEyebrow,
                  title: l10n.dailyStatusTitle,
                  subtitle: formattedDate,
                ),
              ),
              InfoPill(
                label: l10n.remainingIntake,
                value: '${summary.remainingCalories.toStringAsFixed(0)} kcal',
                backgroundColor: remainingColor.withOpacity(0.12),
                foregroundColor: remainingColor,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(
                label: l10n.currentWeight,
                value: '${summary.currentWeightKg.toStringAsFixed(1)} kg',
                icon: Icons.monitor_weight_outlined,
              ),
              MetricCard(
                label: l10n.targetWeightMetric,
                value: '${summary.targetWeightKg.toStringAsFixed(1)} kg',
                icon: Icons.flag_outlined,
              ),
              MetricCard(
                label: l10n.todayIntake,
                value: '${summary.caloriesConsumed.toStringAsFixed(0)} kcal',
                icon: Icons.restaurant_outlined,
                onTap: onTapIntake,
              ),
              MetricCard(
                label: l10n.todayBurn,
                value: '${summary.caloriesBurned.toStringAsFixed(0)} kcal',
                icon: Icons.local_fire_department_outlined,
                onTap: onTapBurn,
              ),
              MetricCard(
                label: l10n.deficitTarget,
                value: '${summary.deficitTarget.toStringAsFixed(0)} kcal',
                icon: Icons.trending_down_outlined,
              ),
              MetricCard(
                label: l10n.bmrTdee,
                value:
                    '${summary.bmr.toStringAsFixed(0)} / ${summary.tdee.toStringAsFixed(0)}',
                icon: Icons.insights_outlined,
              ),
            ],
          ),
          const SizedBox(height: 22),
          CalorieProgressBar(progressPercent: summary.progressPercent),
        ],
      ),
    );
  }
}

class CalorieProgressBar extends StatelessWidget {
  const CalorieProgressBar({super.key, required this.progressPercent});

  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pct = progressPercent.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.planProgress,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 12,
            backgroundColor: const Color(0xFFE8E0D3),
          ),
        ),
      ],
    );
  }
}
