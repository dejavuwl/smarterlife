use serde::{Deserialize, Serialize};
use serde_json::Value;

// ── Request types ─────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct SetupUserRequest {
    pub height_cm: f64,
    pub weight_kg: f64,
    pub target_weight_kg: f64,
    pub target_days: i64,
    pub gender: Option<String>,
    pub age: Option<i64>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AddMealRequest {
    pub name: String,
    /// kcal/100g when unit is "g"/"ml", otherwise kcal per unit
    pub calories: f64,
    pub quantity: f64,
    #[serde(default)]
    pub unit: String,
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AddWorkoutRequest {
    pub workout_type: String,
    pub duration_minutes: i64,
    pub intensity: String,
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateWeightRequest {
    pub weight_kg: f64,
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdatePlanRequest {
    pub target_weight_kg: Option<f64>,
    pub target_date: Option<String>,
    pub paused: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PlanAdjustmentSuggestionRequest {
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DailySummaryRequest {
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RecommendationRequest {
    pub date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ParseFoodRequest {
    pub input: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetFoodCatalogRequest {}

#[derive(Debug, Serialize, Deserialize)]
pub struct LlmRecommendationRequest {
    pub date: Option<String>,
    pub preferences: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetAiRecommendationHistoryRequest {
    pub limit: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct GetAiRecommendationDetailRequest {
    pub date: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RefineCaloriesRequest {
    pub name: String,
    pub current_estimate: f64,
    pub unit: String,
    pub context: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetDailyRecordsRequest {
    pub date: Option<String>,
}

// ── Response types ────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct DailySummaryResponse {
    pub date: String,
    pub current_weight_kg: f64,
    pub target_weight_kg: f64,
    pub calorie_target: f64,
    pub deficit_target: f64,
    pub calories_consumed: f64,
    pub calories_burned: f64,
    pub remaining_calories: f64,
    pub progress_percent: f64,
    pub bmr: f64,
    pub tdee: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PlanAdjustmentSuggestionResponse {
    #[serde(rename = "targetWeightKg")]
    pub target_weight_kg: f64,
    #[serde(rename = "targetDate")]
    pub target_date: String,
    pub reason: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RecommendationResponse {
    pub status: String,
    #[serde(rename = "recommendedCalorieTarget")]
    pub recommended_calorie_target: f64,
    #[serde(rename = "suggestedMessage")]
    pub suggested_message: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ParsedFoodItem {
    pub name: String,
    #[serde(rename = "caloriesPerUnit")]
    pub calories_per_unit: f64,
    pub quantity: f64,
    pub unit: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ParseFoodResponse {
    pub items: Vec<ParsedFoodItem>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FoodCatalogResponse {
    pub items: Vec<FoodCatalogItem>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RefineCaloriesResponse {
    #[serde(rename = "caloriesPerUnit")]
    pub calories_per_unit: f64,
    pub explanation: String,
}

#[derive(Debug, Serialize)]
pub struct GetDailyRecordsResponse {
    pub date: String,
    pub meals: Vec<Value>,
    pub workouts: Vec<Value>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AiRecommendationSummaryItem {
    pub date: String,
    pub saved_at: String,
    pub status: String,
    pub summary_message: String,
    pub recommended_calorie_target: f64,
    pub weight_kg: f64,
}

#[derive(Debug, Serialize)]
pub struct GetAiRecommendationHistoryResponse {
    pub items: Vec<AiRecommendationSummaryItem>,
}

// ── LLM recommendation ────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct LlmMealItem {
    pub name: String,
    pub calories: f64,
    pub quantity: f64,
    pub unit: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LlmMealGroup {
    #[serde(rename = "mealType")]
    pub meal_type: String,
    #[serde(rename = "mealTypeLabel")]
    pub meal_type_label: String,
    #[serde(rename = "totalCalories")]
    pub total_calories: f64,
    pub items: Vec<LlmMealItem>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LlmExerciseItem {
    pub name: String,
    #[serde(rename = "durationMinutes")]
    pub duration_minutes: i64,
    #[serde(rename = "estimatedCaloriesBurned")]
    pub estimated_calories_burned: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LlmRecommendationResponse {
    pub status: String,
    #[serde(rename = "recommendedCalorieTarget")]
    pub recommended_calorie_target: f64,
    #[serde(rename = "remainingCalories")]
    pub remaining_calories: f64,
    #[serde(rename = "summaryMessage")]
    pub summary_message: String,
    pub meals: Vec<LlmMealGroup>,
    pub exercises: Vec<LlmExerciseItem>,
}

// ── AI recommendation detail ──────────────────────────────────────────────────

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiBodySnapshot {
    #[serde(default)]
    pub height_cm: f64,
    #[serde(default)]
    pub weight_kg: f64,
    #[serde(default)]
    pub target_weight_kg: f64,
    pub gender: Option<String>,
    pub age: Option<i64>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiPlanSnapshot {
    #[serde(default)]
    pub calories_consumed: f64,
    #[serde(default)]
    pub calories_burned: f64,
    #[serde(default)]
    pub remaining_calories: f64,
    #[serde(default)]
    pub deficit_target: f64,
    #[serde(default)]
    pub calorie_target: f64,
    #[serde(default)]
    pub bmr: f64,
    #[serde(default)]
    pub tdee: f64,
    #[serde(default)]
    pub progress_percent: f64,
    #[serde(default)]
    pub days_elapsed: i64,
    #[serde(default)]
    pub days_remaining: i64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiRecommendationDetail {
    #[serde(default)]
    pub date: String,
    #[serde(default)]
    pub saved_at: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub summary_message: String,
    #[serde(default)]
    pub recommended_calorie_target: f64,
    #[serde(default)]
    pub remaining_calories: f64,
    #[serde(default)]
    pub body_snapshot: AiBodySnapshot,
    #[serde(default)]
    pub plan_snapshot: AiPlanSnapshot,
    #[serde(default)]
    pub meals: Vec<LlmMealGroup>,
    #[serde(default)]
    pub exercises: Vec<LlmExerciseItem>,
}

// ── Domain models ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Profile {
    #[serde(default)]
    pub height_cm: f64,
    #[serde(default)]
    pub current_weight_kg: f64,
    #[serde(default)]
    pub start_weight_kg: f64,
    #[serde(default)]
    pub target_weight_kg: f64,
    #[serde(default)]
    pub target_days: i64,
    pub gender: Option<String>,
    pub age: Option<i64>,
    #[serde(default = "crate::logic::current_date_string")]
    pub plan_start_date: String,
    #[serde(default)]
    pub plan_paused: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyStats {
    #[serde(default)]
    pub meals: Vec<Value>,
    #[serde(default)]
    pub workouts: Vec<Value>,
    #[serde(default)]
    pub calories_consumed: f64,
    #[serde(default)]
    pub calories_burned: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub latest_weight_kg: Option<f64>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FoodCatalogItem {
    pub name: String,
    #[serde(rename = "caloriesPerUnit")]
    pub calories_per_unit: f64,
    #[serde(default)]
    pub unit: String,
    #[serde(rename = "timesUsed")]
    pub times_used: i64,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct FoodCatalogDoc {
    #[serde(default)]
    pub items: Vec<FoodCatalogItem>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WeightHistoryEntry {
    pub weight_kg: f64,
    pub recorded_at: String,
    pub source: String,
}

// ── Computed types (used by logic layer) ─────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct ComputedSummary {
    pub bmr: f64,
    pub tdee: f64,
    pub recommended_deficit: f64,
    pub recommended_calorie_target: f64,
    pub current_weight_kg: f64,
    pub target_weight_kg: f64,
    pub calories_consumed: f64,
    pub calories_burned: f64,
    pub remaining_calories: f64,
    pub progress_percent: f64,
}

#[derive(Debug, Clone)]
pub struct PlanEvaluation {
    pub action_type: Option<&'static str>,
    pub message: String,
    pub raw_required_deficit: f64,
    pub max_healthy_deficit: f64,
    pub current_target_date: String,
}
