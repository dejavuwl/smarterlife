import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';
import 'recommendation_screen.dart';

bool _isWeightOrVolume(String unit) {
  final normalized = unit.toLowerCase();
  return normalized == 'g' ||
      normalized == 'ml' ||
      normalized == 'kg' ||
      normalized == 'l' ||
      unit == '克' ||
      unit == '毫升' ||
      unit == '千克' ||
      unit == '升';
}

String _caloriesLabel(String unit, AppLocalizations l10n) {
  if (_isWeightOrVolume(unit)) return l10n.caloriesPer100Unit(unit);
  return l10n.caloriesPerUnit(unit);
}

class _EditableItem {
  _EditableItem({
    required this.name,
    required this.caloriesPerUnit,
    required this.quantity,
    required this.unit,
  });

  final String name;
  double caloriesPerUnit;
  double quantity;
  final String unit;

  double get totalCalories {
    if (_isWeightOrVolume(unit)) {
      return (caloriesPerUnit * quantity / 100 * 10).roundToDouble() / 10;
    }
    return (caloriesPerUnit * quantity * 10).roundToDouble() / 10;
  }

  double get sliderMin => _isWeightOrVolume(unit) ? 1.0 : 0.5;
  double get sliderMax => _isWeightOrVolume(unit) ? 1000.0 : 20.0;
  int get sliderDivisions => _isWeightOrVolume(unit) ? 199 : 39;

  String get quantityLabel {
    if (_isWeightOrVolume(unit)) {
      return '${quantity.toStringAsFixed(0)} $unit';
    }
    final formatted = quantity == quantity.truncateToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return '$formatted $unit';
  }
}

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _inputController = TextEditingController();
  final List<_EditableItem> _items = [];
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _showCatalog = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SessionState>().loadFoodCatalog());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  double get _grandTotal =>
      _items.fold<double>(0, (sum, item) => sum + item.totalCalories);

  Future<void> _analyzeInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    try {
      final parsed = await context.read<SessionState>().parseFoodInput(text);
      if (!mounted) return;
      setState(() {
        _items.addAll(
          parsed.map(
            (item) => _EditableItem(
              name: item.name,
              caloriesPerUnit: item.caloriesPerUnit.clamp(1, 3000),
              quantity: _isWeightOrVolume(item.unit)
                  ? item.quantity.clamp(1, 1000)
                  : item.quantity.clamp(0.5, 20),
              unit: item.unit.isEmpty ? 'serving' : item.unit,
            ),
          ),
        );
        _inputController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedParseFoodInput(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _addFromCatalog(FoodCatalogEntry entry) {
    setState(() {
      _items.add(
        _EditableItem(
          name: entry.name,
          caloriesPerUnit: entry.caloriesPerUnit,
          quantity: _isWeightOrVolume(entry.unit) ? 100.0 : 1.0,
          unit: entry.unit.isEmpty ? 'serving' : entry.unit,
        ),
      );
      _showCatalog = false;
    });
  }

  Future<void> _showRefineDialog(int index) async {
    final item = _items[index];
    final contextController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    String? explanation;
    double? newCalories;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.refineCaloriesFor(item.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentEstimate(
                    item.caloriesPerUnit.toStringAsFixed(0),
                    _caloriesLabel(item.unit, l10n),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contextController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.extraContextLabel,
                    hintText: l10n.extraContextHint,
                  ),
                ),
                if (explanation != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.suggestedEstimate(
                            newCalories!.toStringAsFixed(0),
                            _caloriesLabel(item.unit, l10n),
                          ),
                          style:
                              Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(explanation!),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            if (newCalories != null)
              FilledButton(
                onPressed: () {
                  setState(() => _items[index].caloriesPerUnit = newCalories!);
                  Navigator.pop(dialogContext);
                },
                child: Text(l10n.apply),
              ),
            FilledButton.tonal(
              onPressed: isLoading
                  ? null
                  : () async {
                      final detail = contextController.text.trim();
                      if (detail.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        final result =
                            await context.read<SessionState>().refineCalories(
                                  name: item.name,
                                  currentEstimate: item.caloriesPerUnit,
                                  unit: item.unit,
                                  context: detail,
                                );
                        setDialogState(() {
                          newCalories =
                              (result['caloriesPerUnit'] as num?)?.toDouble() ??
                                  item.caloriesPerUnit;
                          explanation = result['explanation'] as String? ?? '';
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(l10n.refinementFailed(e.toString()))),
                        );
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.useAI),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final session = context.read<SessionState>();
      for (final item in _items) {
        await session.addMeal(
          MealDraft(
            name: item.name,
            caloriesPerUnit: item.caloriesPerUnit,
            quantity: item.quantity,
            unit: item.unit,
          ),
        );
      }
      if (!mounted) return;
      await _askRecommendation();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedSaveMeals(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _askRecommendation() async {
    final l10n = AppLocalizations.of(context)!;
    final goToRecommendation = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.mealsSaved),
            content: Text(l10n.recommendationQuestion),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.later),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.openRecommendation),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (goToRecommendation) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RecommendationScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = context.watch<SessionState>().foodCatalog;

    return AmbientScaffold(
      appBar: AppBar(title: Text(l10n.logMealAppBar)),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isSaving ? l10n.saving : l10n.saveItems(_items.length),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  eyebrow: l10n.mealEyebrow,
                  title: l10n.describeMealTitle,
                  subtitle: l10n.describeMealSubtitle,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inputController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.mealInputHint,
                    suffixIcon: _isAnalyzing
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _analyzeInput(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isAnalyzing ? null : _analyzeInput,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(l10n.analyzeButton),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showCatalog = !_showCatalog),
                      icon: Icon(
                        _showCatalog
                            ? Icons.close
                            : Icons.history_rounded,
                      ),
                      label: Text(_showCatalog ? l10n.hideHistory : l10n.foodHistory),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showCatalog) ...[
            const SizedBox(height: 16),
            GlassCard(
              child: catalog.isEmpty
                  ? Text(l10n.frequentFoodsEmpty)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addFromHistory,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        ...catalog.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CatalogTile(
                              entry: entry,
                              onTap: () => _addFromCatalog(entry),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: SectionLabel(
                      eyebrow: l10n.draftEyebrow,
                      title: l10n.draftItemsReady(_items.length),
                      subtitle: l10n.draftSubtitle,
                    ),
                  ),
                  InfoPill(
                    label: l10n.total,
                    value: '${_grandTotal.toStringAsFixed(0)} kcal',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              _items.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FoodCard(
                  item: _items[index],
                  onDelete: () => setState(() => _items.removeAt(index)),
                  onRefine: () => _showRefineDialog(index),
                  onChanged: (value) => setState(() {
                    _items[index].quantity = _isWeightOrVolume(_items[index].unit)
                        ? (value / 5).round() * 5.0
                        : (value * 2).round() / 2.0;
                  }),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.entry,
    required this.onTap,
  });

  final FoodCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white.withOpacity(0.55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.caloriesPerUnit.toStringAsFixed(0)} kcal ${_caloriesLabel(entry.unit, l10n)} | ${l10n.usedNTimes(entry.timesUsed)}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.item,
    required this.onDelete,
    required this.onRefine,
    required this.onChanged,
  });

  final _EditableItem item;
  final VoidCallback onDelete;
  final VoidCallback onRefine;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFB55A52),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              InfoPill(label: l10n.quantityLabel, value: item.quantityLabel),
              InfoPill(
                label: l10n.densityLabel,
                value: '${item.caloriesPerUnit.toStringAsFixed(0)} kcal',
                backgroundColor: const Color(0x14D08743),
                foregroundColor: const Color(0xFFD08743),
              ),
              InfoPill(
                label: l10n.itemTotalLabel,
                value: '${item.totalCalories.toStringAsFixed(0)} kcal',
                backgroundColor: const Color(0x145874A8),
                foregroundColor: const Color(0xFF5874A8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.adjustQuantity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: item.quantity.clamp(item.sliderMin, item.sliderMax),
            min: item.sliderMin,
            max: item.sliderMax,
            divisions: item.sliderDivisions,
            label: item.quantityLabel,
            onChanged: onChanged,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRefine,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(l10n.refineCaloriesButton),
            ),
          ),
        ],
      ),
    );
  }
}
