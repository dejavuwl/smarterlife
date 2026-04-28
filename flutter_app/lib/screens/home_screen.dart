import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/session_state.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/daily_summary_card.dart';
import 'add_meal_screen.dart';
import 'add_workout_screen.dart';
import 'daily_records_screen.dart';
import 'recommendation_screen.dart';
import 'setup_screen.dart';
import 'update_weight_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = context.watch<SessionState>();
    if (session.loading && session.profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.loadingData),
            ],
          ),
        ),
      );
    }
    if (session.profile == null) {
      return const SetupScreen();
    }
    final summary = session.summary;
    if (summary == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.loadingTodayData),
            ],
          ),
        ),
      );
    }

    return AmbientScaffold(
      body: RefreshIndicator(
        onRefresh: session.refreshSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionLabel(
                    eyebrow: 'SmarterLife',
                    title: l10n.appTagline,
                    subtitle: l10n.appSubtitle,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.accountTooltip,
                  onSelected: (value) => _handleMenu(context, value),
                  icon: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Icon(Icons.person_outline),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'email', child: Text(l10n.switchToEmail)),
                    PopupMenuItem(value: 'google', child: Text(l10n.switchToGoogle)),
                    PopupMenuItem(value: 'apple', child: Text(l10n.switchToApple)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            DailySummaryCard(
              summary: summary,
              onTapIntake: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyRecordsScreen(initialTab: 0),
                ),
              ),
              onTapBurn: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyRecordsScreen(initialTab: 1),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    eyebrow: l10n.quickEntryEyebrow,
                    title: l10n.quickEntryTitle,
                    subtitle: l10n.quickEntrySubtitle,
                  ),
                  const SizedBox(height: 18),
                  _ActionTile(
                    icon: Icons.restaurant_outlined,
                    title: l10n.logMealTitle,
                    subtitle: l10n.logMealSubtitle,
                    accent: const Color(0xFF3E8F7C),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddMealScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.directions_run_outlined,
                    title: l10n.logWorkoutTitle,
                    subtitle: l10n.logWorkoutSubtitle,
                    accent: const Color(0xFFD08743),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddWorkoutScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.monitor_weight_outlined,
                    title: l10n.updateWeightTitle,
                    subtitle: l10n.updateWeightSubtitle,
                    accent: const Color(0xFF5874A8),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpdateWeightScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecommendationScreen(),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                      eyebrow: l10n.aiSuggestionEyebrow,
                      title: l10n.aiSuggestionTitle,
                      subtitle: l10n.aiSuggestionSubtitle,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.viewRecommendation,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    final auth = context.read<AuthService>();
    final l10n = AppLocalizations.of(context)!;
    try {
      switch (value) {
        case 'email':
          await _showEmailUpgradeDialog(context, auth);
        case 'google':
          await auth.upgradeAnonymousToGoogle();
        case 'apple':
          await auth.upgradeAnonymousToApple();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginSwitchFailed)),
        );
      }
    }
  }

  Future<void> _showEmailUpgradeDialog(
      BuildContext context, AuthService auth) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.switchToEmail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: l10n.emailLabel),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: l10n.passwordLabel),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await auth.upgradeAnonymousToEmail(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(l10n.emailBindingFailed)),
                  );
                }
              }
            },
            child: Text(l10n.confirmBinding),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
