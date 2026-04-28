// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get loadingData => '正在加载你的数据…';

  @override
  String get loadingTodayData => '正在加载今日数据…';

  @override
  String get appTagline => '更轻一点，也更稳一点';

  @override
  String get appSubtitle => '把饮食、运动和体重记录放进一个更清爽的每日视图。';

  @override
  String get accountTooltip => '账户';

  @override
  String get switchToEmail => '切换到邮箱登录';

  @override
  String get switchToGoogle => '切换到 Google 登录';

  @override
  String get switchToApple => '切换到 Apple 登录';

  @override
  String get quickEntryEyebrow => '快捷入口';

  @override
  String get quickEntryTitle => '今天要记录什么？';

  @override
  String get quickEntrySubtitle => '三个高频入口放在同一层，减少跳转和搜索。';

  @override
  String get logMealTitle => '记录饮食';

  @override
  String get logMealSubtitle => '用自然语言描述你刚吃了什么';

  @override
  String get logWorkoutTitle => '记录运动';

  @override
  String get logWorkoutSubtitle => '补充今天的训练和额外消耗';

  @override
  String get updateWeightTitle => '更新体重';

  @override
  String get updateWeightSubtitle => '同步最新体重并重新估算计划';

  @override
  String get aiSuggestionEyebrow => 'AI 建议';

  @override
  String get aiSuggestionTitle => '今日智能建议';

  @override
  String get aiSuggestionSubtitle => '根据当前饮食和运动数据，生成个性化的剩余计划。';

  @override
  String get viewRecommendation => '查看建议';

  @override
  String get loginSwitchFailed => '登录切换失败，请稍后再试';

  @override
  String get emailLabel => '邮箱';

  @override
  String get passwordLabel => '密码';

  @override
  String get cancel => '取消';

  @override
  String get confirmBinding => '确认绑定';

  @override
  String get emailBindingFailed => '邮箱绑定失败，请检查信息后重试';

  @override
  String get dailyOverviewEyebrow => '每日概览';

  @override
  String get dailyStatusTitle => '今天的身体与热量状态';

  @override
  String get remainingIntake => '剩余摄入';

  @override
  String get currentWeight => '当前体重';

  @override
  String get targetWeightMetric => '目标体重';

  @override
  String get todayIntake => '今日摄入';

  @override
  String get todayBurn => '今日消耗';

  @override
  String get deficitTarget => '缺口目标';

  @override
  String get bmrTdee => '基础代谢 / TDEE';

  @override
  String get planProgress => '计划推进度';

  @override
  String get today => '今日';

  @override
  String get logMealAppBar => '记录饮食';

  @override
  String get saving => '保存中…';

  @override
  String saveItems(int count) {
    return '保存 $count 项';
  }

  @override
  String get mealEyebrow => '餐食';

  @override
  String get describeMealTitle => '描述你刚吃的食物';

  @override
  String get describeMealSubtitle => '用自然语言描述，应用会将文字拆分为可编辑的食物条目后再保存。';

  @override
  String get mealInputHint => '例如：200克米饭、一块鸡胸肉、一杯酸奶';

  @override
  String get analyzeButton => '分析';

  @override
  String get hideHistory => '隐藏历史';

  @override
  String get foodHistory => '食物历史';

  @override
  String get frequentFoodsEmpty => '保存餐食后，常用食物将显示在这里。';

  @override
  String get addFromHistory => '从历史添加';

  @override
  String get draftEyebrow => '草稿';

  @override
  String draftItemsReady(int count) {
    return '$count 项待保存';
  }

  @override
  String get draftSubtitle => '仍可调整数量或热量估算后再保存。';

  @override
  String get total => '合计';

  @override
  String refineCaloriesFor(String name) {
    return '调整 $name 的热量';
  }

  @override
  String currentEstimate(String estimate, String unit) {
    return '当前估算：$estimate 千卡 $unit';
  }

  @override
  String get extraContextLabel => '额外备注';

  @override
  String get extraContextHint => '例如：额外加油、低脂版本、成品食品、加了酱';

  @override
  String suggestedEstimate(String calories, String unit) {
    return '建议估算：$calories 千卡 $unit';
  }

  @override
  String get apply => '应用';

  @override
  String get useAI => '使用 AI';

  @override
  String get quantityLabel => '数量';

  @override
  String get densityLabel => '密度';

  @override
  String get itemTotalLabel => '单项合计';

  @override
  String get adjustQuantity => '调整数量';

  @override
  String get refineCaloriesButton => '精调热量';

  @override
  String get mealsSaved => '餐食已保存';

  @override
  String get recommendationQuestion => '想查看今日剩余时段的最新建议吗？';

  @override
  String get later => '稍后';

  @override
  String get openRecommendation => '查看建议';

  @override
  String failedSaveMeals(String error) {
    return '保存餐食失败：$error';
  }

  @override
  String failedParseFoodInput(String error) {
    return '解析食物输入失败：$error';
  }

  @override
  String refinementFailed(String error) {
    return '精调失败：$error';
  }

  @override
  String caloriesPerUnit(String unit) {
    return '每 $unit';
  }

  @override
  String caloriesPer100Unit(String unit) {
    return '每 100$unit';
  }

  @override
  String usedNTimes(int n) {
    return '已使用 $n 次';
  }

  @override
  String get logWorkoutAppBar => '记录运动';

  @override
  String get workoutEyebrow => '运动';

  @override
  String get addTrainingTitle => '添加今日训练';

  @override
  String get addTrainingSubtitle => '记录运动名称、时长和强度，以便统计今日消耗热量。';

  @override
  String get workoutTypeLabel => '运动类型';

  @override
  String get workoutTypeHint => '例如：跑步、散步、骑车、力量训练';

  @override
  String get durationLabel => '时长';

  @override
  String get minutesLabel => '分钟';

  @override
  String get intensityLabel => '强度';

  @override
  String get lowIntensity => '低';

  @override
  String get mediumIntensity => '中';

  @override
  String get highIntensity => '高';

  @override
  String get saveWorkoutButton => '保存运动';

  @override
  String get enterWorkoutTypeFirst => '请先输入运动类型。';

  @override
  String failedSaveWorkout(String error) {
    return '保存运动失败：$error';
  }

  @override
  String get setupEyebrow => '初始设置';

  @override
  String get createProfileTitle => '创建你的身体档案';

  @override
  String get createProfileSubtitle => '这些数据用于估算热量目标、进度和每日建议。';

  @override
  String get heightLabel => '身高（厘米）';

  @override
  String get currentWeightFieldLabel => '当前体重（千克）';

  @override
  String get targetWeightFieldLabel => '目标体重（千克）';

  @override
  String get targetDaysLabel => '目标天数';

  @override
  String get genderLabel => '性别（可选）';

  @override
  String get maleOption => '男';

  @override
  String get femaleOption => '女';

  @override
  String get ageLabel => '年龄（可选）';

  @override
  String get createProfileButton => '创建档案';

  @override
  String get requiredError => '必填项';

  @override
  String get invalidNumberError => '请输入有效数字';

  @override
  String get mustBePositiveError => '必须大于 0';

  @override
  String failedCreateProfile(String error) {
    return '创建档案失败：$error';
  }

  @override
  String get updateWeightAppBar => '更新体重';

  @override
  String get weightEyebrow => '体重';

  @override
  String get syncWeightTitle => '同步最新体重';

  @override
  String get syncWeightSubtitle => '更新后，应用将刷新今日热量目标和建议数据。';

  @override
  String get currentRecordLabel => '当前记录';

  @override
  String get weightKgLabel => '体重（千克）';

  @override
  String get weightHint => '例如：72.4';

  @override
  String get updateWeightButton => '更新体重';

  @override
  String get invalidWeightError => '请输入有效的体重（千克）。';

  @override
  String failedUpdateWeight(String error) {
    return '更新体重失败：$error';
  }

  @override
  String get dailyRecommendationTitle => '每日建议';

  @override
  String get reloadTooltip => '重新加载';

  @override
  String get targetIntakeLabel => '目标摄入';

  @override
  String get remainingLabel => '剩余';

  @override
  String get exerciseTab => '运动';

  @override
  String get estimatedBurnLabel => '预计消耗';

  @override
  String get belowTargetStatus => '摄入低于目标';

  @override
  String get tighterControlStatus => '计划需更严格把控';

  @override
  String get onTrackStatus => '今日进展良好';

  @override
  String get failedLoadRecommendation => '加载建议失败';

  @override
  String get retry => '重试';

  @override
  String get preferencesHint => '添加偏好备注，如晚餐少吃或多走路。';

  @override
  String get regenerateButton => '重新生成';

  @override
  String get noExerciseRecommended => '今日无额外运动建议，正常活动即可。';

  @override
  String get recommendationHistoryTooltip => '历史记录';

  @override
  String get recommendationHistoryTitle => '建议历史';

  @override
  String get noRecommendationHistory => '暂无历史建议。在每日建议页面生成第一条吧。';

  @override
  String get bodyStatusAtTime => '生成时的身体状态';

  @override
  String get planProgressAtTime => '生成时的计划进度';

  @override
  String get daysElapsed => '已过天数';

  @override
  String get daysRemaining => '剩余天数';

  @override
  String generatedOn(String date) {
    return '生成于 $date';
  }
}
