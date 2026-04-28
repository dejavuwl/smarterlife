import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlanUpdateDraft {
  const PlanUpdateDraft({
    required this.targetWeightKg,
    required this.targetDate,
  });

  final double targetWeightKg;
  final String targetDate;
}

class PlanUpdateDialog extends StatefulWidget {
  const PlanUpdateDialog({
    super.key,
    required this.initialTargetWeightKg,
    required this.initialTargetDate,
    required this.currentWeightKg,
    this.title = '更新计划',
    this.subtitle = '请先调整新的目标完成日期和目标体重。',
  });

  final double initialTargetWeightKg;
  final String initialTargetDate;
  final double currentWeightKg;
  final String title;
  final String subtitle;

  @override
  State<PlanUpdateDialog> createState() => _PlanUpdateDialogState();
}

class _PlanUpdateDialogState extends State<PlanUpdateDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.initialTargetDate);
    _weightController = TextEditingController(
      text: widget.initialTargetWeightKg.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateController.text) ??
        DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  void _submit() {
    final targetWeightKg = double.tryParse(_weightController.text.trim());
    if (targetWeightKg == null ||
        targetWeightKg <= 0 ||
        targetWeightKg > widget.currentWeightKg) {
      return;
    }
    Navigator.of(context).pop(
      PlanUpdateDraft(
        targetWeightKg: targetWeightKg,
        targetDate: _dateController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle),
          const SizedBox(height: 16),
          TextField(
            controller: _dateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: '目标完成日期',
              suffixIcon: Icon(Icons.calendar_today_rounded),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '目标体重 (kg)'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('应用新计划'),
        ),
      ],
    );
  }
}
