// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loadingData => 'Loading your data…';

  @override
  String get loadingTodayData => 'Loading today\'s data…';

  @override
  String get appTagline => 'Lighter and steadier, one day at a time';

  @override
  String get appSubtitle =>
      'Track meals, workouts, and weight in one clean daily view.';

  @override
  String get accountTooltip => 'Account';

  @override
  String get switchToEmail => 'Switch to email login';

  @override
  String get switchToGoogle => 'Switch to Google login';

  @override
  String get switchToApple => 'Switch to Apple login';

  @override
  String get quickEntryEyebrow => 'Quick Entry';

  @override
  String get quickEntryTitle => 'What do you want to record today?';

  @override
  String get quickEntrySubtitle =>
      'Three shortcuts in one place — fewer taps, less searching.';

  @override
  String get logMealTitle => 'Log Meal';

  @override
  String get logMealSubtitle =>
      'Describe what you just ate in natural language';

  @override
  String get logWorkoutTitle => 'Log Workout';

  @override
  String get logWorkoutSubtitle =>
      'Add today\'s training and extra calorie burn';

  @override
  String get updateWeightTitle => 'Update Weight';

  @override
  String get updateWeightSubtitle =>
      'Sync latest weight and recalculate your plan';

  @override
  String get aiSuggestionEyebrow => 'AI Recommendation';

  @override
  String get aiSuggestionTitle => 'Today\'s Smart Recommendation';

  @override
  String get aiSuggestionSubtitle =>
      'Generate a personalized plan for the rest of today based on your current diet and workout data.';

  @override
  String get viewRecommendation => 'View recommendation';

  @override
  String get loginSwitchFailed => 'Login switch failed, please try again later';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmBinding => 'Confirm';

  @override
  String get emailBindingFailed =>
      'Email binding failed, please check and retry';

  @override
  String get dailyOverviewEyebrow => 'Daily overview';

  @override
  String get dailyStatusTitle => 'Today\'s body & calorie status';

  @override
  String get remainingIntake => 'Remaining intake';

  @override
  String get currentWeight => 'Current weight';

  @override
  String get targetWeightMetric => 'Target weight';

  @override
  String get todayIntake => 'Today\'s intake';

  @override
  String get todayBurn => 'Today\'s burn';

  @override
  String get deficitTarget => 'Deficit target';

  @override
  String get bmrTdee => 'BMR / TDEE';

  @override
  String get planProgress => 'Plan progress';

  @override
  String get today => 'Today';

  @override
  String get logMealAppBar => 'Log Meal';

  @override
  String get saving => 'Saving...';

  @override
  String saveItems(int count) {
    return 'Save $count items';
  }

  @override
  String get mealEyebrow => 'Meal';

  @override
  String get describeMealTitle => 'Describe what you just ate';

  @override
  String get describeMealSubtitle =>
      'Use natural language, and the app will split the text into editable food items before saving.';

  @override
  String get mealInputHint =>
      'For example: 200g rice, one chicken breast, one yogurt';

  @override
  String get analyzeButton => 'Analyze';

  @override
  String get hideHistory => 'Hide history';

  @override
  String get foodHistory => 'Food history';

  @override
  String get frequentFoodsEmpty =>
      'Your frequently used foods will appear here after you save meals.';

  @override
  String get addFromHistory => 'Add from history';

  @override
  String get draftEyebrow => 'Draft';

  @override
  String draftItemsReady(int count) {
    return '$count item(s) ready to save';
  }

  @override
  String get draftSubtitle =>
      'You can still adjust quantity or refine the calorie estimate before saving.';

  @override
  String get total => 'Total';

  @override
  String refineCaloriesFor(String name) {
    return 'Refine calories for $name';
  }

  @override
  String currentEstimate(String estimate, String unit) {
    return 'Current estimate: $estimate kcal $unit';
  }

  @override
  String get extraContextLabel => 'Extra context';

  @override
  String get extraContextHint =>
      'For example: extra oil, low-fat version, packaged food, added sauce';

  @override
  String suggestedEstimate(String calories, String unit) {
    return 'Suggested estimate: $calories kcal $unit';
  }

  @override
  String get apply => 'Apply';

  @override
  String get useAI => 'Use AI';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get densityLabel => 'Density';

  @override
  String get itemTotalLabel => 'Item total';

  @override
  String get adjustQuantity => 'Adjust quantity';

  @override
  String get refineCaloriesButton => 'Refine calories';

  @override
  String get mealsSaved => 'Meals saved';

  @override
  String get recommendationQuestion =>
      'Do you want to see an updated recommendation for the rest of today?';

  @override
  String get later => 'Later';

  @override
  String get openRecommendation => 'Open recommendation';

  @override
  String failedSaveMeals(String error) {
    return 'Failed to save meals: $error';
  }

  @override
  String failedParseFoodInput(String error) {
    return 'Failed to parse food input: $error';
  }

  @override
  String refinementFailed(String error) {
    return 'Refinement failed: $error';
  }

  @override
  String caloriesPerUnit(String unit) {
    return 'per $unit';
  }

  @override
  String caloriesPer100Unit(String unit) {
    return 'per 100$unit';
  }

  @override
  String usedNTimes(int n) {
    return 'used $n times';
  }

  @override
  String get logWorkoutAppBar => 'Log Workout';

  @override
  String get workoutEyebrow => 'Workout';

  @override
  String get addTrainingTitle => 'Add today\'s training session';

  @override
  String get addTrainingSubtitle =>
      'Record the workout name, duration, and intensity so the daily summary can reflect calories burned.';

  @override
  String get workoutTypeLabel => 'Workout type';

  @override
  String get workoutTypeHint => 'For example: run, walk, cycling, strength';

  @override
  String get durationLabel => 'Duration';

  @override
  String get minutesLabel => 'Minutes';

  @override
  String get intensityLabel => 'Intensity';

  @override
  String get lowIntensity => 'Low';

  @override
  String get mediumIntensity => 'Medium';

  @override
  String get highIntensity => 'High';

  @override
  String get saveWorkoutButton => 'Save workout';

  @override
  String get enterWorkoutTypeFirst => 'Enter a workout type first.';

  @override
  String failedSaveWorkout(String error) {
    return 'Failed to save workout: $error';
  }

  @override
  String get setupEyebrow => 'Setup';

  @override
  String get createProfileTitle => 'Create your body profile';

  @override
  String get createProfileSubtitle =>
      'These numbers are used to estimate calorie targets, progress, and daily recommendations.';

  @override
  String get heightLabel => 'Height (cm)';

  @override
  String get currentWeightFieldLabel => 'Current weight (kg)';

  @override
  String get targetWeightFieldLabel => 'Target weight (kg)';

  @override
  String get targetDaysLabel => 'Target days';

  @override
  String get genderLabel => 'Gender (optional)';

  @override
  String get maleOption => 'Male';

  @override
  String get femaleOption => 'Female';

  @override
  String get ageLabel => 'Age (optional)';

  @override
  String get createProfileButton => 'Create profile';

  @override
  String get requiredError => 'Required';

  @override
  String get invalidNumberError => 'Enter a valid number';

  @override
  String get mustBePositiveError => 'Must be greater than 0';

  @override
  String failedCreateProfile(String error) {
    return 'Failed to create profile: $error';
  }

  @override
  String get updateWeightAppBar => 'Update Weight';

  @override
  String get weightEyebrow => 'Weight';

  @override
  String get syncWeightTitle => 'Sync your latest weight';

  @override
  String get syncWeightSubtitle =>
      'After updating, the app refreshes today\'s calorie target and recommendation data.';

  @override
  String get currentRecordLabel => 'Current record';

  @override
  String get weightKgLabel => 'Weight (kg)';

  @override
  String get weightHint => 'For example: 72.4';

  @override
  String get updateWeightButton => 'Update weight';

  @override
  String get invalidWeightError => 'Enter a valid weight in kilograms.';

  @override
  String failedUpdateWeight(String error) {
    return 'Failed to update weight: $error';
  }

  @override
  String get dailyRecommendationTitle => 'Daily Recommendation';

  @override
  String get reloadTooltip => 'Reload';

  @override
  String get targetIntakeLabel => 'Target intake';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String get exerciseTab => 'Exercise';

  @override
  String get estimatedBurnLabel => 'Estimated burn';

  @override
  String get belowTargetStatus => 'Below target intake';

  @override
  String get tighterControlStatus => 'Plan needs tighter control';

  @override
  String get onTrackStatus => 'On track for today';

  @override
  String get failedLoadRecommendation => 'Failed to load recommendation';

  @override
  String get retry => 'Retry';

  @override
  String get preferencesHint =>
      'Add preference notes, such as lighter dinner or more walking.';

  @override
  String get regenerateButton => 'Regenerate';

  @override
  String get noExerciseRecommended =>
      'No extra exercise is recommended today. A normal activity level is enough.';

  @override
  String get recommendationHistoryTooltip => 'History';

  @override
  String get recommendationHistoryTitle => 'Recommendation History';

  @override
  String get noRecommendationHistory =>
      'No past recommendations yet. Generate your first one from the Daily Recommendation screen.';

  @override
  String get bodyStatusAtTime => 'Body Status at Generation Time';

  @override
  String get planProgressAtTime => 'Plan Progress at Generation Time';

  @override
  String get daysElapsed => 'Days elapsed';

  @override
  String get daysRemaining => 'Days remaining';

  @override
  String generatedOn(String date) {
    return 'Generated on $date';
  }
}
