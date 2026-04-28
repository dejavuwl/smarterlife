import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';

class DailyRecordsScreen extends StatefulWidget {
  const DailyRecordsScreen({super.key, this.initialTab = 0});

  /// 0 = 饮食, 1 = 运动
  final int initialTab;

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _dateScrollController = ScrollController();

  late final List<DateTime> _dates;
  late DateTime _selectedDate;

  DailyRecords? _records;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

    final today = _stripTime(DateTime.now());
    _selectedDate = today;
    // Last 30 days up to today
    _dates =
        List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll date bar to the end (today)
      if (_dateScrollController.hasClients) {
        _dateScrollController
            .jumpTo(_dateScrollController.position.maxScrollExtent);
      }
      _loadRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<SessionState>();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final records = await session.fetchDailyRecords(dateStr);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectDate(DateTime date) {
    if (date == _selectedDate) return;
    setState(() => _selectedDate = date);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AmbientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        title: const Text('每日记录'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: const Color(0x88123C36),
          tabs: const [
            Tab(text: '饮食'),
            Tab(text: '运动'),
          ],
        ),
      ),
      body: Column(
        children: [
          _DateBar(
            dates: _dates,
            selectedDate: _selectedDate,
            onSelect: _selectDate,
            scrollController: _dateScrollController,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _loadRecords)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _MealsTab(meals: _records?.meals ?? []),
                          _WorkoutsTab(workouts: _records?.workouts ?? []),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Date bar ────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.dates,
    required this.selectedDate,
    required this.onSelect,
    required this.scrollController,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 88,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
      ),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date == selectedDate;
          final isToday = date == today;

          return GestureDetector(
            onTap: () => onSelect(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary
                    : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? scheme.primary : Colors.white,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? '今' : '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF123C36),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withOpacity(0.75)
                          : const Color(0x88123C36),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Meals tab ────────────────────────────────────────────────────────────────

class _MealsTab extends StatelessWidget {
  const _MealsTab({required this.meals});
  final List<MealRecord> meals;

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return const _EmptyState(
        icon: Icons.restaurant_outlined,
        message: '这天没有饮食记录',
      );
    }

    final totalCalories =
        meals.fold<double>(0, (sum, m) => sum + m.totalCalories);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SummaryPill(
          icon: Icons.restaurant_outlined,
          label: '共摄入',
          value: '${totalCalories.toStringAsFixed(0)} kcal',
          color: const Color(0xFF3E8F7C),
        ),
        const SizedBox(height: 12),
        ...meals.map((m) => _MealRecordCard(record: m)),
      ],
    );
  }
}

class _MealRecordCard extends StatelessWidget {
  const _MealRecordCard({required this.record});
  final MealRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3E8F7C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_outlined,
              size: 20,
              color: Color(0xFF3E8F7C),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.quantity % 1 == 0 ? record.quantity.toInt() : record.quantity}${record.unit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0x99123C36),
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${record.totalCalories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3E8F7C),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Workouts tab ─────────────────────────────────────────────────────────────

class _WorkoutsTab extends StatelessWidget {
  const _WorkoutsTab({required this.workouts});
  final List<WorkoutRecord> workouts;

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const _EmptyState(
        icon: Icons.directions_run_outlined,
        message: '这天没有运动记录',
      );
    }

    final totalBurned =
        workouts.fold<double>(0, (sum, w) => sum + w.estimatedCaloriesBurned);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SummaryPill(
          icon: Icons.local_fire_department_outlined,
          label: '共消耗',
          value: '${totalBurned.toStringAsFixed(0)} kcal',
          color: const Color(0xFFD08743),
        ),
        const SizedBox(height: 12),
        ...workouts.map((w) => _WorkoutRecordCard(record: w)),
      ],
    );
  }
}

class _WorkoutRecordCard extends StatelessWidget {
  const _WorkoutRecordCard({required this.record});
  final WorkoutRecord record;

  String _intensityLabel(String intensity) {
    switch (intensity) {
      case 'low':
        return '低强度';
      case 'medium':
        return '中强度';
      case 'high':
        return '高强度';
      default:
        return intensity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD08743).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_run_outlined,
              size: 20,
              color: Color(0xFFD08743),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.type,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.durationMinutes} 分钟 · ${_intensityLabel(record.intensity)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0x99123C36),
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${record.estimatedCaloriesBurned.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD08743),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0x44123C36)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0x88123C36),
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Color(0xFFB55A52)),
          const SizedBox(height: 12),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
