import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _targetDaysController = TextEditingController(text: '90');
  final _ageController = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _targetDaysController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final session = context.read<SessionState>();
    try {
      await session.createProfile(
        UserProfile(
          heightCm: double.parse(_heightController.text.trim()),
          currentWeightKg: double.parse(_weightController.text.trim()),
          targetWeightKg: double.parse(_targetWeightController.text.trim()),
          targetDays: int.parse(_targetDaysController.text.trim()),
          gender: _gender,
          age: _ageController.text.trim().isEmpty
              ? null
              : int.parse(_ageController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedCreateProfile(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = context.watch<SessionState>();
    return AmbientScaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    eyebrow: l10n.setupEyebrow,
                    title: l10n.createProfileTitle,
                    subtitle: l10n.createProfileSubtitle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GlassCard(
              child: Column(
                children: [
                  _numberField(_heightController, l10n.heightLabel, l10n),
                  const SizedBox(height: 14),
                  _numberField(_weightController, l10n.currentWeightFieldLabel, l10n),
                  const SizedBox(height: 14),
                  _numberField(_targetWeightController, l10n.targetWeightFieldLabel, l10n),
                  const SizedBox(height: 14),
                  _numberField(
                    _targetDaysController,
                    l10n.targetDaysLabel,
                    l10n,
                    integerOnly: true,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: [
                      DropdownMenuItem(value: 'male', child: Text(l10n.maleOption)),
                      DropdownMenuItem(value: 'female', child: Text(l10n.femaleOption)),
                    ],
                    decoration: InputDecoration(labelText: l10n.genderLabel),
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 14),
                  _numberField(
                    _ageController,
                    l10n.ageLabel,
                    l10n,
                    required: false,
                    integerOnly: true,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: session.loading ? null : _submit,
                      child: Text(
                        session.loading ? l10n.saving : l10n.createProfileButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    AppLocalizations l10n, {
    bool required = true,
    bool integerOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integerOnly),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(integerOnly ? r'[0-9]' : r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return required ? l10n.requiredError : null;
        }
        final number = integerOnly ? int.tryParse(text) : double.tryParse(text);
        if (number == null) {
          return l10n.invalidNumberError;
        }
        if (number is num && number <= 0) {
          return l10n.mustBePositiveError;
        }
        return null;
      },
    );
  }
}
