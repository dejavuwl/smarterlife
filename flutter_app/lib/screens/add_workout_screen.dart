import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';

class AddWorkoutScreen extends StatefulWidget {
  const AddWorkoutScreen({super.key});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  final _typeController = TextEditingController();
  double _duration = 30;
  String _intensity = 'medium';
  bool _isSaving = false;

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final type = _typeController.text.trim();
    if (type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterWorkoutTypeFirst)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<SessionState>().addWorkout(
            WorkoutDraft(
              type: type,
              durationMinutes: _duration.round(),
              intensity: _intensity,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedSaveWorkout(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final intensityOptions = {
      'low': l10n.lowIntensity,
      'medium': l10n.mediumIntensity,
      'high': l10n.highIntensity,
    };

    return AmbientScaffold(
      appBar: AppBar(title: Text(l10n.logWorkoutAppBar)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  eyebrow: l10n.workoutEyebrow,
                  title: l10n.addTrainingTitle,
                  subtitle: l10n.addTrainingSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _typeController,
                  decoration: InputDecoration(
                    labelText: l10n.workoutTypeLabel,
                    hintText: l10n.workoutTypeHint,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      l10n.durationLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    InfoPill(
                      label: l10n.minutesLabel,
                      value: '${_duration.round()}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _duration,
                  min: 10,
                  max: 180,
                  divisions: 34,
                  label: '${_duration.round()} min',
                  onChanged: (value) => setState(() => _duration = value),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.intensityLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: intensityOptions.entries
                      .map(
                        (entry) => ButtonSegment<String>(
                          value: entry.key,
                          label: Text(entry.value),
                        ),
                      )
                      .toList(),
                  selected: {_intensity},
                  onSelectionChanged: (selection) {
                    setState(() => _intensity = selection.first);
                  },
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
                        : const Icon(Icons.check_rounded),
                    label: Text(_isSaving ? l10n.saving : l10n.saveWorkoutButton),
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
