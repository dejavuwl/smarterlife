import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/plan_update_dialog.dart';

class UpdateWeightScreen extends StatefulWidget {
  const UpdateWeightScreen({super.key});

  @override
  State<UpdateWeightScreen> createState() => _UpdateWeightScreenState();
}

class _UpdateWeightScreenState extends State<UpdateWeightScreen> {
  final _weightController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_weightController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidWeightError)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final evaluation = await context.read<SessionState>().updateWeight(value);
      if (!mounted) return;
      if (evaluation != null &&
          evaluation.actionType != null &&
          evaluation.actionType != 'paused') {
        await _handlePlanAction(evaluation);
        if (!mounted) return;
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedUpdateWeight(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = context.watch<SessionState>().summary;
    if (_weightController.text.isEmpty && summary != null) {
      _weightController.text = summary.currentWeightKg.toStringAsFixed(1);
    }

    return AmbientScaffold(
      appBar: AppBar(title: Text(l10n.updateWeightAppBar)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  eyebrow: l10n.weightEyebrow,
                  title: l10n.syncWeightTitle,
                  subtitle: l10n.syncWeightSubtitle,
                ),
                const SizedBox(height: 18),
                if (summary != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      InfoPill(
                        label: l10n.currentRecordLabel,
                        value:
                            '${summary.currentWeightKg.toStringAsFixed(1)} kg',
                      ),
                      InfoPill(
                        label: l10n.targetWeightMetric,
                        value:
                            '${summary.targetWeightKg.toStringAsFixed(1)} kg',
                        backgroundColor: const Color(0x145874A8),
                        foregroundColor: const Color(0xFF5874A8),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              children: [
                TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.weightKgLabel,
                    hintText: l10n.weightHint,
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                        : const Icon(Icons.monitor_weight_outlined),
                    label:
                        Text(_isSaving ? l10n.saving : l10n.updateWeightButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
