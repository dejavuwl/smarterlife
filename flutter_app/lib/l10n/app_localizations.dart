import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @loadingData.
  ///
  /// In zh, this message translates to:
  /// **'正在加载你的数据…'**
  String get loadingData;

  /// No description provided for @loadingTodayData.
  ///
  /// In zh, this message translates to:
  /// **'正在加载今日数据…'**
  String get loadingTodayData;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'更轻一点，也更稳一点'**
  String get appTagline;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把饮食、运动和体重记录放进一个更清爽的每日视图。'**
  String get appSubtitle;

  /// No description provided for @accountTooltip.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountTooltip;

  /// No description provided for @switchToEmail.
  ///
  /// In zh, this message translates to:
  /// **'切换到邮箱登录'**
  String get switchToEmail;

  /// No description provided for @switchToGoogle.
  ///
  /// In zh, this message translates to:
  /// **'切换到 Google 登录'**
  String get switchToGoogle;

  /// No description provided for @switchToApple.
  ///
  /// In zh, this message translates to:
  /// **'切换到 Apple 登录'**
  String get switchToApple;

  /// No description provided for @quickEntryEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'快捷入口'**
  String get quickEntryEyebrow;

  /// No description provided for @quickEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'今天要记录什么？'**
  String get quickEntryTitle;

  /// No description provided for @quickEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'三个高频入口放在同一层，减少跳转和搜索。'**
  String get quickEntrySubtitle;

  /// No description provided for @logMealTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录饮食'**
  String get logMealTitle;

  /// No description provided for @logMealSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用自然语言描述你刚吃了什么'**
  String get logMealSubtitle;

  /// No description provided for @logWorkoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录运动'**
  String get logWorkoutTitle;

  /// No description provided for @logWorkoutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'补充今天的训练和额外消耗'**
  String get logWorkoutSubtitle;

  /// No description provided for @updateWeightTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新体重'**
  String get updateWeightTitle;

  /// No description provided for @updateWeightSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同步最新体重并重新估算计划'**
  String get updateWeightSubtitle;

  /// No description provided for @aiSuggestionEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'AI 建议'**
  String get aiSuggestionEyebrow;

  /// No description provided for @aiSuggestionTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日智能建议'**
  String get aiSuggestionTitle;

  /// No description provided for @aiSuggestionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据当前饮食和运动数据，生成个性化的剩余计划。'**
  String get aiSuggestionSubtitle;

  /// No description provided for @viewRecommendation.
  ///
  /// In zh, this message translates to:
  /// **'查看建议'**
  String get viewRecommendation;

  /// No description provided for @loginSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录切换失败，请稍后再试'**
  String get loginSwitchFailed;

  /// No description provided for @emailLabel.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordLabel;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmBinding.
  ///
  /// In zh, this message translates to:
  /// **'确认绑定'**
  String get confirmBinding;

  /// No description provided for @emailBindingFailed.
  ///
  /// In zh, this message translates to:
  /// **'邮箱绑定失败，请检查信息后重试'**
  String get emailBindingFailed;

  /// No description provided for @dailyOverviewEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'每日概览'**
  String get dailyOverviewEyebrow;

  /// No description provided for @dailyStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'今天的身体与热量状态'**
  String get dailyStatusTitle;

  /// No description provided for @remainingIntake.
  ///
  /// In zh, this message translates to:
  /// **'剩余摄入'**
  String get remainingIntake;

  /// No description provided for @currentWeight.
  ///
  /// In zh, this message translates to:
  /// **'当前体重'**
  String get currentWeight;

  /// No description provided for @targetWeightMetric.
  ///
  /// In zh, this message translates to:
  /// **'目标体重'**
  String get targetWeightMetric;

  /// No description provided for @todayIntake.
  ///
  /// In zh, this message translates to:
  /// **'今日摄入'**
  String get todayIntake;

  /// No description provided for @todayBurn.
  ///
  /// In zh, this message translates to:
  /// **'今日消耗'**
  String get todayBurn;

  /// No description provided for @deficitTarget.
  ///
  /// In zh, this message translates to:
  /// **'缺口目标'**
  String get deficitTarget;

  /// No description provided for @bmrTdee.
  ///
  /// In zh, this message translates to:
  /// **'基础代谢 / TDEE'**
  String get bmrTdee;

  /// No description provided for @planProgress.
  ///
  /// In zh, this message translates to:
  /// **'计划推进度'**
  String get planProgress;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get today;

  /// No description provided for @logMealAppBar.
  ///
  /// In zh, this message translates to:
  /// **'记录饮食'**
  String get logMealAppBar;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @saveItems.
  ///
  /// In zh, this message translates to:
  /// **'保存 {count} 项'**
  String saveItems(int count);

  /// No description provided for @mealEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'餐食'**
  String get mealEyebrow;

  /// No description provided for @describeMealTitle.
  ///
  /// In zh, this message translates to:
  /// **'描述你刚吃的食物'**
  String get describeMealTitle;

  /// No description provided for @describeMealSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用自然语言描述，应用会将文字拆分为可编辑的食物条目后再保存。'**
  String get describeMealSubtitle;

  /// No description provided for @mealInputHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：200克米饭、一块鸡胸肉、一杯酸奶'**
  String get mealInputHint;

  /// No description provided for @analyzeButton.
  ///
  /// In zh, this message translates to:
  /// **'分析'**
  String get analyzeButton;

  /// No description provided for @hideHistory.
  ///
  /// In zh, this message translates to:
  /// **'隐藏历史'**
  String get hideHistory;

  /// No description provided for @foodHistory.
  ///
  /// In zh, this message translates to:
  /// **'食物历史'**
  String get foodHistory;

  /// No description provided for @frequentFoodsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'保存餐食后，常用食物将显示在这里。'**
  String get frequentFoodsEmpty;

  /// No description provided for @addFromHistory.
  ///
  /// In zh, this message translates to:
  /// **'从历史添加'**
  String get addFromHistory;

  /// No description provided for @draftEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get draftEyebrow;

  /// No description provided for @draftItemsReady.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项待保存'**
  String draftItemsReady(int count);

  /// No description provided for @draftSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仍可调整数量或热量估算后再保存。'**
  String get draftSubtitle;

  /// No description provided for @total.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get total;

  /// No description provided for @refineCaloriesFor.
  ///
  /// In zh, this message translates to:
  /// **'调整 {name} 的热量'**
  String refineCaloriesFor(String name);

  /// No description provided for @currentEstimate.
  ///
  /// In zh, this message translates to:
  /// **'当前估算：{estimate} 千卡 {unit}'**
  String currentEstimate(String estimate, String unit);

  /// No description provided for @extraContextLabel.
  ///
  /// In zh, this message translates to:
  /// **'额外备注'**
  String get extraContextLabel;

  /// No description provided for @extraContextHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：额外加油、低脂版本、成品食品、加了酱'**
  String get extraContextHint;

  /// No description provided for @suggestedEstimate.
  ///
  /// In zh, this message translates to:
  /// **'建议估算：{calories} 千卡 {unit}'**
  String suggestedEstimate(String calories, String unit);

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @useAI.
  ///
  /// In zh, this message translates to:
  /// **'使用 AI'**
  String get useAI;

  /// No description provided for @quantityLabel.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get quantityLabel;

  /// No description provided for @densityLabel.
  ///
  /// In zh, this message translates to:
  /// **'密度'**
  String get densityLabel;

  /// No description provided for @itemTotalLabel.
  ///
  /// In zh, this message translates to:
  /// **'单项合计'**
  String get itemTotalLabel;

  /// No description provided for @adjustQuantity.
  ///
  /// In zh, this message translates to:
  /// **'调整数量'**
  String get adjustQuantity;

  /// No description provided for @refineCaloriesButton.
  ///
  /// In zh, this message translates to:
  /// **'精调热量'**
  String get refineCaloriesButton;

  /// No description provided for @mealsSaved.
  ///
  /// In zh, this message translates to:
  /// **'餐食已保存'**
  String get mealsSaved;

  /// No description provided for @recommendationQuestion.
  ///
  /// In zh, this message translates to:
  /// **'想查看今日剩余时段的最新建议吗？'**
  String get recommendationQuestion;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// No description provided for @openRecommendation.
  ///
  /// In zh, this message translates to:
  /// **'查看建议'**
  String get openRecommendation;

  /// No description provided for @failedSaveMeals.
  ///
  /// In zh, this message translates to:
  /// **'保存餐食失败：{error}'**
  String failedSaveMeals(String error);

  /// No description provided for @failedParseFoodInput.
  ///
  /// In zh, this message translates to:
  /// **'解析食物输入失败：{error}'**
  String failedParseFoodInput(String error);

  /// No description provided for @refinementFailed.
  ///
  /// In zh, this message translates to:
  /// **'精调失败：{error}'**
  String refinementFailed(String error);

  /// No description provided for @caloriesPerUnit.
  ///
  /// In zh, this message translates to:
  /// **'每 {unit}'**
  String caloriesPerUnit(String unit);

  /// No description provided for @caloriesPer100Unit.
  ///
  /// In zh, this message translates to:
  /// **'每 100{unit}'**
  String caloriesPer100Unit(String unit);

  /// No description provided for @usedNTimes.
  ///
  /// In zh, this message translates to:
  /// **'已使用 {n} 次'**
  String usedNTimes(int n);

  /// No description provided for @logWorkoutAppBar.
  ///
  /// In zh, this message translates to:
  /// **'记录运动'**
  String get logWorkoutAppBar;

  /// No description provided for @workoutEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'运动'**
  String get workoutEyebrow;

  /// No description provided for @addTrainingTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加今日训练'**
  String get addTrainingTitle;

  /// No description provided for @addTrainingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'记录运动名称、时长和强度，以便统计今日消耗热量。'**
  String get addTrainingSubtitle;

  /// No description provided for @workoutTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'运动类型'**
  String get workoutTypeLabel;

  /// No description provided for @workoutTypeHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：跑步、散步、骑车、力量训练'**
  String get workoutTypeHint;

  /// No description provided for @durationLabel.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get durationLabel;

  /// No description provided for @minutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutesLabel;

  /// No description provided for @intensityLabel.
  ///
  /// In zh, this message translates to:
  /// **'强度'**
  String get intensityLabel;

  /// No description provided for @lowIntensity.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get lowIntensity;

  /// No description provided for @mediumIntensity.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get mediumIntensity;

  /// No description provided for @highIntensity.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get highIntensity;

  /// No description provided for @saveWorkoutButton.
  ///
  /// In zh, this message translates to:
  /// **'保存运动'**
  String get saveWorkoutButton;

  /// No description provided for @enterWorkoutTypeFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先输入运动类型。'**
  String get enterWorkoutTypeFirst;

  /// No description provided for @failedSaveWorkout.
  ///
  /// In zh, this message translates to:
  /// **'保存运动失败：{error}'**
  String failedSaveWorkout(String error);

  /// No description provided for @setupEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'初始设置'**
  String get setupEyebrow;

  /// No description provided for @createProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建你的身体档案'**
  String get createProfileTitle;

  /// No description provided for @createProfileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些数据用于估算热量目标、进度和每日建议。'**
  String get createProfileSubtitle;

  /// No description provided for @heightLabel.
  ///
  /// In zh, this message translates to:
  /// **'身高（厘米）'**
  String get heightLabel;

  /// No description provided for @currentWeightFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前体重（千克）'**
  String get currentWeightFieldLabel;

  /// No description provided for @targetWeightFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标体重（千克）'**
  String get targetWeightFieldLabel;

  /// No description provided for @targetDaysLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标天数'**
  String get targetDaysLabel;

  /// No description provided for @genderLabel.
  ///
  /// In zh, this message translates to:
  /// **'性别（可选）'**
  String get genderLabel;

  /// No description provided for @maleOption.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get maleOption;

  /// No description provided for @femaleOption.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get femaleOption;

  /// No description provided for @ageLabel.
  ///
  /// In zh, this message translates to:
  /// **'年龄（可选）'**
  String get ageLabel;

  /// No description provided for @createProfileButton.
  ///
  /// In zh, this message translates to:
  /// **'创建档案'**
  String get createProfileButton;

  /// No description provided for @requiredError.
  ///
  /// In zh, this message translates to:
  /// **'必填项'**
  String get requiredError;

  /// No description provided for @invalidNumberError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效数字'**
  String get invalidNumberError;

  /// No description provided for @mustBePositiveError.
  ///
  /// In zh, this message translates to:
  /// **'必须大于 0'**
  String get mustBePositiveError;

  /// No description provided for @failedCreateProfile.
  ///
  /// In zh, this message translates to:
  /// **'创建档案失败：{error}'**
  String failedCreateProfile(String error);

  /// No description provided for @updateWeightAppBar.
  ///
  /// In zh, this message translates to:
  /// **'更新体重'**
  String get updateWeightAppBar;

  /// No description provided for @weightEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'体重'**
  String get weightEyebrow;

  /// No description provided for @syncWeightTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步最新体重'**
  String get syncWeightTitle;

  /// No description provided for @syncWeightSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'更新后，应用将刷新今日热量目标和建议数据。'**
  String get syncWeightSubtitle;

  /// No description provided for @currentRecordLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前记录'**
  String get currentRecordLabel;

  /// No description provided for @weightKgLabel.
  ///
  /// In zh, this message translates to:
  /// **'体重（千克）'**
  String get weightKgLabel;

  /// No description provided for @weightHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：72.4'**
  String get weightHint;

  /// No description provided for @updateWeightButton.
  ///
  /// In zh, this message translates to:
  /// **'更新体重'**
  String get updateWeightButton;

  /// No description provided for @invalidWeightError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的体重（千克）。'**
  String get invalidWeightError;

  /// No description provided for @failedUpdateWeight.
  ///
  /// In zh, this message translates to:
  /// **'更新体重失败：{error}'**
  String failedUpdateWeight(String error);

  /// No description provided for @dailyRecommendationTitle.
  ///
  /// In zh, this message translates to:
  /// **'每日建议'**
  String get dailyRecommendationTitle;

  /// No description provided for @reloadTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reloadTooltip;

  /// No description provided for @targetIntakeLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标摄入'**
  String get targetIntakeLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get remainingLabel;

  /// No description provided for @exerciseTab.
  ///
  /// In zh, this message translates to:
  /// **'运动'**
  String get exerciseTab;

  /// No description provided for @estimatedBurnLabel.
  ///
  /// In zh, this message translates to:
  /// **'预计消耗'**
  String get estimatedBurnLabel;

  /// No description provided for @belowTargetStatus.
  ///
  /// In zh, this message translates to:
  /// **'摄入低于目标'**
  String get belowTargetStatus;

  /// No description provided for @tighterControlStatus.
  ///
  /// In zh, this message translates to:
  /// **'计划需更严格把控'**
  String get tighterControlStatus;

  /// No description provided for @onTrackStatus.
  ///
  /// In zh, this message translates to:
  /// **'今日进展良好'**
  String get onTrackStatus;

  /// No description provided for @failedLoadRecommendation.
  ///
  /// In zh, this message translates to:
  /// **'加载建议失败'**
  String get failedLoadRecommendation;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @preferencesHint.
  ///
  /// In zh, this message translates to:
  /// **'添加偏好备注，如晚餐少吃或多走路。'**
  String get preferencesHint;

  /// No description provided for @regenerateButton.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerateButton;

  /// No description provided for @noExerciseRecommended.
  ///
  /// In zh, this message translates to:
  /// **'今日无额外运动建议，正常活动即可。'**
  String get noExerciseRecommended;

  /// No description provided for @recommendationHistoryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get recommendationHistoryTooltip;

  /// No description provided for @recommendationHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'建议历史'**
  String get recommendationHistoryTitle;

  /// No description provided for @noRecommendationHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史建议。在每日建议页面生成第一条吧。'**
  String get noRecommendationHistory;

  /// No description provided for @bodyStatusAtTime.
  ///
  /// In zh, this message translates to:
  /// **'生成时的身体状态'**
  String get bodyStatusAtTime;

  /// No description provided for @planProgressAtTime.
  ///
  /// In zh, this message translates to:
  /// **'生成时的计划进度'**
  String get planProgressAtTime;

  /// No description provided for @daysElapsed.
  ///
  /// In zh, this message translates to:
  /// **'已过天数'**
  String get daysElapsed;

  /// No description provided for @daysRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余天数'**
  String get daysRemaining;

  /// No description provided for @generatedOn.
  ///
  /// In zh, this message translates to:
  /// **'生成于 {date}'**
  String generatedOn(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
