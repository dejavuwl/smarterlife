import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';
import 'ai_recommendation_detail_screen.dart';

class AiRecommendationHistoryScreen extends StatefulWidget {
  const AiRecommendationHistoryScreen({super.key});

  @override
  State<AiRecommendationHistoryScreen> createState() =>
      _AiRecommendationHistoryScreenState();
}

class _AiRecommendationHistoryScreenState
    extends State<AiRecommendationHistoryScreen> {
  List<AiRecommendationSummary> _items = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHistory);
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items =
          await context.read<SessionState>().loadAiRecommendationHistory();
      if (!mounted) return;
      setState(() => _items = items);
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
      appBar: AppBar(title: Text(l10n.recommendationHistoryTitle)),
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
                  onPressed: _loadHistory,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noRecommendationHistory,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _HistoryItemTile(
          item: item,
          statusColor: _statusColor(item.status),
          statusIcon: _statusIcon(item.status),
          statusLabel: _statusLabel(item.status, l10n),
          formattedDate: _formatDate(item.date),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiRecommendationDetailScreen(date: item.date),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryItemTile extends StatelessWidget {
  const _HistoryItemTile({
    required this.item,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.formattedDate,
    required this.onTap,
  });

  final AiRecommendationSummary item;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;
  final String formattedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.recommendedCalorieTarget.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.weightKg.toStringAsFixed(1)} kg',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
