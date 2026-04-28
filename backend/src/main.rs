use std::{collections::HashMap, env, net::SocketAddr, sync::Arc};

use gcp_auth::TokenProvider;

use anyhow::{anyhow, Context, Result};
use axum::{
    extract::{Request, State},
    http::{header, HeaderMap, Method, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
    Extension, Json, Router,
};
use chrono::{Datelike, NaiveDate, Utc};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::{debug, error, info};

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            env::var("RUST_LOG").unwrap_or_else(|_| "smarterlife_api=info,tower_http=info".into()),
        )
        .init();

    let firebase_api_key = env::var("FIREBASE_API_KEY")
        .context("FIREBASE_API_KEY is required for Firebase token verification")?;
    let project_id = env::var("GCP_PROJECT")
        .or_else(|_| env::var("GOOGLE_CLOUD_PROJECT"))
        .context("GCP_PROJECT or GOOGLE_CLOUD_PROJECT is required")?;
    let openai_api_key = env::var("OPENAI_API_KEY")
        .context("OPENAI_API_KEY is required for AI food parsing and recommendations")?;
    let openai_base_url =
        env::var("OPENAI_BASE_URL").unwrap_or_else(|_| "https://api.openai.com".to_string());

    let auth_manager: Arc<dyn TokenProvider + Send + Sync> = gcp_auth::provider()
        .await
        .context("failed to initialize GCP authentication — set GOOGLE_APPLICATION_CREDENTIALS or run on GCP")?;

    let state = Arc::new(AppState {
        http: Client::new(),
        firebase_api_key,
        project_id,
        auth_manager,
        openai_api_key,
        openai_base_url,
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/setupUser", post(setup_user))
        .route("/addMeal", post(add_meal))
        .route("/addWorkout", post(add_workout))
        .route("/updateWeight", post(update_weight))
        .route("/updatePlan", post(update_plan))
        .route(
            "/planAdjustmentSuggestion",
            post(plan_adjustment_suggestion),
        )
        .route("/dailySummary", post(daily_summary))
        .route("/recommendation", post(recommendation))
        .route("/parseFood", post(parse_food))
        .route("/getFoodCatalog", post(get_food_catalog))
        .route("/llmRecommendation", post(llm_recommendation))
        .route(
            "/getAiRecommendationHistory",
            post(get_ai_recommendation_history),
        )
        .route(
            "/getAiRecommendationDetail",
            post(get_ai_recommendation_detail),
        )
        .route("/refineCalories", post(refine_calories))
        .route("/getDailyRecords", post(get_daily_records))
        .layer(
            CorsLayer::new()
                .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
                .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE])
                .allow_origin(tower_http::cors::Any),
        )
        .layer(TraceLayer::new_for_http())
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ))
        .with_state(state);

    let port = env::var("PORT")
        .ok()
        .and_then(|s| s.parse::<u16>().ok())
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

#[derive(Clone)]
struct AppState {
    http: Client,
    firebase_api_key: String,
    project_id: String,
    auth_manager: Arc<dyn TokenProvider + Send + Sync>,
    openai_api_key: String,
    openai_base_url: String,
}

#[derive(Clone)]
struct AuthContext {
    user_id: String,
}

async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    mut request: Request,
    next: Next,
) -> Response {
    if request.uri().path() == "/health" {
        return next.run(request).await;
    }

    match verify_authorization(&state, request.headers()).await {
        Ok(user_id) => {
            request.extensions_mut().insert(AuthContext { user_id });
            next.run(request).await
        }
        Err(err) => {
            error!("authorization failed: {err:#}");
            (
                StatusCode::UNAUTHORIZED,
                Json(json!({ "error": err.to_string() })),
            )
                .into_response()
        }
    }
}

async fn verify_authorization(state: &AppState, headers: &HeaderMap) -> Result<String> {
    let value = headers
        .get(header::AUTHORIZATION)
        .ok_or_else(|| anyhow!("missing Authorization header"))?
        .to_str()
        .context("invalid Authorization header")?;
    let token = value
        .strip_prefix("Bearer ")
        .ok_or_else(|| anyhow!("expected Bearer token"))?;

    let url = format!(
        "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key={}",
        state.firebase_api_key
    );
    let response: IdentityLookupResponse = state
        .http
        .post(url)
        .json(&json!({ "idToken": token }))
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;

    response
        .users
        .into_iter()
        .next()
        .map(|user| user.local_id)
        .ok_or_else(|| anyhow!("token lookup returned no users"))
}

async fn health() -> impl IntoResponse {
    Json(json!({ "ok": true }))
}

async fn setup_user(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<SetupUserRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[setupUser] incoming request"
    );
    let firestore = FirestoreClient::new(state);

    let today = current_date_string();
    let profile_doc = json!({
        "heightCm": payload.height_cm,
        "currentWeightKg": payload.weight_kg,
        "startWeightKg": payload.weight_kg,
        "targetWeightKg": payload.target_weight_kg,
        "targetDays": payload.target_days,
        "gender": payload.gender,
        "age": payload.age,
        "planStartDate": today,
        "planPaused": false,
        "updatedAt": firestore.now_timestamp(),
        "createdAt": firestore.now_timestamp(),
    });

    firestore
        .set_document(
            &format!("users/{}", auth.user_id),
            firestore.encode_document(profile_doc),
        )
        .await?;

    firestore
        .create_document_auto_id(
            &format!("users/{}/weightHistory", auth.user_id),
            firestore.encode_document(json!({
                "weightKg": payload.weight_kg,
                "recordedAt": firestore.now_timestamp(),
                "source": "setup"
            })),
        )
        .await?;

    let summary = compute_summary(
        Profile {
            height_cm: payload.height_cm,
            current_weight_kg: payload.weight_kg,
            start_weight_kg: payload.weight_kg,
            target_weight_kg: payload.target_weight_kg,
            target_days: payload.target_days,
            gender: payload.gender.clone(),
            age: payload.age,
            plan_start_date: today.clone(),
            plan_paused: false,
        },
        None,
        &today,
    );

    let resp = json!({ "ok": true, "summary": summary });
    debug!(
        user_id = %auth.user_id,
        response = ?resp.to_string(),
        "[setupUser] response"
    );
    Ok(Json(resp))
}

async fn add_meal(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<AddMealRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[addMeal] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let date = payload.date.unwrap_or_else(current_date_string);
    let mut daily = firestore.get_daily_stats(&auth.user_id, &date).await?;

    // For g/ml units caloriesPerUnit is per 100g/ml; convert to actual total.
    let total_calories = if is_weight_or_volume(&payload.unit) {
        payload.calories * payload.quantity / 100.0
    } else {
        payload.calories * payload.quantity
    };
    let meal_entry = json!({
        "name": payload.name,
        "caloriesPerUnit": payload.calories,
        "unit": payload.unit,
        "quantity": payload.quantity,
        "totalCalories": total_calories,
        "loggedAt": firestore.now_timestamp(),
    });

    daily.meals.push(meal_entry);
    daily.calories_consumed += total_calories;

    firestore
        .save_daily_stats(&auth.user_id, &date, &daily)
        .await?;

    // Upsert to food catalog (best-effort, don't fail the request if this fails)
    if let Err(e) = firestore
        .upsert_food_catalog(
            &auth.user_id,
            &payload.name,
            payload.calories,
            &payload.unit,
        )
        .await
    {
        error!("failed to upsert food catalog: {e:#}");
    }

    let resp = json!({
        "ok": true,
        "date": date,
        "caloriesConsumed": daily.calories_consumed
    });
    debug!(
        user_id = %auth.user_id,
        response = ?resp.to_string(),
        "[addMeal] response"
    );
    Ok(Json(resp))
}

async fn add_workout(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<AddWorkoutRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[addWorkout] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let date = payload.date.unwrap_or_else(current_date_string);
    let mut daily = firestore.get_daily_stats(&auth.user_id, &date).await?;

    let intensity_multiplier = match payload.intensity.as_str() {
        "low" => 4.0,
        "medium" => 6.0,
        "high" => 8.0,
        _ => 5.0,
    };
    let burned = (payload.duration_minutes as f64 * intensity_multiplier).round();

    let workout_entry = json!({
        "type": payload.workout_type,
        "durationMinutes": payload.duration_minutes,
        "intensity": payload.intensity,
        "estimatedCaloriesBurned": burned,
        "loggedAt": firestore.now_timestamp(),
    });

    daily.workouts.push(workout_entry);
    daily.calories_burned += burned;

    firestore
        .save_daily_stats(&auth.user_id, &date, &daily)
        .await?;

    let resp = json!({
        "ok": true,
        "date": date,
        "caloriesBurned": daily.calories_burned
    });
    debug!(
        user_id = %auth.user_id,
        response = ?resp.to_string(),
        "[addWorkout] response"
    );
    Ok(Json(resp))
}

async fn update_weight(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<UpdateWeightRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[updateWeight] incoming request"
    );
    let firestore = FirestoreClient::new(state.clone());
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;

    let updated_profile = json!({
        "heightCm": profile.height_cm,
        "currentWeightKg": payload.weight_kg,
        "startWeightKg": profile.start_weight_kg,
        "targetWeightKg": profile.target_weight_kg,
        "targetDays": profile.target_days,
        "gender": profile.gender,
        "age": profile.age,
        "planStartDate": profile.plan_start_date,
        "planPaused": profile.plan_paused,
        "updatedAt": firestore.now_timestamp(),
        "createdAt": firestore.now_timestamp(),
    });

    firestore
        .set_document(
            &format!("users/{}", auth.user_id),
            firestore.encode_document(updated_profile),
        )
        .await?;

    firestore
        .create_document_auto_id(
            &format!("users/{}/weightHistory", auth.user_id),
            firestore.encode_document(json!({
                "weightKg": payload.weight_kg,
                "recordedAt": firestore.now_timestamp(),
                "source": "manual_update",
            })),
        )
        .await?;

    let mut daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    daily.latest_weight_kg = Some(payload.weight_kg);
    firestore
        .save_daily_stats(&auth.user_id, &date, &daily)
        .await?;

    let updated_profile = Profile {
        current_weight_kg: payload.weight_kg,
        ..profile
    };
    let resp = json!({
        "ok": true,
        "planEvaluation": plan_evaluation_json(&evaluate_plan_state(&updated_profile, &date), &updated_profile),
    });
    debug!(
        user_id = %auth.user_id,
        response = ?resp.to_string(),
        "[updateWeight] response"
    );
    Ok(Json(resp))
}

async fn daily_summary(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<DailySummaryRequest>,
) -> ApiResult<Json<DailySummaryResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[dailySummary] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    let summary = compute_summary(profile, Some(daily), &date);

    let resp = DailySummaryResponse {
        date,
        current_weight_kg: summary.current_weight_kg,
        target_weight_kg: summary.target_weight_kg,
        calorie_target: summary.recommended_calorie_target,
        deficit_target: summary.recommended_deficit,
        calories_consumed: summary.calories_consumed,
        calories_burned: summary.calories_burned,
        remaining_calories: summary.remaining_calories,
        progress_percent: summary.progress_percent,
        bmr: summary.bmr,
        tdee: summary.tdee,
    };
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&resp).unwrap_or_default(),
        "[dailySummary] response"
    );
    Ok(Json(resp))
}

async fn update_plan(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<UpdatePlanRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[updatePlan] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let today = current_date_string();

    let paused = payload.paused.unwrap_or(false);
    let target_weight_kg = payload.target_weight_kg.unwrap_or(profile.target_weight_kg);
    let target_days = if paused {
        profile.target_days
    } else {
        let target_date = payload.target_date.as_deref().ok_or_else(|| {
            ApiError::bad_request("target_date is required when updating an active plan")
        })?;
        let target = NaiveDate::parse_from_str(target_date, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request("target_date must be YYYY-MM-DD"))?;
        let start = NaiveDate::parse_from_str(&today, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request("failed to parse current date"))?;
        (target - start).num_days().max(1)
    };

    let updated_profile = json!({
        "heightCm": profile.height_cm,
        "currentWeightKg": profile.current_weight_kg,
        "startWeightKg": if paused { profile.start_weight_kg } else { profile.current_weight_kg },
        "targetWeightKg": target_weight_kg,
        "targetDays": target_days,
        "gender": profile.gender,
        "age": profile.age,
        "planStartDate": if paused { profile.plan_start_date } else { today.clone() },
        "planPaused": paused,
        "updatedAt": firestore.now_timestamp(),
        "createdAt": firestore.now_timestamp(),
    });

    firestore
        .set_document(
            &format!("users/{}", auth.user_id),
            firestore.encode_document(updated_profile),
        )
        .await?;

    let refreshed = firestore.get_profile(&auth.user_id).await?;
    let resp = json!({
        "ok": true,
        "planEvaluation": plan_evaluation_json(&evaluate_plan_state(&refreshed, &today), &refreshed),
    });
    debug!(
        user_id = %auth.user_id,
        response = ?resp.to_string(),
        "[updatePlan] response"
    );
    Ok(Json(resp))
}

async fn recommendation(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<RecommendationRequest>,
) -> ApiResult<Json<RecommendationResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[recommendation] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    let rec = compute_recommendation(profile, daily, &date)?;
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&rec).unwrap_or_default(),
        "[recommendation] response"
    );
    Ok(Json(rec))
}

#[derive(Debug, Serialize, Deserialize)]
struct SetupUserRequest {
    height_cm: f64,
    weight_kg: f64,
    target_weight_kg: f64,
    target_days: i64,
    gender: Option<String>,
    age: Option<i64>,
}

#[derive(Debug, Serialize, Deserialize)]
struct AddMealRequest {
    name: String,
    /// kcal/100g when unit is "g"/"ml", otherwise kcal per unit
    calories: f64,
    /// actual quantity in grams, ml, or count
    quantity: f64,
    /// the display unit ("g", "ml", "个", "碗", etc.)
    #[serde(default)]
    unit: String,
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct AddWorkoutRequest {
    workout_type: String,
    duration_minutes: i64,
    intensity: String,
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct UpdateWeightRequest {
    weight_kg: f64,
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct UpdatePlanRequest {
    target_weight_kg: Option<f64>,
    target_date: Option<String>,
    paused: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
struct PlanAdjustmentSuggestionRequest {
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct DailySummaryRequest {
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct RecommendationRequest {
    date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct ParseFoodRequest {
    input: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct GetFoodCatalogRequest {}

#[derive(Debug, Serialize, Deserialize)]
struct LlmRecommendationRequest {
    date: Option<String>,
    preferences: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct DailySummaryResponse {
    date: String,
    current_weight_kg: f64,
    target_weight_kg: f64,
    calorie_target: f64,
    deficit_target: f64,
    calories_consumed: f64,
    calories_burned: f64,
    remaining_calories: f64,
    progress_percent: f64,
    bmr: f64,
    tdee: f64,
}

#[derive(Debug, Serialize, Deserialize)]
struct PlanAdjustmentSuggestionResponse {
    #[serde(rename = "targetWeightKg")]
    target_weight_kg: f64,
    #[serde(rename = "targetDate")]
    target_date: String,
    reason: String,
}

const MAX_HEALTHY_DAILY_DEFICIT: f64 = 900.0;

#[derive(Debug, Serialize, Deserialize)]
struct RecommendationResponse {
    status: String,
    #[serde(rename = "recommendedCalorieTarget")]
    recommended_calorie_target: f64,
    #[serde(rename = "suggestedMessage")]
    suggested_message: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct ParsedFoodItem {
    name: String,
    #[serde(rename = "caloriesPerUnit")]
    calories_per_unit: f64,
    quantity: f64,
    unit: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct ParseFoodResponse {
    items: Vec<ParsedFoodItem>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct FoodCatalogItem {
    name: String,
    /// kcal/100g for g/ml units, kcal/unit otherwise
    #[serde(rename = "caloriesPerUnit")]
    calories_per_unit: f64,
    /// display unit ("g", "ml", "个", etc.)
    #[serde(default)]
    unit: String,
    #[serde(rename = "timesUsed")]
    times_used: i64,
}

#[derive(Debug, Serialize, Deserialize)]
struct FoodCatalogResponse {
    items: Vec<FoodCatalogItem>,
}

#[derive(Debug, Serialize, Deserialize)]
struct LlmMealItem {
    name: String,
    calories: f64,
    quantity: f64,
    unit: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct LlmMealGroup {
    #[serde(rename = "mealType")]
    meal_type: String,
    #[serde(rename = "mealTypeLabel")]
    meal_type_label: String,
    #[serde(rename = "totalCalories")]
    total_calories: f64,
    items: Vec<LlmMealItem>,
}

#[derive(Debug, Serialize, Deserialize)]
struct LlmExerciseItem {
    name: String,
    #[serde(rename = "durationMinutes")]
    duration_minutes: i64,
    #[serde(rename = "estimatedCaloriesBurned")]
    estimated_calories_burned: f64,
}

#[derive(Debug, Serialize, Deserialize)]
struct LlmRecommendationResponse {
    status: String,
    #[serde(rename = "recommendedCalorieTarget")]
    recommended_calorie_target: f64,
    #[serde(rename = "remainingCalories")]
    remaining_calories: f64,
    #[serde(rename = "summaryMessage")]
    summary_message: String,
    meals: Vec<LlmMealGroup>,
    exercises: Vec<LlmExerciseItem>,
}

#[derive(Debug, Deserialize)]
struct GetAiRecommendationHistoryRequest {
    limit: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AiRecommendationSummaryItem {
    date: String,
    saved_at: String,
    status: String,
    summary_message: String,
    recommended_calorie_target: f64,
    weight_kg: f64,
}

#[derive(Debug, Serialize)]
struct GetAiRecommendationHistoryResponse {
    items: Vec<AiRecommendationSummaryItem>,
}

#[derive(Debug, Deserialize)]
struct GetAiRecommendationDetailRequest {
    date: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AiBodySnapshot {
    height_cm: f64,
    weight_kg: f64,
    target_weight_kg: f64,
    gender: Option<String>,
    age: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AiPlanSnapshot {
    calories_consumed: f64,
    calories_burned: f64,
    remaining_calories: f64,
    deficit_target: f64,
    calorie_target: f64,
    bmr: f64,
    tdee: f64,
    progress_percent: f64,
    days_elapsed: i64,
    days_remaining: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AiRecommendationDetail {
    date: String,
    saved_at: String,
    status: String,
    summary_message: String,
    recommended_calorie_target: f64,
    remaining_calories: f64,
    body_snapshot: AiBodySnapshot,
    plan_snapshot: AiPlanSnapshot,
    meals: Vec<LlmMealGroup>,
    exercises: Vec<LlmExerciseItem>,
}

#[derive(Debug, Serialize, Deserialize)]
struct IdentityLookupResponse {
    #[serde(default)]
    users: Vec<IdentityLookupUser>,
}

#[derive(Debug, Serialize, Deserialize)]
struct IdentityLookupUser {
    #[serde(rename = "localId")]
    local_id: String,
}

#[derive(Debug, Clone)]
struct Profile {
    height_cm: f64,
    current_weight_kg: f64,
    start_weight_kg: f64,
    target_weight_kg: f64,
    target_days: i64,
    gender: Option<String>,
    age: Option<i64>,
    plan_start_date: String,
    plan_paused: bool,
}

#[derive(Debug, Clone, Default)]
struct DailyStats {
    meals: Vec<Value>,
    workouts: Vec<Value>,
    calories_consumed: f64,
    calories_burned: f64,
    latest_weight_kg: Option<f64>,
}

#[derive(Debug, Serialize)]
struct ComputedSummary {
    bmr: f64,
    tdee: f64,
    recommended_deficit: f64,
    recommended_calorie_target: f64,
    current_weight_kg: f64,
    target_weight_kg: f64,
    calories_consumed: f64,
    calories_burned: f64,
    remaining_calories: f64,
    progress_percent: f64,
}

fn compute_summary(profile: Profile, daily: Option<DailyStats>, today: &str) -> ComputedSummary {
    let age = profile.age.unwrap_or(30) as f64;
    let current_weight = profile.current_weight_kg;
    let bmr = match profile.gender.as_deref() {
        Some("male") => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age + 5.0,
        Some("female") => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age - 161.0,
        _ => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age - 78.0,
    };
    let tdee = bmr * 1.4;

    let total_loss_needed = (profile.start_weight_kg - profile.target_weight_kg).max(0.0);
    let remaining_loss = (current_weight - profile.target_weight_kg).max(0.0);
    let total_deficit_needed = remaining_loss * 7700.0;
    // Compute remaining days until the plan end date so a late weight update
    // doesn't underestimate the required daily deficit by dividing by the full
    // original plan length instead of the days actually left.
    let days_left = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(today, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(1) as f64,
            _ => profile.target_days.max(1) as f64,
        }
    };
    let recommended_deficit = if profile.plan_paused || current_weight <= profile.target_weight_kg {
        0.0
    } else {
        (total_deficit_needed / days_left).clamp(0.0, MAX_HEALTHY_DAILY_DEFICIT)
    };
    let recommended_calorie_target =
        if profile.plan_paused || current_weight <= profile.target_weight_kg {
            tdee
        } else {
            (tdee - recommended_deficit).max(1200.0)
        };

    let daily = daily.unwrap_or_default();
    let remaining_calories =
        recommended_calorie_target - daily.calories_consumed + daily.calories_burned;
    let progress_percent = if total_loss_needed <= 0.0 {
        1.0
    } else {
        ((profile.start_weight_kg - current_weight) / total_loss_needed).clamp(0.0, 1.0)
    };

    ComputedSummary {
        bmr: round1(bmr),
        tdee: round1(tdee),
        recommended_deficit: round1(recommended_deficit),
        recommended_calorie_target: round1(recommended_calorie_target),
        current_weight_kg: round1(current_weight),
        target_weight_kg: round1(profile.target_weight_kg),
        calories_consumed: round1(daily.calories_consumed),
        calories_burned: round1(daily.calories_burned),
        remaining_calories: round1(remaining_calories),
        progress_percent: (progress_percent * 1000.0).round() / 10.0,
    }
}

#[derive(Debug, Clone)]
struct PlanEvaluation {
    action_type: Option<&'static str>,
    message: String,
    raw_required_deficit: f64,
    max_healthy_deficit: f64,
    current_target_date: String,
}

fn current_target_date(profile: &Profile) -> String {
    NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
        .ok()
        .and_then(|start| {
            start.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64))
        })
        .map(|d| d.format("%Y-%m-%d").to_string())
        .unwrap_or_else(|| profile.plan_start_date.clone())
}

fn raw_required_deficit(profile: &Profile, today: &str) -> f64 {
    if profile.plan_paused || profile.current_weight_kg <= profile.target_weight_kg {
        return 0.0;
    }
    let remaining_loss = (profile.current_weight_kg - profile.target_weight_kg).max(0.0);
    let total_deficit_needed = remaining_loss * 7700.0;
    let days_left = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(today, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(1) as f64,
            _ => profile.target_days.max(1) as f64,
        }
    };
    total_deficit_needed / days_left
}

fn evaluate_plan_state(profile: &Profile, today: &str) -> PlanEvaluation {
    let raw_deficit = raw_required_deficit(profile, today);
    let current_target_date = current_target_date(profile);
    if profile.current_weight_kg <= profile.target_weight_kg {
        PlanEvaluation {
            action_type: Some("completed_or_record_only"),
            message: "当前体重已经达到或超过原计划目标。请开启新计划，或先切换为仅记录模式。"
                .to_string(),
            raw_required_deficit: 0.0,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date,
        }
    } else if !profile.plan_paused && raw_deficit > MAX_HEALTHY_DAILY_DEFICIT {
        PlanEvaluation {
            action_type: Some("update_or_pause"),
            message: format!(
                "按当前计划剩余时间计算，日均热量赤字约为 {:.0} kcal，已超过健康上限 {:.0} kcal。建议先更新目标日期或目标体重，或暂停计划只做记录。",
                raw_deficit, MAX_HEALTHY_DAILY_DEFICIT
            ),
            raw_required_deficit: raw_deficit,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date,
        }
    } else if profile.plan_paused {
        PlanEvaluation {
            action_type: Some("paused"),
            message: "当前计划已暂停，将以健康维持为目标给出建议。".to_string(),
            raw_required_deficit: 0.0,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date,
        }
    } else {
        PlanEvaluation {
            action_type: None,
            message: String::new(),
            raw_required_deficit: raw_deficit,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date,
        }
    }
}

fn plan_evaluation_json(plan: &PlanEvaluation, profile: &Profile) -> Value {
    json!({
        "actionRequired": plan.action_type.is_some() && plan.action_type != Some("paused"),
        "actionType": plan.action_type,
        "message": plan.message,
        "rawRequiredDeficit": round1(plan.raw_required_deficit),
        "maxHealthyDeficit": plan.max_healthy_deficit,
        "currentTargetWeightKg": round1(profile.target_weight_kg),
        "currentTargetDate": plan.current_target_date,
        "planPaused": profile.plan_paused,
    })
}

fn compute_recommendation(
    profile: Profile,
    daily: DailyStats,
    today: &str,
) -> Result<RecommendationResponse> {
    let base_summary = compute_summary(profile.clone(), Some(daily.clone()), today);
    let start_date = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
        .context("invalid planStartDate")?;
    let today = NaiveDate::parse_from_str(today, "%Y-%m-%d").context("invalid date")?;
    let elapsed_days = (today - start_date).num_days().max(0) as f64;
    let total_loss_needed = (profile.start_weight_kg - profile.target_weight_kg).max(0.0);
    let planned_loss = if profile.target_days <= 0 {
        0.0
    } else {
        total_loss_needed * (elapsed_days / profile.target_days as f64).clamp(0.0, 1.0)
    };
    let actual_loss = (profile.start_weight_kg - profile.current_weight_kg).max(0.0);
    let lag = planned_loss - actual_loss;

    let (status, calorie_target, message) = if profile.current_weight_kg <= profile.target_weight_kg
    {
        (
            "balanced",
            round1(base_summary.tdee),
            "Goal reached. Switch to maintenance calories and keep your training rhythm."
                .to_string(),
        )
    } else if lag > 0.4 {
        let tightened_target = (base_summary.recommended_calorie_target - 150.0).max(1200.0);
        (
            "overweight_adjusted",
            round1(tightened_target),
            format!(
                "Weight loss is behind plan by about {:.1} kg. Aim for {:.0} kcal today or add 20-30 minutes of moderate exercise.",
                lag, tightened_target
            ),
        )
    } else if base_summary.remaining_calories < 0.0 {
        (
            "deficit",
            base_summary.recommended_calorie_target,
            format!(
                "You are about {:.0} kcal over the daily budget. Keep dinner high-protein and add 15-20 minutes of light to moderate activity.",
                base_summary.remaining_calories.abs()
            ),
        )
    } else {
        (
            "balanced",
            base_summary.recommended_calorie_target,
            format!(
                "Progress is on track. You still have about {:.0} kcal remaining today. Favor high-protein and high-fiber food choices.",
                base_summary.remaining_calories.max(0.0)
            ),
        )
    };

    Ok(RecommendationResponse {
        status: status.to_string(),
        recommended_calorie_target: calorie_target,
        suggested_message: message,
    })
}

// ──────────────────────────────────────────────────────────────────────────────
// /refineCalories structs (defined early so handler can reference them)
// ──────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
struct RefineCaloriesRequest {
    /// Food name
    name: String,
    /// Current estimate: kcal/100g for g/ml units, kcal/unit otherwise
    current_estimate: f64,
    /// The unit returned by parseFood (e.g. "g", "ml", "个", "碗")
    unit: String,
    /// Free-text context the user provides (cooking method, ratios, etc.)
    context: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct RefineCaloriesResponse {
    /// Refined estimate in the same semantics as current_estimate
    #[serde(rename = "caloriesPerUnit")]
    calories_per_unit: f64,
    /// One-sentence explanation of the refinement
    explanation: String,
}

// ──────────────────────────────────────────────────────────────────────────────
// OpenAI helper
// ──────────────────────────────────────────────────────────────────────────────

async fn call_openai_json(state: &AppState, messages: Vec<Value>) -> Result<String> {
    let body = json!({
        "model": "gpt-5.4",
        "messages": messages,
        "temperature": 0.4,
        "response_format": { "type": "json_object" }
    });
    let url = format!(
        "{}/v1/chat/completions",
        state.openai_base_url.trim_end_matches('/')
    );

    tracing::debug!(
        url = %url,
        model = "gpt-5.4",
        temperature = 0.4,
        message_count = messages.len(),
        messages = %serde_json::to_string(&messages).unwrap_or_default(),
        "sending LLM request"
    );

    let http_response = state
        .http
        .post(&url)
        .bearer_auth(&state.openai_api_key)
        .json(&body)
        .send()
        .await
        .context("failed to send OpenAI request")?;

    let status = http_response.status();
    tracing::debug!(status = %status, "received LLM HTTP response");

    let http_response = http_response
        .error_for_status()
        .context("OpenAI returned error status")?;

    let response = http_response
        .json::<Value>()
        .await
        .context("failed to parse OpenAI response")?;

    tracing::debug!(
        response = %serde_json::to_string(&response).unwrap_or_default(),
        "LLM response body"
    );

    let content = response["choices"][0]["message"]["content"]
        .as_str()
        .ok_or_else(|| anyhow!("no content in OpenAI response"))?
        .to_string();

    tracing::debug!(
        finish_reason = %response["choices"][0]["finish_reason"].as_str().unwrap_or("unknown"),
        prompt_tokens = response["usage"]["prompt_tokens"].as_u64().unwrap_or(0),
        completion_tokens = response["usage"]["completion_tokens"].as_u64().unwrap_or(0),
        total_tokens = response["usage"]["total_tokens"].as_u64().unwrap_or(0),
        content_length = content.len(),
        "LLM request complete"
    );

    Ok(content)
}

// ──────────────────────────────────────────────────────────────────────────────
// /parseFood
// ──────────────────────────────────────────────────────────────────────────────

async fn parse_food(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<ParseFoodRequest>,
) -> ApiResult<Json<ParseFoodResponse>> {
    debug!(user_id = %auth.user_id, input = %payload.input, "[parseFood] incoming request");

    let firestore = FirestoreClient::new(state.clone());
    let catalog = firestore
        .get_food_catalog(&auth.user_id)
        .await
        .unwrap_or_default();

    let catalog_hint = if catalog.is_empty() {
        String::new()
    } else {
        let entries: Vec<String> = catalog
            .iter()
            .take(30)
            .map(|e| format!("- {}: {}kcal/份", e.name, e.calories_per_unit))
            .collect();
        format!(
            "\n用户历史食物参考（优先使用其中的热量数据）：\n{}",
            entries.join("\n")
        )
    };

    let system_prompt = format!(
        r#"你是专业营养分析助手。用户会描述吃了什么食物，请解析出每种食物，估算热量和数量。
{}
规则：
1. 将用户描述拆分为独立的食物条目
2. unit 选择最自然的计量单位：重量/体积类用 g 或 ml，固体食物默认用 g，液体用 ml；计件食物用 个/碗/杯/片/块等中文单位
3. caloriesPerUnit 的含义取决于 unit：
   - unit 为 g 或 ml 时：caloriesPerUnit = 每 100g 或每 100ml 的热量（kcal）
   - unit 为其他（个/碗/份/杯/片等）时：caloriesPerUnit = 每一个该单位的热量（kcal）
4. quantity 表示实际数量（克数、毫升数或件数）
5. 若用户历史有相同食物，优先使用历史热量数据

只返回 JSON，格式：
{{"items": [{{"name": "食物名", "caloriesPerUnit": 数字, "quantity": 数字, "unit": "单位"}}]}}"#,
        catalog_hint
    );

    let messages = vec![
        json!({"role": "system", "content": system_prompt}),
        json!({"role": "user", "content": payload.input}),
    ];

    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[parseFood] OpenAI response");

    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse OpenAI JSON response")?;

    let items: Vec<ParsedFoodItem> = parsed["items"]
        .as_array()
        .ok_or_else(|| anyhow!("OpenAI response missing 'items' array"))?
        .iter()
        .filter_map(|item| {
            let name = item["name"].as_str()?.to_string();
            let calories_per_unit = item["caloriesPerUnit"].as_f64()?;
            let quantity = item["quantity"].as_f64().unwrap_or(1.0);
            let unit = item["unit"].as_str().unwrap_or("份").to_string();
            Some(ParsedFoodItem {
                name,
                calories_per_unit,
                quantity,
                unit,
            })
        })
        .collect();

    Ok(Json(ParseFoodResponse { items }))
}

// ──────────────────────────────────────────────────────────────────────────────
// /getFoodCatalog
// ──────────────────────────────────────────────────────────────────────────────

async fn get_food_catalog(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(_payload): Json<GetFoodCatalogRequest>,
) -> ApiResult<Json<FoodCatalogResponse>> {
    debug!(user_id = %auth.user_id, "[getFoodCatalog] incoming request");
    let firestore = FirestoreClient::new(state);
    let mut items = firestore
        .get_food_catalog(&auth.user_id)
        .await
        .unwrap_or_default();
    // Sort by timesUsed descending
    items.sort_by(|a, b| b.times_used.cmp(&a.times_used));
    Ok(Json(FoodCatalogResponse { items }))
}

async fn plan_adjustment_suggestion(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<PlanAdjustmentSuggestionRequest>,
) -> ApiResult<Json<PlanAdjustmentSuggestionResponse>> {
    let firestore = FirestoreClient::new(state.clone());
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let plan = evaluate_plan_state(&profile, &date);
    if profile.current_weight_kg <= profile.target_weight_kg {
        return Err(ApiError::bad_request("plan already completed"));
    }

    let system_prompt = r#"你是专业营养师。用户当前减重计划过于激进，请在健康前提下给出更现实的新目标。
只返回 JSON：
{"targetWeightKg": 数字, "targetDate": "YYYY-MM-DD", "reason": "中文一句话说明"}"#;
    let user_prompt = format!(
        "用户当前体重 {:.1}kg，当前目标体重 {:.1}kg，当前目标完成日期 {}。按现计划需要每日热量赤字 {:.0}kcal，健康上限为 {:.0}kcal。请给出更现实的新目标体重和目标日期，优先保留减重方向，但不要给出不健康方案。",
        profile.current_weight_kg,
        profile.target_weight_kg,
        plan.current_target_date,
        plan.raw_required_deficit,
        plan.max_healthy_deficit
    );

    let content = call_openai_json(
        &state,
        vec![
            json!({"role": "system", "content": system_prompt}),
            json!({"role": "user", "content": user_prompt}),
        ],
    )
    .await?;
    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse plan adjustment suggestion")?;
    let target_weight_kg = parsed["targetWeightKg"]
        .as_f64()
        .unwrap_or(profile.target_weight_kg)
        .min(profile.current_weight_kg)
        .max(profile.target_weight_kg);
    let target_date = parsed["targetDate"]
        .as_str()
        .unwrap_or(&plan.current_target_date)
        .to_string();
    let reason = parsed["reason"]
        .as_str()
        .unwrap_or("建议延长周期或分阶段减重，以确保计划更可持续。")
        .to_string();

    Ok(Json(PlanAdjustmentSuggestionResponse {
        target_weight_kg: round1(target_weight_kg),
        target_date,
        reason,
    }))
}

// ──────────────────────────────────────────────────────────────────────────────
// /llmRecommendation
// ──────────────────────────────────────────────────────────────────────────────

async fn llm_recommendation(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<LlmRecommendationRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[llmRecommendation] incoming request"
    );
    let firestore = FirestoreClient::new(state.clone());
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    let summary = compute_summary(profile.clone(), Some(daily.clone()), &date);
    let plan = evaluate_plan_state(&profile, &date);
    if matches!(
        plan.action_type,
        Some("update_or_pause") | Some("completed_or_record_only")
    ) {
        return Ok(Json(json!({
            "kind": "plan_action_required",
            "planEvaluation": plan_evaluation_json(&plan, &profile),
        })));
    }

    // Build context strings
    let age = profile.age.unwrap_or(30);
    let gender_label = match profile.gender.as_deref() {
        Some("male") => "男",
        Some("female") => "女",
        _ => "未知",
    };

    let meals_str = if daily.meals.is_empty() {
        "（今日暂无记录）".to_string()
    } else {
        daily
            .meals
            .iter()
            .map(|m| {
                let name = m["name"].as_str().unwrap_or("未知");
                let total = m["totalCalories"].as_f64().unwrap_or(0.0);
                format!("- {} ({:.0}kcal)", name, total)
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    let workouts_str = if daily.workouts.is_empty() {
        "（今日暂无记录）".to_string()
    } else {
        daily
            .workouts
            .iter()
            .map(|w| {
                let t = w["type"].as_str().unwrap_or("运动");
                let dur = w["durationMinutes"].as_f64().unwrap_or(0.0);
                let burned = w["estimatedCaloriesBurned"].as_f64().unwrap_or(0.0);
                format!("- {} {}分钟 ({:.0}kcal)", t, dur, burned)
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    let preferences_str = payload
        .preferences
        .as_deref()
        .unwrap_or("无特殊偏好")
        .to_string();

    let system_prompt = r#"你是专业营养师和健身教练。根据用户数据，为其规划今日剩余的饮食和运动。
只返回 JSON，格式：
{
  "status": "balanced|deficit|overweight_adjusted",
  "summaryMessage": "总体建议（中文，2-3句）",
  "meals": [
    {
      "mealType": "breakfast|lunch|dinner|snack",
      "mealTypeLabel": "早餐|午餐|晚餐|加餐",
      "totalCalories": 数字,
      "items": [{"name": "食物名", "calories": 数字, "quantity": 数字, "unit": "单位"}]
    }
  ],
  "exercises": [
    {"name": "运动名称", "durationMinutes": 数字, "estimatedCaloriesBurned": 数字}
  ]
}
注意：meals 只包含今日剩余需要安排的餐食，不要重复已记录的餐食。"#;

    let user_prompt = format!(
        r#"用户基本信息：
- 性别：{gender}，年龄：{age}岁，身高：{height}cm，当前体重：{weight}kg，目标体重：{target}kg
- BMR：{bmr:.0}kcal，TDEE：{tdee:.0}kcal
- 今日热量目标：{calorie_target:.0}kcal（赤字目标：{deficit:.0}kcal）

今日进度：
- 已摄入：{consumed:.0}kcal
- 已燃烧（运动）：{burned:.0}kcal
- 剩余可摄入：{remaining:.0}kcal

今日已记录餐食：
{meals}

今日已记录运动：
{workouts}

用户偏好：{prefs}

请为用户规划今日剩余的饮食和运动安排。"#,
        gender = gender_label,
        age = age,
        height = profile.height_cm,
        weight = profile.current_weight_kg,
        target = profile.target_weight_kg,
        bmr = summary.bmr,
        tdee = summary.tdee,
        calorie_target = summary.recommended_calorie_target,
        deficit = summary.recommended_deficit,
        consumed = summary.calories_consumed,
        burned = summary.calories_burned,
        remaining = summary.remaining_calories,
        meals = meals_str,
        workouts = workouts_str,
        prefs = preferences_str,
    );
    let user_prompt = if profile.plan_paused {
        format!(
            "用户基本信息：\n- 性别：{gender}，年龄：{age}岁，身高：{height}cm，当前体重：{weight}kg，目标体重：{target}kg\n- BMR：{bmr:.0}kcal，TDEE：{tdee:.0}kcal\n- 当前计划状态：已暂停，请不要使用固定热量缺口，而是依据当前身体状态给出健康、可持续的饮食和运动建议。\n今日进度：\n- 已摄入：{consumed:.0}kcal\n- 已消耗（运动）：{burned:.0}kcal\n\n今日已记录饮食：\n{meals}\n\n今日已记录运动：\n{workouts}\n\n用户偏好：{prefs}\n\n请为用户规划今日剩余的饮食和运动安排。",
            gender = gender_label,
            age = age,
            height = profile.height_cm,
            weight = profile.current_weight_kg,
            target = profile.target_weight_kg,
            bmr = summary.bmr,
            tdee = summary.tdee,
            consumed = summary.calories_consumed,
            burned = summary.calories_burned,
            meals = meals_str,
            workouts = workouts_str,
            prefs = preferences_str,
        )
    } else {
        user_prompt
    };

    let messages = vec![
        json!({"role": "system", "content": system_prompt}),
        json!({"role": "user", "content": user_prompt}),
    ];

    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[llmRecommendation] OpenAI response");

    let parsed: Value = serde_json::from_str(&content).context("failed to parse OpenAI JSON")?;

    let meals: Vec<LlmMealGroup> = parsed["meals"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|g| {
            let meal_type = g["mealType"].as_str()?.to_string();
            let meal_type_label = g["mealTypeLabel"]
                .as_str()
                .unwrap_or(&meal_type)
                .to_string();
            let total_calories = g["totalCalories"].as_f64().unwrap_or(0.0);
            let items: Vec<LlmMealItem> = g["items"]
                .as_array()
                .unwrap_or(&vec![])
                .iter()
                .filter_map(|i| {
                    Some(LlmMealItem {
                        name: i["name"].as_str()?.to_string(),
                        calories: i["calories"].as_f64()?,
                        quantity: i["quantity"].as_f64().unwrap_or(1.0),
                        unit: i["unit"].as_str().unwrap_or("份").to_string(),
                    })
                })
                .collect();
            Some(LlmMealGroup {
                meal_type,
                meal_type_label,
                total_calories,
                items,
            })
        })
        .collect();

    let exercises: Vec<LlmExerciseItem> = parsed["exercises"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|e| {
            Some(LlmExerciseItem {
                name: e["name"].as_str()?.to_string(),
                duration_minutes: e["durationMinutes"].as_i64().unwrap_or(30),
                estimated_calories_burned: e["estimatedCaloriesBurned"].as_f64().unwrap_or(0.0),
            })
        })
        .collect();

    let status = parsed["status"].as_str().unwrap_or("balanced").to_string();
    let summary_message = parsed["summaryMessage"]
        .as_str()
        .unwrap_or("保持计划继续努力！")
        .to_string();

    let resp = LlmRecommendationResponse {
        status,
        recommended_calorie_target: summary.recommended_calorie_target,
        remaining_calories: summary.remaining_calories,
        summary_message,
        meals,
        exercises,
    };
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&resp).unwrap_or_default(),
        "[llmRecommendation] response"
    );

    // Persist recommendation snapshot to Firestore (best-effort)
    let days_elapsed = {
        let plan_start = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d").ok();
        let today_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").ok();
        match (plan_start, today_date) {
            (Some(start), Some(td)) => (td - start).num_days().max(0),
            _ => 0,
        }
    };
    let days_remaining = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(0),
            _ => profile.target_days.max(0),
        }
    };
    let meals_json: Vec<Value> = resp
        .meals
        .iter()
        .map(|g| {
            json!({
                "mealType": g.meal_type,
                "mealTypeLabel": g.meal_type_label,
                "totalCalories": g.total_calories,
                "items": g.items.iter().map(|i| json!({
                    "name": i.name,
                    "calories": i.calories,
                    "quantity": i.quantity,
                    "unit": i.unit,
                })).collect::<Vec<_>>(),
            })
        })
        .collect();
    let exercises_json: Vec<Value> = resp
        .exercises
        .iter()
        .map(|e| {
            json!({
                "name": e.name,
                "durationMinutes": e.duration_minutes,
                "estimatedCaloriesBurned": e.estimated_calories_burned,
            })
        })
        .collect();
    let rec_doc = json!({
        "date": date,
        "savedAt": Utc::now().to_rfc3339(),
        "status": resp.status,
        "summaryMessage": resp.summary_message,
        "recommendedCalorieTarget": resp.recommended_calorie_target,
        "remainingCalories": resp.remaining_calories,
        "bodySnapshot": {
            "heightCm": profile.height_cm,
            "weightKg": profile.current_weight_kg,
            "targetWeightKg": profile.target_weight_kg,
            "gender": profile.gender,
            "age": profile.age,
        },
        "planSnapshot": {
            "caloriesConsumed": summary.calories_consumed,
            "caloriesBurned": summary.calories_burned,
            "remainingCalories": summary.remaining_calories,
            "deficitTarget": summary.recommended_deficit,
            "calorieTarget": summary.recommended_calorie_target,
            "bmr": summary.bmr,
            "tdee": summary.tdee,
            "progressPercent": summary.progress_percent,
            "daysElapsed": days_elapsed,
            "daysRemaining": days_remaining,
        },
        "meals": meals_json,
        "exercises": exercises_json,
    });
    let rec_fields = firestore.encode_document(rec_doc);
    if let Err(e) = firestore
        .set_document(
            &format!("users/{}/aiRecommendations/{}", auth.user_id, date),
            rec_fields,
        )
        .await
    {
        error!("failed to save ai recommendation: {e:#}");
    }

    Ok(Json(json!({
        "kind": "recommendation",
        "status": resp.status,
        "recommendedCalorieTarget": resp.recommended_calorie_target,
        "remainingCalories": resp.remaining_calories,
        "summaryMessage": resp.summary_message,
        "meals": resp.meals,
        "exercises": resp.exercises,
    })))
}

// ──────────────────────────────────────────────────────────────────────────────
// /refineCalories
// ──────────────────────────────────────────────────────────────────────────────

fn is_weight_or_volume(unit: &str) -> bool {
    matches!(
        unit.to_lowercase().as_str(),
        "g" | "ml" | "克" | "毫升" | "kg" | "l" | "千克" | "升"
    )
}

async fn refine_calories(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<RefineCaloriesRequest>,
) -> ApiResult<Json<RefineCaloriesResponse>> {
    debug!(
        user_id = %auth.user_id,
        name = %payload.name,
        unit = %payload.unit,
        "[refineCalories] incoming request"
    );

    let per_unit_label = if is_weight_or_volume(&payload.unit) {
        format!("每100{}", payload.unit)
    } else {
        format!("每{}", payload.unit)
    };

    let prompt = format!(
        r#"你是专业营养师。请根据以下信息精确估算食物热量。

食物：{name}
当前估算：{current:.0} kcal（{per_unit}）
用户补充说明：{context}

请综合食物名称和用户说明，给出更准确的热量估算。
只返回 JSON：{{"caloriesPerUnit": 数字, "explanation": "一句话说明估算依据"}}"#,
        name = payload.name,
        current = payload.current_estimate,
        per_unit = per_unit_label,
        context = payload.context,
    );

    let messages = vec![json!({"role": "user", "content": prompt})];
    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[refineCalories] OpenAI response");

    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse refine response")?;

    let calories_per_unit = parsed["caloriesPerUnit"]
        .as_f64()
        .unwrap_or(payload.current_estimate);
    let explanation = parsed["explanation"].as_str().unwrap_or("").to_string();

    Ok(Json(RefineCaloriesResponse {
        calories_per_unit,
        explanation,
    }))
}

// ──────────────────────────────────────────────────────────────────────────────
// /getDailyRecords
// ──────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
struct GetDailyRecordsRequest {
    date: Option<String>,
}

#[derive(Debug, Serialize)]
struct GetDailyRecordsResponse {
    date: String,
    meals: Vec<Value>,
    workouts: Vec<Value>,
}

async fn get_daily_records(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetDailyRecordsRequest>,
) -> ApiResult<Json<GetDailyRecordsResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[getDailyRecords] incoming request"
    );
    let firestore = FirestoreClient::new(state);
    let date = payload.date.unwrap_or_else(current_date_string);
    let daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    let resp = GetDailyRecordsResponse {
        date,
        meals: daily.meals,
        workouts: daily.workouts,
    };
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&resp).unwrap_or_default(),
        "[getDailyRecords] response"
    );
    Ok(Json(resp))
}

fn current_date_string() -> String {
    let now = Utc::now().date_naive();
    format!("{:04}-{:02}-{:02}", now.year(), now.month(), now.day())
}

// ──────────────────────────────────────────────────────────────────────────────
// /getAiRecommendationHistory
// ──────────────────────────────────────────────────────────────────────────────

async fn get_ai_recommendation_history(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetAiRecommendationHistoryRequest>,
) -> ApiResult<Json<GetAiRecommendationHistoryResponse>> {
    let firestore = FirestoreClient::new(state);
    let limit = payload.limit.unwrap_or(30).clamp(1, 100);
    let items = firestore
        .list_ai_recommendations(&auth.user_id, limit)
        .await?;
    Ok(Json(GetAiRecommendationHistoryResponse { items }))
}

// ──────────────────────────────────────────────────────────────────────────────
// /getAiRecommendationDetail
// ──────────────────────────────────────────────────────────────────────────────

async fn get_ai_recommendation_detail(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetAiRecommendationDetailRequest>,
) -> ApiResult<Json<AiRecommendationDetail>> {
    let firestore = FirestoreClient::new(state);
    let detail = firestore
        .get_ai_recommendation_by_date(&auth.user_id, &payload.date)
        .await?
        .ok_or_else(|| ApiError {
            status: StatusCode::NOT_FOUND,
            message: format!("no recommendation found for date {}", payload.date),
        })?;
    Ok(Json(detail))
}

fn round1(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

struct FirestoreClient {
    state: Arc<AppState>,
}

impl FirestoreClient {
    fn new(state: Arc<AppState>) -> Self {
        Self { state }
    }

    fn now_timestamp(&self) -> Value {
        json!(Utc::now().to_rfc3339())
    }

    async fn access_token(&self) -> Result<String> {
        let scopes = &["https://www.googleapis.com/auth/datastore"];
        let token = self
            .state
            .auth_manager
            .token(scopes)
            .await
            .context("failed to obtain GCP access token")?;
        Ok(token.as_str().to_string())
    }

    fn document_url(&self, document_path: &str) -> String {
        format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/{}",
            self.state.project_id, document_path
        )
    }

    fn collection_url(&self, collection_path: &str) -> String {
        format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/{}",
            self.state.project_id, collection_path
        )
    }

    async fn set_document(&self, document_path: &str, fields: Value) -> Result<()> {
        let url = self.document_url(document_path);
        let body = json!({ "fields": fields });
        debug!(
            url = %url,
            body = ?body.to_string(),
            "[firestore] PATCH (set_document) request"
        );
        let token = self.access_token().await?;
        let resp = self
            .state
            .http
            .patch(&url)
            .bearer_auth(token)
            .json(&body)
            .send()
            .await?
            .error_for_status()?;
        let status = resp.status();
        let resp_text = resp.text().await.unwrap_or_default();
        debug!(
            url = %url,
            status = %status,
            body = %resp_text,
            "[firestore] PATCH (set_document) response"
        );
        Ok(())
    }

    async fn get_document(&self, document_path: &str) -> Result<Option<Value>> {
        let url = self.document_url(document_path);
        debug!(
            url = %url,
            "[firestore] GET (get_document) request"
        );
        let token = self.access_token().await?;
        let response = self.state.http.get(&url).bearer_auth(token).send().await?;
        let status = response.status();
        if status == reqwest::StatusCode::NOT_FOUND {
            debug!(url = %url, "[firestore] GET (get_document) response: 404 not found");
            return Ok(None);
        }
        let doc = response.error_for_status()?.json::<Value>().await?;
        debug!(
            url = %url,
            status = %status,
            body = ?doc.to_string(),
            "[firestore] GET (get_document) response"
        );
        Ok(Some(doc))
    }

    async fn create_document_auto_id(&self, collection_path: &str, fields: Value) -> Result<()> {
        let url = self.collection_url(collection_path);
        let body = json!({ "fields": fields });
        debug!(
            url = %url,
            body = ?body.to_string(),
            "[firestore] POST (create_document_auto_id) request"
        );
        let token = self.access_token().await?;
        let resp = self
            .state
            .http
            .post(&url)
            .bearer_auth(token)
            .json(&body)
            .send()
            .await?
            .error_for_status()?;
        let status = resp.status();
        let resp_text = resp.text().await.unwrap_or_default();
        debug!(
            url = %url,
            status = %status,
            body = %resp_text,
            "[firestore] POST (create_document_auto_id) response"
        );
        Ok(())
    }

    async fn get_profile(&self, user_id: &str) -> Result<Profile> {
        let doc = self
            .get_document(&format!("users/{}", user_id))
            .await?
            .ok_or_else(|| anyhow!("profile not found"))?;
        let fields = decode_document_fields(doc)?;
        Ok(Profile {
            height_cm: get_f64(&fields, "heightCm")?,
            current_weight_kg: get_f64(&fields, "currentWeightKg")?,
            start_weight_kg: get_f64(&fields, "startWeightKg")
                .unwrap_or_else(|_| get_f64(&fields, "currentWeightKg").unwrap_or(0.0)),
            target_weight_kg: get_f64(&fields, "targetWeightKg")?,
            target_days: get_i64(&fields, "targetDays")?,
            gender: get_optional_string(&fields, "gender"),
            age: get_optional_i64(&fields, "age"),
            plan_start_date: get_string(&fields, "planStartDate")
                .unwrap_or_else(|_| current_date_string()),
            plan_paused: get_bool(&fields, "planPaused").unwrap_or(false),
        })
    }

    async fn get_daily_stats(&self, user_id: &str, date: &str) -> Result<DailyStats> {
        let path = format!("users/{}/dailyStats/{}", user_id, date);
        let Some(doc) = self.get_document(&path).await? else {
            return Ok(DailyStats::default());
        };
        let fields = decode_document_fields(doc)?;
        Ok(DailyStats {
            meals: get_array(&fields, "meals"),
            workouts: get_array(&fields, "workouts"),
            calories_consumed: get_f64(&fields, "caloriesConsumed").unwrap_or(0.0),
            calories_burned: get_f64(&fields, "caloriesBurned").unwrap_or(0.0),
            latest_weight_kg: get_f64(&fields, "latestWeightKg").ok(),
        })
    }

    async fn get_food_catalog(&self, user_id: &str) -> Result<Vec<FoodCatalogItem>> {
        let path = format!("users/{}/meta/foodCatalog", user_id);
        let Some(doc) = self.get_document(&path).await? else {
            return Ok(vec![]);
        };
        let fields = decode_document_fields(doc)?;
        let raw_items = get_array(&fields, "items");
        let items: Vec<FoodCatalogItem> = raw_items
            .into_iter()
            .filter_map(|v| {
                let name = v["name"].as_str()?.to_string();
                let calories_per_unit = v["caloriesPerUnit"].as_f64()?;
                let unit = v["unit"].as_str().unwrap_or("份").to_string();
                let times_used = v["timesUsed"].as_i64().unwrap_or(1);
                Some(FoodCatalogItem {
                    name,
                    calories_per_unit,
                    unit,
                    times_used,
                })
            })
            .collect();
        Ok(items)
    }

    async fn upsert_food_catalog(
        &self,
        user_id: &str,
        food_name: &str,
        calories_per_unit: f64,
        unit: &str,
    ) -> Result<()> {
        let mut items = self.get_food_catalog(user_id).await.unwrap_or_default();
        let name_lower = food_name.trim().to_lowercase();
        if let Some(entry) = items
            .iter_mut()
            .find(|e| e.name.to_lowercase() == name_lower)
        {
            entry.calories_per_unit = calories_per_unit;
            entry.unit = unit.to_string();
            entry.times_used += 1;
        } else {
            items.push(FoodCatalogItem {
                name: food_name.trim().to_string(),
                calories_per_unit,
                unit: unit.to_string(),
                times_used: 1,
            });
        }
        // Keep only top 200 entries by timesUsed
        items.sort_by(|a, b| b.times_used.cmp(&a.times_used));
        items.truncate(200);

        let items_value: Vec<Value> = items
            .iter()
            .map(|e| {
                json!({
                    "name": e.name,
                    "caloriesPerUnit": e.calories_per_unit,
                    "unit": e.unit,
                    "timesUsed": e.times_used,
                })
            })
            .collect();

        let fields = self.encode_document(json!({ "items": items_value }));
        self.set_document(&format!("users/{}/meta/foodCatalog", user_id), fields)
            .await
    }

    async fn save_daily_stats(&self, user_id: &str, date: &str, stats: &DailyStats) -> Result<()> {
        let fields = self.encode_document(json!({
            "date": date,
            "meals": stats.meals,
            "workouts": stats.workouts,
            "caloriesConsumed": stats.calories_consumed,
            "caloriesBurned": stats.calories_burned,
            "latestWeightKg": stats.latest_weight_kg,
            "updatedAt": self.now_timestamp(),
        }));
        self.set_document(&format!("users/{}/dailyStats/{}", user_id, date), fields)
            .await
    }

    fn encode_document(&self, value: Value) -> Value {
        encode_firestore_value(value)
            .get("mapValue")
            .and_then(|v| v.get("fields"))
            .cloned()
            .unwrap_or_else(|| json!({}))
    }

    async fn list_collection(&self, collection_path: &str, page_size: i64) -> Result<Vec<Value>> {
        let url = format!(
            "{}?pageSize={}&orderBy=__name__%20desc",
            self.collection_url(collection_path),
            page_size
        );
        debug!(url = %url, "[firestore] GET (list_collection) request");
        let token = self.access_token().await?;
        let resp = self
            .state
            .http
            .get(&url)
            .bearer_auth(token)
            .send()
            .await?
            .error_for_status()?;
        let body: Value = resp.json().await?;
        let docs = body
            .get("documents")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        Ok(docs)
    }

    async fn list_ai_recommendations(
        &self,
        user_id: &str,
        limit: i64,
    ) -> Result<Vec<AiRecommendationSummaryItem>> {
        let collection_path = format!("users/{}/aiRecommendations", user_id);
        let docs = self.list_collection(&collection_path, limit).await?;
        let mut items = Vec::new();
        for doc in docs {
            let Ok(fields) = decode_document_fields(doc) else {
                continue;
            };
            let date = get_string(&fields, "date").unwrap_or_default();
            if date.is_empty() {
                continue;
            }
            let saved_at = get_string(&fields, "savedAt").unwrap_or_default();
            let status = get_string(&fields, "status").unwrap_or_default();
            let summary_message = get_string(&fields, "summaryMessage").unwrap_or_default();
            let recommended_calorie_target =
                get_f64(&fields, "recommendedCalorieTarget").unwrap_or(0.0);
            let weight_kg = fields
                .get("bodySnapshot")
                .and_then(Value::as_object)
                .and_then(|s| s.get("weightKg"))
                .and_then(Value::as_f64)
                .unwrap_or(0.0);
            items.push(AiRecommendationSummaryItem {
                date,
                saved_at,
                status,
                summary_message,
                recommended_calorie_target,
                weight_kg,
            });
        }
        Ok(items)
    }

    async fn get_ai_recommendation_by_date(
        &self,
        user_id: &str,
        date: &str,
    ) -> Result<Option<AiRecommendationDetail>> {
        let path = format!("users/{}/aiRecommendations/{}", user_id, date);
        let Some(doc) = self.get_document(&path).await? else {
            return Ok(None);
        };
        let fields = decode_document_fields(doc)?;

        let date = get_string(&fields, "date").unwrap_or_default();
        let saved_at = get_string(&fields, "savedAt").unwrap_or_default();
        let status = get_string(&fields, "status").unwrap_or_default();
        let summary_message = get_string(&fields, "summaryMessage").unwrap_or_default();
        let recommended_calorie_target =
            get_f64(&fields, "recommendedCalorieTarget").unwrap_or(0.0);
        let remaining_calories = get_f64(&fields, "remainingCalories").unwrap_or(0.0);

        let body_snapshot = fields
            .get("bodySnapshot")
            .and_then(Value::as_object)
            .map(|s| AiBodySnapshot {
                height_cm: s.get("heightCm").and_then(Value::as_f64).unwrap_or(0.0),
                weight_kg: s.get("weightKg").and_then(Value::as_f64).unwrap_or(0.0),
                target_weight_kg: s
                    .get("targetWeightKg")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                gender: s.get("gender").and_then(Value::as_str).map(str::to_string),
                age: s.get("age").and_then(Value::as_i64),
            })
            .unwrap_or(AiBodySnapshot {
                height_cm: 0.0,
                weight_kg: 0.0,
                target_weight_kg: 0.0,
                gender: None,
                age: None,
            });

        let plan_snapshot = fields
            .get("planSnapshot")
            .and_then(Value::as_object)
            .map(|s| AiPlanSnapshot {
                calories_consumed: s
                    .get("caloriesConsumed")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                calories_burned: s
                    .get("caloriesBurned")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                remaining_calories: s
                    .get("remainingCalories")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                deficit_target: s
                    .get("deficitTarget")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                calorie_target: s
                    .get("calorieTarget")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                bmr: s.get("bmr").and_then(Value::as_f64).unwrap_or(0.0),
                tdee: s.get("tdee").and_then(Value::as_f64).unwrap_or(0.0),
                progress_percent: s
                    .get("progressPercent")
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0),
                days_elapsed: s.get("daysElapsed").and_then(Value::as_i64).unwrap_or(0),
                days_remaining: s.get("daysRemaining").and_then(Value::as_i64).unwrap_or(0),
            })
            .unwrap_or(AiPlanSnapshot {
                calories_consumed: 0.0,
                calories_burned: 0.0,
                remaining_calories: 0.0,
                deficit_target: 0.0,
                calorie_target: 0.0,
                bmr: 0.0,
                tdee: 0.0,
                progress_percent: 0.0,
                days_elapsed: 0,
                days_remaining: 0,
            });

        let meals: Vec<LlmMealGroup> = get_array(&fields, "meals")
            .into_iter()
            .filter_map(|g| {
                let meal_type = g["mealType"].as_str()?.to_string();
                let meal_type_label = g["mealTypeLabel"]
                    .as_str()
                    .unwrap_or(&meal_type)
                    .to_string();
                let total_calories = g["totalCalories"].as_f64().unwrap_or(0.0);
                let items: Vec<LlmMealItem> = g["items"]
                    .as_array()
                    .unwrap_or(&vec![])
                    .iter()
                    .filter_map(|i| {
                        Some(LlmMealItem {
                            name: i["name"].as_str()?.to_string(),
                            calories: i["calories"].as_f64()?,
                            quantity: i["quantity"].as_f64().unwrap_or(1.0),
                            unit: i["unit"].as_str().unwrap_or("份").to_string(),
                        })
                    })
                    .collect();
                Some(LlmMealGroup {
                    meal_type,
                    meal_type_label,
                    total_calories,
                    items,
                })
            })
            .collect();

        let exercises: Vec<LlmExerciseItem> = get_array(&fields, "exercises")
            .into_iter()
            .filter_map(|e| {
                Some(LlmExerciseItem {
                    name: e["name"].as_str()?.to_string(),
                    duration_minutes: e["durationMinutes"].as_i64().unwrap_or(30),
                    estimated_calories_burned: e["estimatedCaloriesBurned"].as_f64().unwrap_or(0.0),
                })
            })
            .collect();

        Ok(Some(AiRecommendationDetail {
            date,
            saved_at,
            status,
            summary_message,
            recommended_calorie_target,
            remaining_calories,
            body_snapshot,
            plan_snapshot,
            meals,
            exercises,
        }))
    }
}

fn encode_firestore_value(value: Value) -> Value {
    match value {
        Value::Null => json!({ "nullValue": null }),
        Value::Bool(v) => json!({ "booleanValue": v }),
        Value::Number(n) => {
            if n.is_i64() {
                json!({ "integerValue": n.as_i64().unwrap() })
            } else {
                json!({ "doubleValue": n.as_f64().unwrap() })
            }
        }
        Value::String(v) => json!({ "stringValue": v }),
        Value::Array(items) => json!({
            "arrayValue": {
                "values": items.into_iter().map(encode_firestore_value).collect::<Vec<_>>()
            }
        }),
        Value::Object(map) => {
            let fields = map
                .into_iter()
                .filter(|(_, v)| !v.is_null())
                .map(|(k, v)| (k, encode_firestore_value(v)))
                .collect::<Map<String, Value>>();
            json!({ "mapValue": { "fields": fields } })
        }
    }
}

fn decode_document_fields(doc: Value) -> Result<HashMap<String, Value>> {
    let fields = doc
        .get("fields")
        .and_then(Value::as_object)
        .ok_or_else(|| anyhow!("document missing fields"))?;
    fields
        .iter()
        .map(|(k, v)| Ok((k.clone(), decode_firestore_value(v)?)))
        .collect()
}

fn decode_firestore_value(value: &Value) -> Result<Value> {
    if value.get("nullValue").is_some() {
        return Ok(Value::Null);
    }
    if let Some(v) = value.get("booleanValue").and_then(Value::as_bool) {
        return Ok(json!(v));
    }
    if let Some(v) = value.get("stringValue").and_then(Value::as_str) {
        return Ok(json!(v));
    }
    if let Some(v) = value.get("integerValue") {
        if let Some(s) = v.as_str() {
            return Ok(json!(s.parse::<i64>()?));
        }
        if let Some(i) = v.as_i64() {
            return Ok(json!(i));
        }
    }
    if let Some(v) = value.get("doubleValue").and_then(Value::as_f64) {
        return Ok(json!(v));
    }
    if let Some(v) = value.get("timestampValue").and_then(Value::as_str) {
        return Ok(json!(v));
    }
    if let Some(array_value) = value.get("arrayValue") {
        // Firestore omits the "values" key entirely for empty arrays,
        // returning {"arrayValue": {}} — handle both cases.
        let items = match array_value.get("values").and_then(Value::as_array) {
            Some(arr) => {
                let mut out = Vec::with_capacity(arr.len());
                for item in arr {
                    out.push(decode_firestore_value(item)?);
                }
                out
            }
            None => Vec::new(),
        };
        return Ok(Value::Array(items));
    }
    if let Some(fields) = value
        .get("mapValue")
        .and_then(|v| v.get("fields"))
        .and_then(Value::as_object)
    {
        let mut map = Map::new();
        for (k, v) in fields {
            map.insert(k.clone(), decode_firestore_value(v)?);
        }
        return Ok(Value::Object(map));
    }
    Err(anyhow!("unsupported firestore value: {value}"))
}

fn get_f64(map: &HashMap<String, Value>, key: &str) -> Result<f64> {
    let value = map.get(key).ok_or_else(|| anyhow!("missing {key}"))?;
    value
        .as_f64()
        .or_else(|| value.as_i64().map(|v| v as f64))
        .ok_or_else(|| anyhow!("invalid number for {key}"))
}

fn get_i64(map: &HashMap<String, Value>, key: &str) -> Result<i64> {
    let value = map.get(key).ok_or_else(|| anyhow!("missing {key}"))?;
    value
        .as_i64()
        .or_else(|| value.as_f64().map(|v| v.round() as i64))
        .ok_or_else(|| anyhow!("invalid integer for {key}"))
}

fn get_string(map: &HashMap<String, Value>, key: &str) -> Result<String> {
    map.get(key)
        .and_then(Value::as_str)
        .map(str::to_string)
        .ok_or_else(|| anyhow!("missing string {key}"))
}

fn get_optional_string(map: &HashMap<String, Value>, key: &str) -> Option<String> {
    map.get(key).and_then(Value::as_str).map(str::to_string)
}

fn get_optional_i64(map: &HashMap<String, Value>, key: &str) -> Option<i64> {
    map.get(key)
        .and_then(|v| v.as_i64().or_else(|| v.as_f64().map(|n| n.round() as i64)))
}

fn get_bool(map: &HashMap<String, Value>, key: &str) -> Result<bool> {
    map.get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| anyhow!("missing bool {key}"))
}

fn get_array(map: &HashMap<String, Value>, key: &str) -> Vec<Value> {
    map.get(key)
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

type ApiResult<T> = std::result::Result<T, ApiError>;

#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn bad_request(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message: message.into(),
        }
    }

    fn unauthorized(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::UNAUTHORIZED,
            message: message.into(),
        }
    }
}

impl<E> From<E> for ApiError
where
    E: Into<anyhow::Error>,
{
    fn from(value: E) -> Self {
        let err = value.into();
        error!("{err:#}");
        Self {
            status: StatusCode::BAD_REQUEST,
            message: err.to_string(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(json!({ "error": self.message }))).into_response()
    }
}
